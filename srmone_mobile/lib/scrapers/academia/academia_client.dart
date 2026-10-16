// lib/scrapers/academia/academia_client.dart
// SRM Academia Zoho authentication and scraper client.
// Implements the 6-step Zoho login sequence, silent cookie rotation,
// and cache-busted data fetching.
// Ported from academia-backend/academia-scraper/cmd/loginprobe/login.go & client.go

import 'dart:convert';
import '../../core/constants/portal_endpoints.dart';
import '../../core/network/manual_redirect_client.dart';
import '../../core/network/simple_cookie_jar.dart';
import '../../domain/services/attendance_planner_math.dart';
import 'academia_decoder.dart';
import 'academia_parsers.dart';

class SessionExpiredException implements Exception {
  final String message;
  const SessionExpiredException(this.message);

  @override
  String toString() => 'SessionExpiredException: $message';
}

class AcademiaClient {
  final SimpleCookieJar cookieJar;
  final ManualRedirectClient _client;

  AcademiaClient({required this.cookieJar})
      : _client = ManualRedirectClient(cookieJar: cookieJar);

  static const String _host = 'academia.srmist.edu.in';

  // ─── 6-Step Zoho Login ────────────────────────────────────────────────────────

  /// Executes the 6-step Zoho authentication sequence.
  /// Rotates cookies in [cookieJar] upon success.
  Future<bool> login(String email, String password) async {
    // 1. Account Normalization
    String fullEmail = email.trim();
    if (!fullEmail.contains('@')) {
      fullEmail = '$fullEmail@srmist.edu.in';
    }
    final encodedEmail = Uri.encodeComponent(fullEmail);

    String serviceUrl = PortalEndpoints.academiaBaseUrl;
    String uriPrefix = '/accounts/p/${PortalEndpoints.defaultPortalId}';
    String csrfParam = 'iamcsrcoo';
    String csrfCookie = 'iamcsr';
    final cliTime = DateTime.now().toUtc().millisecondsSinceEpoch.toString();

    // Step 1: Load Sign-In Page
    final signinUrl =
        '${PortalEndpoints.academiaBaseUrl}${PortalEndpoints.signinPath}'
        '?serviceurl=${Uri.encodeQueryComponent(serviceUrl)}';

    final signinResp = await _client.get(
      signinUrl,
      headers: {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'User-Agent': PortalEndpoints.defaultUserAgent,
      },
    );

    final signinHtml = signinResp.data.toString();

    // Extract JS variables
    String? extractJs(String name) {
      final m1 =
          RegExp('var\\s+$name\\s*=\\s*"([^"]*)"').firstMatch(signinHtml);
      if (m1 != null) return m1.group(1);
      final m2 =
          RegExp("var\\s+$name\\s*=\\s*'([^']*)'").firstMatch(signinHtml);
      return m2?.group(1);
    }

    csrfParam = extractJs('csrfParam') ?? csrfParam;
    csrfCookie = extractJs('csrfCookieName') ?? csrfCookie;
    uriPrefix = extractJs('uriPrefix') ?? uriPrefix;

    String csrfHeader() {
      final token = cookieJar.get(_host, csrfCookie);
      return token != null && token.isNotEmpty ? '$csrfParam=$token' : '';
    }

    // Step 2: Locate Service
    final locateUrl = '$serviceUrl$uriPrefix/accounts/public/api/locate'
        '?cli_time=${Uri.encodeQueryComponent(cliTime)}'
        '&serviceurl=${Uri.encodeQueryComponent(serviceUrl)}';

    final locateHeaders = {
      'Accept': 'application/json,text/plain,*/*',
      'Referer': signinUrl,
      'User-Agent': PortalEndpoints.defaultUserAgent,
    };
    final csrfVal = csrfHeader();
    if (csrfVal.isNotEmpty) locateHeaders['X-ZCSRF-TOKEN'] = csrfVal;

    await _client.post(locateUrl, headers: locateHeaders, body: '');

    // Step 3: Account Lookup
    final lookupUrl = '$serviceUrl$uriPrefix/signin/v2/lookup/$encodedEmail';
    final lookupHeaders = {
      'Accept': 'application/json,text/plain,*/*',
      'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
      'Referer': signinUrl,
      'User-Agent': PortalEndpoints.defaultUserAgent,
    };
    final csrfVal3 = csrfHeader();
    if (csrfVal3.isNotEmpty) lookupHeaders['X-ZCSRF-TOKEN'] = csrfVal3;

    final lookupBody =
        'mode=primary&cli_time=${Uri.encodeQueryComponent(cliTime)}&serviceurl=${Uri.encodeQueryComponent(serviceUrl)}';

    final lookupResp = await _client.post(
      lookupUrl,
      headers: lookupHeaders,
      body: lookupBody,
    );

    String? digest;
    try {
      final lookupJson =
          jsonDecode(lookupResp.data.toString()) as Map<String, dynamic>;
      final lookupObj = (lookupJson['lookup'] ??
          lookupJson[lookupJson['resource_name']]) as Map<String, dynamic>?;
      digest = lookupObj?['digest'] as String?;
    } catch (_) {}

    // Step 4: Submit Password
    final passwordUrl =
        '$serviceUrl$uriPrefix/signin/v2/primary/password/$encodedEmail';
    final passwordHeaders = {
      'Accept': 'application/json,text/plain,*/*',
      'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
      'Referer': signinUrl,
      'User-Agent': PortalEndpoints.defaultUserAgent,
    };
    final csrfVal4 = csrfHeader();
    if (csrfVal4.isNotEmpty) passwordHeaders['X-ZCSRF-TOKEN'] = csrfVal4;

    final passwordParts = [
      'mode=primary',
      'cli_time=${Uri.encodeQueryComponent(cliTime)}',
      'serviceurl=${Uri.encodeQueryComponent(serviceUrl)}',
      'password=${Uri.encodeQueryComponent(password)}',
    ];
    if (digest != null && digest.isNotEmpty) {
      passwordParts.add('digest=${Uri.encodeQueryComponent(digest)}');
    }

    final passwordResp = await _client.post(
      passwordUrl,
      headers: passwordHeaders,
      body: passwordParts.join('&'),
    );

    // Step 5: Follow Continuation / Check Status
    final respStr = passwordResp.data.toString();
    if (respStr.contains('INVALID_PASSWORD') ||
        respStr.contains('invalid_password') ||
        respStr.contains('Incorrect password')) {
      return false;
    }

    // Step 6: Continuation unblocker if redirect_uri is returned
    try {
      final passJson = jsonDecode(respStr) as Map<String, dynamic>;
      final resName = passJson['resource_name'] as String? ?? 'password';
      final resObj = passJson[resName] as Map<String, dynamic>?;
      final redirectUri = resObj?['redirect_uri'] as String?;
      if (redirectUri != null && redirectUri.isNotEmpty) {
        await _client.get(redirectUri, headers: {'Referer': signinUrl});
      }
    } catch (_) {}

    return true;
  }

