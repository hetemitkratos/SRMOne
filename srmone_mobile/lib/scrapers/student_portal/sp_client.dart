// lib/scrapers/student_portal/sp_client.dart
// SRM Student Portal (sp.srmist.edu.in) HTTP client.
// Ported from academia-backend/academia-scraper/cmd/studentportal/client.go & login.go

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/constants/portal_endpoints.dart';
import '../../core/network/manual_redirect_client.dart';
import '../../core/network/simple_cookie_jar.dart';
import '../../domain/services/attendance_planner_math.dart';
import 'sp_captcha_solver.dart';
import 'sp_parsers.dart';

class SPLoginContext {
  final SPSecureConfig config;
  final List<String> honeypotNames;
  final int pageLoadMs;
  final Uint8List captchaImage;

  const SPLoginContext({
    required this.config,
    required this.honeypotNames,
    required this.pageLoadMs,
    required this.captchaImage,
  });
}

sealed class SPLoginResult {
  const SPLoginResult();
}

class SPLoginSuccess extends SPLoginResult {
  final String html;
  const SPLoginSuccess(this.html);
}

class SPCaptchaRequired extends SPLoginResult {
  final Uint8List captchaImage;
  final SPLoginContext context;
  const SPCaptchaRequired(this.captchaImage, this.context);
}

class SPLoginFailure extends SPLoginResult {
  final String message;
  const SPLoginFailure(this.message);
}

class SPClient {
  final SimpleCookieJar cookieJar;
  final ManualRedirectClient _client;

  SPClient({required this.cookieJar})
      : _client = ManualRedirectClient(cookieJar: cookieJar);

  static const String _spBaseUrl = 'https://sp.srmist.edu.in';
  static const String _spLoginUrl =
      '$_spBaseUrl/srmiststudentportal/students/loginManager/youLogin.jsp';
  static const String _spLoginPostUrl =
      '$_spBaseUrl/srmiststudentportal/LoginServlet';
  static const String _spAttendanceUrl =
      '$_spBaseUrl/srmiststudentportal/students/report/studentAttendanceDetails.jsp';
  static const String _spInternalMarksUrl =
      '$_spBaseUrl/srmiststudentportal/students/report/studentInternalMarkDetails.jsp';
  static const String _spDashboardUrl =
      '$_spBaseUrl/srmiststudentportal/students/template/HRDSystem.jsp';

