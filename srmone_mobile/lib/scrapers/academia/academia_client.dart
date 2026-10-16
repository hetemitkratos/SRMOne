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

  /// Fetches a Zoho page fragment with cache-busting headers and decodes it.
  /// Retries once with the portal home as Referer on a 403/404.
  /// Throws [SessionExpiredException] if the response is a sign-in page.
  Future<String> fetchDecodedPage(String pageUrl, {String? refererHash}) async {
    Future<String> attempt(String referer) async {
      final epoch = DateTime.now().millisecondsSinceEpoch;
      final response = await _client.get(
        '$pageUrl?_t=$epoch',
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': referer,
          'User-Agent': PortalEndpoints.defaultUserAgent,
        },
      );
      final status = response.statusCode ?? 0;
      final rawHtml = response.data?.toString() ?? '';
      if (looksLikeSigninPage(response.realUri.toString(), rawHtml)) {
        throw const SessionExpiredException(
            'Zoho session expired: landed on signin page');
      }
      if (status == 403 || status == 404) {
        throw _RetryableStatus(status);
      }
      return AcademiaDecoder.decodeHTMLFragment(rawHtml);
    }

    const home = '${PortalEndpoints.academiaBaseUrl}/';
    try {
      return await attempt(refererHash != null
          ? '${PortalEndpoints.academiaBaseUrl}/$refererHash'
          : home);
    } on _RetryableStatus catch (e) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        return await attempt(home);
      } on _RetryableStatus {
        throw FormatException(
            'Academia returned HTTP ${e.status} for $pageUrl');
      }
    }
  }

  /// Ported from Go `looksLikeUnauthenticatedPage`. Deliberately does not match
  /// a bare "signin" substring, because logged-in pages link to sign-in URLs.
  static bool looksLikeSigninPage(String finalUrl, String body) {
    final url = finalUrl.toLowerCase();
    if (url.contains('/accounts/') || url.contains('/signin')) return true;
    final lower = body.toLowerCase();
    return lower.contains('sign in to continue') ||
        lower.contains('zoho accounts') ||
        lower.contains('academic web services login');
  }

  /// Fetches the decoded My_Time_Table_2023_24 page. It carries attendance,
  /// the student info table, the Test Performance (marks) table, the personal
  /// course list and advisors.
  Future<String> fetchAttendancePage() => fetchDecodedPage(
        PortalEndpoints.attendanceUrl,
        refererHash: '#Page:My_Time_Table_2023_24',
      );

  /// Fetches attendance records with Zoho cache-busting headers.
  /// Throws [SessionExpiredException] if session has expired or was invalidated.
  Future<List<AttendanceInput>> fetchAttendance() async {
    return AcademiaParsers.parseAttendance(await fetchAttendancePage());
  }

  /// Fetches the unified timetable slot grid for [batch] ("1" or "2").
  Future<Map<String, List<Map<String, dynamic>>>> fetchUnifiedSlotMap(
      String batch) async {
    final isBatch2 = batch.trim() == '2';
    final html = await fetchDecodedPage(
      isBatch2
          ? PortalEndpoints.unifiedTimetableBatch2
          : PortalEndpoints.unifiedTimetableBatch1,
      refererHash: isBatch2
          ? '#Page:Unified_Time_Table_2025_batch_2'
          : '#Page:Unified_Time_Table_2025_Batch_1',
    );
    return AcademiaParsers.parseUnifiedSlotMap(html);
  }

  /// Fetches the academic calendar for [sem] ('odd' | 'even'), trying the
  /// Academic_Reports page first and the legacy planner pages after it.
  /// Returns an empty list when no candidate page yields a calendar.
  Future<List<Map<String, dynamic>>> fetchCalendar(String sem) async {
    final semToken = sem.toUpperCase();
    final candidates = <(String, String)>[
      (PortalEndpoints.academicReportsUrl, '#Academic_Reports'),
      for (final year in ['2026_27', '2025_26', '2024_25'])
        (
          '${PortalEndpoints.academiaBaseUrl}/srm_university/academia-academic-services/page/Academic_Planner_${year}_$semToken',
          '#Page:Academic_Planner_${year}_$semToken',
        ),
    ];
    for (final (url, referer) in candidates) {
      try {
        final months = AcademiaParsers.parseCalendar(
            await fetchDecodedPage(url, refererHash: referer));
        if (months.isNotEmpty) return months;
      } on SessionExpiredException {
        rethrow;
      } catch (_) {
        // Try the next candidate page.
      }
    }
    return [];
  }
}

class _RetryableStatus implements Exception {
  final int status;
  const _RetryableStatus(this.status);
}