  // ─── Scrape Methods (With Cache-Busting Layer 2) ──────────────────────────────

  /// Fetches attendance records with Zoho cache-busting headers.
  /// Throws [SessionExpiredException] if session has expired or was invalidated.
  Future<List<AttendanceInput>> fetchAttendance() async {
    final epoch = DateTime.now().millisecondsSinceEpoch;
    final url = '${PortalEndpoints.attendanceUrl}?_t=$epoch';

    final response = await _client.get(
      url,
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': '${PortalEndpoints.academiaBaseUrl}/',
        'User-Agent': PortalEndpoints.defaultUserAgent,
      },
    );

    final rawHtml = response.data.toString();

    // Check if redirected to login
    if (rawHtml.contains('signin') ||
        rawHtml.contains('sign in to continue') ||
        rawHtml.contains('academic web services login')) {
      throw const SessionExpiredException(
          'Zoho session expired: landed on signin page');
    }

    final decoded = AcademiaDecoder.decodeHTMLFragment(rawHtml);
    return AcademiaParsers.parseAttendance(decoded);
  }

  /// Fetches timetable course list with cache-busting headers.
  Future<List<Map<String, dynamic>>> fetchTimetable() async {
    final epoch = DateTime.now().millisecondsSinceEpoch;
    final url = '${PortalEndpoints.personalTimetableUrl}?_t=$epoch';

    final response = await _client.get(
      url,
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': '${PortalEndpoints.academiaBaseUrl}/',
      },
    );

    final rawHtml = response.data.toString();
    if (rawHtml.contains('signin')) {
      throw const SessionExpiredException('Zoho session expired');
    }

    final decoded = AcademiaDecoder.decodeHTMLFragment(rawHtml);
    return AcademiaParsers.parseTimetableCourses(decoded);
  }

  /// Fetches marks from Academic_Reports.
  Future<List<Map<String, dynamic>>> fetchMarks() async {
    final epoch = DateTime.now().millisecondsSinceEpoch;
    final url = '${PortalEndpoints.academicReportsUrl}?_t=$epoch';

    final response = await _client.get(
      url,
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': '${PortalEndpoints.academiaBaseUrl}/',
      },
    );

    final rawHtml = response.data.toString();
    if (rawHtml.contains('signin')) {
      throw const SessionExpiredException('Zoho session expired');
    }

    final decoded = AcademiaDecoder.decodeHTMLFragment(rawHtml);
    return AcademiaParsers.parseMarks(decoded);
  }
}