  /// Step 1: Prepares login by fetching the login page, parsing SECURE_CONFIG,
  /// collecting honeypot names, and downloading the CAPTCHA image with X-Domain-Proof.
  Future<SPLoginContext> prepareLogin() async {
    final pageResp = await _client.get(
      _spLoginUrl,
      headers: {
        'User-Agent': PortalEndpoints.defaultUserAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    );

    final html = pageResp.data.toString();
    final pageLoadMs = DateTime.now().millisecondsSinceEpoch;
    final config = SPParsers.parseSecureConfig(html);

    if (config.captchaText.isEmpty) {
      throw const FormatException(
          'Could not extract captchaText from SP login page');
    }

    final honeypotNames = SPParsers.extractHoneypotNames(html);

    // Fetch CAPTCHA image with X-Domain-Proof header
    final domainProof =
        base64Encode(utf8.encode('${config.nonce}:sp.srmist.edu.in'));
    const captchaUrl = '$_spBaseUrl/srmiststudentportal/SCaptchaServlet';

    final captchaResp = await _client.request(
      'GET',
      captchaUrl,
      headers: {
        'Referer': _spLoginUrl,
        'Accept': 'image/png, image/jpeg, image/svg+xml, image/*',
        'X-Domain-Proof': domainProof,
        'User-Agent': PortalEndpoints.defaultUserAgent,
      },
      // Binary image: a text response would corrupt the bytes.
      responseType: ResponseType.bytes,
    );

    Uint8List captchaBytes;
    if (captchaResp.data is List<int>) {
      captchaBytes = Uint8List.fromList(captchaResp.data as List<int>);
    } else {
      throw const FormatException('Invalid CAPTCHA image response format');
    }

    return SPLoginContext(
      config: config,
      honeypotNames: honeypotNames,
      pageLoadMs: pageLoadMs,
      captchaImage: captchaBytes,
    );
  }

  /// Automatically attempts login using ONNX CAPTCHA solver.
  /// Falls back to returning SPCaptchaRequired if ONNX fails or CAPTCHA is rejected.
  Future<SPLoginResult> login(String netId, String password) async {
    final ctx = await prepareLogin();

    // Try ONNX CAPTCHA solve
    final solved = await SpCaptchaSolver.solve(ctx.captchaImage);
    if (solved == null || solved.length < 4) {
      return SPCaptchaRequired(ctx.captchaImage, ctx);
    }

    return submitLogin(ctx, netId, password, solved);
  }

  /// Submits the login form with a solved CAPTCHA string.
  Future<SPLoginResult> submitLogin(
    SPLoginContext ctx,
    String netId,
    String password,
    String solvedCaptcha,
  ) async {
    String cleanNetId = netId.trim();
    if (cleanNetId.contains('@')) {
      cleanNetId = cleanNetId.split('@').first;
    }

    final config = ctx.config;
    final now = DateTime.now();
    final startTime =
        now.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch;
    final submitTime = now.millisecondsSinceEpoch;

    // Telemetry payload
    final telemetryMap = {
      'startTime': startTime,
      'currentDomain': 'sp.srmist.edu.in',
      'timezoneOffset': -330,
      'screenWidth': 1920,
      'screenHeight': 1080,
      'colorDepth': 24,
      'devicePixelRatio': 1,
      'platform': 'Win32',
      'userAgent': PortalEndpoints.defaultUserAgent,
      'language': 'en-US',
      'hardwareConcurrency': 8,
      'deviceMemory': 8,
      'touchSupport': false,
      'webdriver': false,
      'mouseClicks': 1,
      'mouseMovements': 5,
      'keystrokeCount': 10,
      'typingSpeedMs': 5000,
      'canvasHash': 'a1b2c3d4e5f6',
      'submitTime': submitTime,
      'timeOnPageMs': 5000,
    };
    final telemetryPayload =
        base64Encode(utf8.encode(jsonEncode(telemetryMap)));

    // Build form body in DOM order
    final formParts = <String>[];
    formParts.add('username=${Uri.encodeQueryComponent(cleanNetId)}');
    formParts.add('password=${Uri.encodeQueryComponent(password)}');

    for (final name in ctx.honeypotNames) {
      formParts.add('${Uri.encodeQueryComponent(name)}=');
    }

    formParts.add('captcha=${Uri.encodeQueryComponent(solvedCaptcha)}');
    formParts.add('fpPayload=');
    formParts.add('fpToken=');
    formParts
        .add('telemetryPayload=${Uri.encodeQueryComponent(telemetryPayload)}');

    final reversedHost = 'sp.srmist.edu.in'.split('').reversed.join();
    final encodedHost = base64Encode(utf8.encode(reversedHost));

    if (config.domainFieldName.isNotEmpty) {
      formParts.add(
          '${Uri.encodeQueryComponent(config.domainFieldName)}=${Uri.encodeQueryComponent(encodedHost)}');
    }

    if (config.captchaFieldName.isNotEmpty) {
      int timeElapsed =
          (DateTime.now().millisecondsSinceEpoch - ctx.pageLoadMs) ~/ 1000;
      if (timeElapsed < 3) {
        timeElapsed = 3 +
            (config.randomDelimiter.isNotEmpty
                ? config.randomDelimiter.codeUnitAt(0) % 10
                : 3);
      }
      final interactCount = 5 + (timeElapsed % 10);
      final trapPayload = '$timeElapsed${config.randomDelimiter}$interactCount';
      final encodedTrap = base64Encode(utf8.encode(trapPayload));
      formParts.add(
          '${Uri.encodeQueryComponent(config.captchaFieldName)}=${Uri.encodeQueryComponent(encodedTrap)}');
    }

    if (config.domainFieldName.isNotEmpty) {
      // guardlogin.js duplicate
      formParts.add(
          '${Uri.encodeQueryComponent(config.domainFieldName)}=${Uri.encodeQueryComponent(encodedHost)}');
    }

    final body = formParts.join('&');

    final response = await _client.post(
      _spLoginPostUrl,
      body: body,
      headers: {
        'Referer': _spLoginUrl,
        'Origin': _spBaseUrl,
        'User-Agent': PortalEndpoints.defaultUserAgent,
        'Upgrade-Insecure-Requests': '1',
      },
    );

    final respHtml = response.data.toString();

    // Check for login failure alerts
    if (respHtml.contains('alert-danger') ||
        respHtml.contains('Invalid Captcha') ||
        respHtml.contains('Invalid User') ||
        respHtml.contains('Login Failed')) {
      if (respHtml.contains('Invalid Captcha') ||
          respHtml.contains('alert-danger')) {
        // Need manual fallback
        final newCtx = await prepareLogin();
        return SPCaptchaRequired(newCtx.captchaImage, newCtx);
      }
      return const SPLoginFailure('Invalid registration number or password');
    }

    return SPLoginSuccess(respHtml);
  }

  /// Fetches attendance records from Student Portal (iden=9).
  Future<List<AttendanceInput>> fetchAttendance() async {
    // Prime context
    await _client.get(_spDashboardUrl, headers: {'Referer': _spLoginUrl});

    const body = 'iden=9&filter=&hdnFormDetails=1&csrfPreventionSalt=';
    final response = await _client.post(
      _spAttendanceUrl,
      body: body,
      headers: {
        'Referer': _spDashboardUrl,
        'X-Requested-With': 'XMLHttpRequest',
      },
    );

    return SPParsers.parseAttendance(response.data.toString());
  }

  /// Fetches internal marks from Student Portal (iden=13).
  Future<List<SPMarkRecord>> fetchInternalMarks() async {
    await _client.get(_spDashboardUrl, headers: {'Referer': _spLoginUrl});

    const body = 'iden=13&filter=&hdnFormDetails=1&csrfPreventionSalt=';
    final response = await _client.post(
      _spInternalMarksUrl,
      body: body,
      headers: {
        'Referer': _spDashboardUrl,
        'X-Requested-With': 'XMLHttpRequest',
      },
    );

    return SPParsers.parseInternalMarks(response.data.toString());
  }
}
