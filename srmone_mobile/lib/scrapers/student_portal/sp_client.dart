// lib/scrapers/student_portal/sp_client.dart
// SRM Student Portal (sp.srmist.edu.in) HTTP client.
// Ported from academia-backend/academia-scraper/cmd/studentportal/client.go & login.go

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  /// Upper bound for each Student Portal round trip, so a stalled portal
  /// surfaces as an error instead of an endless spinner.
  static const Duration stepTimeout = Duration(seconds: 30);

  /// How many fresh CAPTCHAs [login] tries to solve on-device before asking
  /// the user. Each rejected answer costs one portal sign-in attempt.
  static const int autoSolveAttempts = 3;

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
    ).timeout(stepTimeout);

    final html = pageResp.data.toString();
    final pageLoadMs = DateTime.now().millisecondsSinceEpoch;
    // Parsed off the UI isolate: the login page is large enough to stall
    // a frame. Only the HTML string crosses over.
    final (config, honeypotNames, captchaUrl) = await Isolate.run(() => (
          SPParsers.parseSecureConfig(html),
          SPParsers.extractHoneypotNames(html),
          SPParsers.extractCaptchaImageUrl(html, _spLoginUrl),
        ));

    if (config.captchaText.isEmpty) {
      throw const FormatException(
          'Could not extract captchaText from SP login page');
    }

    // The real image lives at the one-time URL in img#secure_captcha's
    // data-src; the bare servlet path answers 403 with an empty body.
    if (captchaUrl.isEmpty) {
      throw const FormatException('SP login page has no CAPTCHA image');
    }
    final domainProof =
        base64Encode(utf8.encode('${config.nonce}:sp.srmist.edu.in'));

    final captchaResp = await _client
        .request(
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
        )
        .timeout(stepTimeout);

    final data = captchaResp.data;
    final captchaBytes =
        data is List<int> ? Uint8List.fromList(data) : Uint8List(0);
    if (!looksLikeRasterImage(captchaBytes)) {
      throw FormatException('SP CAPTCHA was not an image '
          '(HTTP ${captchaResp.statusCode}, ${captchaBytes.length} bytes)');
    }

    return SPLoginContext(
      config: config,
      honeypotNames: honeypotNames,
      pageLoadMs: pageLoadMs,
      captchaImage: captchaBytes,
    );
  }

  /// True when [bytes] start with a PNG, JPEG or GIF signature, i.e. something
  /// both `Image.memory` and the OCR decoder can read.
  static bool looksLikeRasterImage(Uint8List bytes) {
    bool startsWith(List<int> sig) {
      if (bytes.length < sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (bytes[i] != sig[i]) return false;
      }
      return true;
    }

    return startsWith(const [0x89, 0x50, 0x4E, 0x47]) || // PNG
        startsWith(const [0xFF, 0xD8, 0xFF]) || // JPEG
        startsWith(const [0x47, 0x49, 0x46, 0x38]); // GIF
  }

  /// Signs in, solving the CAPTCHA on-device. Tries up to [autoSolveAttempts]
  /// fresh CAPTCHAs; if none is accepted (or OCR is unavailable) returns
  /// [SPCaptchaRequired] with a fresh CAPTCHA for the user to read.
  Future<SPLoginResult> login(String netId, String password) async {
    // Load the OCR model while the login page and CAPTCHA download.
    unawaited(SpCaptchaSolver.init());
    var ctx = await prepareLogin();
    for (var attempt = 1; attempt <= autoSolveAttempts; attempt++) {
      final solved = await SpCaptchaSolver.solve(ctx.captchaImage);
      _log('OCR attempt $attempt: '
          '${solved == null ? 'no answer' : '${solved.length} chars'}');
      if (solved == null) break;
      final result = await submitLogin(ctx, netId, password, solved);
      if (result is! SPCaptchaRequired) return result;
      ctx = result.context;
    }
    return SPCaptchaRequired(ctx.captchaImage, ctx);
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[SP] $message');
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
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Upgrade-Insecure-Requests': '1',
      },
    ).timeout(stepTimeout);

    final respHtml = response.data.toString();
    final finalUrl = response.realUri.toString();

    if (!SPParsers.isLoginFailed(finalUrl, respHtml)) {
      _log('signed in (HTTP ${response.statusCode})');
      return SPLoginSuccess(respHtml);
    }

    final alert = SPParsers.extractAlertText(respHtml);
    _log('sign-in rejected: ${alert.isEmpty ? '(no alert)' : alert}');
    if (isCredentialRejection(alert)) {
      return SPLoginFailure(alert);
    }
    // Wrong (or unreadable) CAPTCHA: the old one is spent, fetch a new one.
    final newCtx = await prepareLogin();
    return SPCaptchaRequired(newCtx.captchaImage, newCtx);
  }

  /// Whether the portal's alert text blames the NetID/password rather than
  /// the CAPTCHA. Retrying a CAPTCHA cannot fix these, and retrying a wrong
  /// password risks locking the account.
  static bool isCredentialRejection(String alert) {
    final a = alert.toLowerCase();
    if (a.contains('captcha')) return false;
    return a.contains('password') ||
        a.contains('credential') ||
        a.contains('invalid user') ||
        a.contains('locked');
  }

  /// Fetches attendance records from Student Portal (iden=9).
  Future<List<AttendanceInput>> fetchAttendance() async {
    // Prime context
    await _client.get(_spDashboardUrl,
        headers: {'Referer': _spLoginUrl}).timeout(stepTimeout);

    const body = 'iden=9&filter=&hdnFormDetails=1&csrfPreventionSalt=';
    final response = await _client.post(
      _spAttendanceUrl,
      body: body,
      headers: {
        'Referer': _spDashboardUrl,
        'X-Requested-With': 'XMLHttpRequest',
      },
    ).timeout(stepTimeout);

    final html = response.data.toString();
    return Isolate.run(() => SPParsers.parseAttendance(html));
  }

  /// Fetches internal marks from Student Portal (iden=13). Pass [prime]
  /// false right after [fetchAttendance], which already opened the
  /// dashboard in this session.
  Future<List<SPMarkRecord>> fetchInternalMarks({bool prime = true}) async {
    if (prime) {
      await _client.get(_spDashboardUrl,
          headers: {'Referer': _spLoginUrl}).timeout(stepTimeout);
    }

    const body = 'iden=13&filter=&hdnFormDetails=1&csrfPreventionSalt=';
    final response = await _client.post(
      _spInternalMarksUrl,
      body: body,
      headers: {
        'Referer': _spDashboardUrl,
        'X-Requested-With': 'XMLHttpRequest',
      },
    ).timeout(stepTimeout);

    final html = response.data.toString();
    return Isolate.run(() => SPParsers.parseInternalMarks(html));
  }
}
