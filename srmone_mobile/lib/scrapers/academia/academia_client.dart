// lib/scrapers/academia/academia_client.dart
// SRM Academia Zoho authentication and scraper client.
// Implements the 6-step Zoho login sequence, silent cookie rotation,
// and cache-busted data fetching.
// Ported from academia-backend/academia-scraper/cmd/loginprobe/login.go & client.go

import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';
import '../../core/constants/portal_endpoints.dart';
import '../../core/network/manual_redirect_client.dart';
import '../../core/network/simple_cookie_jar.dart';
import '../../domain/services/attendance_planner_math.dart';
import 'academia_decoder.dart';
import 'academia_parsers.dart';
import 'zoho_login_helpers.dart';

export 'zoho_login_helpers.dart'
    show AcademiaLoginException, AcademiaLoginFailure;

class SessionExpiredException implements Exception {
  final String message;
  const SessionExpiredException(this.message);

  @override
  String toString() => 'SessionExpiredException: $message';
}

class AcademiaClient {
  final SimpleCookieJar cookieJar;
  final ManualRedirectClient _client;

  /// [dio] is only for tests (fake HTTP adapter).
  AcademiaClient({required this.cookieJar, Dio? dio})
      : _client = ManualRedirectClient(cookieJar: cookieJar, dio: dio);

  static const String _host = 'academia.srmist.edu.in';
  static const String _htmlAccept =
      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
  static const String _jsonAccept = 'application/json,text/plain,*/*';
  static const String _formType =
      'application/x-www-form-urlencoded;charset=UTF-8';

  static const String _signinUrl = '${PortalEndpoints.academiaBaseUrl}'
      '${PortalEndpoints.signinPath}'
      '?serviceurl=https%3A%2F%2Facademia.srmist.edu.in';

  String _csrfParam = 'iamcsrcoo';
  String _csrfCookie = 'iamcsr';

  /// Sends a request with the same default headers as Go `FHClient.DoRequest`:
  /// User-Agent, Accept-Language, the sign-in page as default Referer and the
  /// `X-ZCSRF-TOKEN` header taken from the CSRF cookie. Bodies are read as
  /// plain text so JSON responses are not auto-decoded by Dio.
  Future<Response<dynamic>> _send(
    String method,
    String url, {
    Map<String, String> headers = const {},
    String? body,
    String? contentType,
    bool followRedirects = true,
  }) {
    final token = cookieJar.get(_host, _csrfCookie);
    return _client.request(
      method,
      url,
      headers: {
        'User-Agent': PortalEndpoints.defaultUserAgent,
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': _signinUrl,
        if (token != null && token.isNotEmpty)
          'X-ZCSRF-TOKEN': '$_csrfParam=$token',
        ...headers,
      },
      data: body,
      contentType: contentType,
      responseType: ResponseType.plain,
      followRedirects: followRedirects,
    );
  }

  static String _body(Response<dynamic> r) => r.data?.toString() ?? '';

  /// Zoho's NetID form accepts "ab1234" or "ab1234@srmist.edu.in".
  static String normalizeNetId(String netId) {
    var email = netId.trim();
    if (!email.contains('@')) email = '$email@srmist.edu.in';
    return email.toLowerCase();
  }

  /// Like Go `url.PathEscape`: keeps '@' readable in the path segment.
  static String _pathEscape(String s) =>
      Uri.encodeComponent(s).replaceAll('%40', '@');

  /// True once Zoho has issued the Academia session cookie.
  bool get hasSessionCookie {
    final v = cookieJar.get(_host, 'JSESSIONID');
    return v != null && v.isNotEmpty;
  }

  // ─── Zoho Login (port of Go LoginSession.FullLogin) ─────────────────────────

  /// Signs in to Academia and fills [cookieJar] with a fresh session.
  ///
  /// Returns false when Zoho rejects the NetID/password. Throws
  /// [AcademiaLoginException] for other sign-in problems (unknown NetID,
  /// CAPTCHA demanded, interstitial pages that could not be passed) and a
  /// DioException for network errors.
  Future<bool> login(String netId, String password) async {
    try {
      await _login(netId, password);
      return true;
    } on AcademiaLoginException catch (e) {
      if (e.kind == AcademiaLoginFailure.invalidCredentials) return false;
      rethrow;
    }
  }

  Future<void> _login(String netId, String password) async {
    final email = normalizeNetId(netId);
    var serviceUrl = PortalEndpoints.academiaBaseUrl;
    var uriPrefix = '/accounts/p/${PortalEndpoints.defaultPortalId}';
    final cliTime = DateTime.now().toUtc().millisecondsSinceEpoch.toString();

    // Old session cookies can make Zoho skip straight to an interstitial.
    cookieJar.clearHost(_host);

    // 1. Sign-in page: sets the CSRF cookie and tells us the URI prefix.
    final signin =
        await _send('GET', _signinUrl, headers: {'Accept': _htmlAccept});
    final signinHtml = _body(signin);
    _csrfParam =
        ZohoLoginHelpers.extractJsQuotedValue(signinHtml, 'csrfParam') ??
            _csrfParam;
    _csrfCookie =
        ZohoLoginHelpers.extractJsQuotedValue(signinHtml, 'csrfCookieName') ??
            _csrfCookie;
    uriPrefix =
        ZohoLoginHelpers.extractJsQuotedValue(signinHtml, 'uriPrefix') ??
            uriPrefix;
    final pageService =
        RegExp(r"serviceUrl\s*=\s*'([^']+)'").firstMatch(signinHtml)?.group(1);
    if (pageService != null && pageService.startsWith('http')) {
      serviceUrl = pageService.replaceAll(r'\/', '/');
    }
    final q = 'cli_time=${Uri.encodeQueryComponent(cliTime)}'
        '&serviceurl=${Uri.encodeQueryComponent(serviceUrl)}';

    // 2. Locate.
    await _send('POST', '$serviceUrl$uriPrefix/accounts/public/api/locate?$q',
        headers: {'Accept': _jsonAccept},
        contentType: _formType,
        followRedirects: false);

    // 3. Lookup: returns the account identifier and a digest for step 4.
    final lookupResp = await _send(
        'POST', '$serviceUrl$uriPrefix/signin/v2/lookup/${_pathEscape(email)}',
        headers: {'Accept': _jsonAccept},
        body: 'mode=primary&$q',
        contentType: _formType,
        followRedirects: false);
    final lookup = ZohoLoginHelpers.parseLookup(_body(lookupResp));
    if (lookup.identifier.isEmpty || lookup.digest.isEmpty) {
      final status = lookupResp.statusCode ?? 0;
      if (lookup.errorCode.isEmpty && lookup.message.isEmpty) {
        throw AcademiaLoginException(
            AcademiaLoginFailure.unexpected, 'lookup returned $status');
      }
      throw AcademiaLoginException(
          ZohoLoginHelpers.classifyError(lookup.message, lookup.errorCode,
              duringLookup: true),
          'lookup ${lookup.errorCode}');
    }

    // 4. Password: JSON body, digest in the query string. Zoho answers 200
    //    with an error code (e.g. IN102) when the password is wrong.
    final passwordResp = await _send(
        'POST',
        '$serviceUrl$uriPrefix/signin/v2/primary/'
            '${_pathEscape(lookup.identifier)}/password'
            '?digest=${Uri.encodeQueryComponent(lookup.digest)}&$q',
        headers: {'Accept': _jsonAccept},
        body: jsonEncode({
          'passwordauth': {'password': password.trim()}
        }),
        contentType: _formType,
        followRedirects: false);
    final pwd = ZohoLoginHelpers.parsePassword(
        _body(passwordResp), passwordResp.headers.value('location'));
    final pwdStatus = passwordResp.statusCode ?? 0;
    if (pwd.redirectUri.isEmpty && pwd.errorCode.isNotEmpty) {
      throw AcademiaLoginException(
          ZohoLoginHelpers.classifyError(pwd.message, pwd.errorCode),
          'password ${pwd.errorCode}');
    }
    if (pwdStatus < 200 || pwdStatus > 399) {
      throw AcademiaLoginException(
          AcademiaLoginFailure.unexpected, 'password returned $pwdStatus');
    }

    // 5. Open the redirect target and get past any interstitials.
    final target = pwd.redirectUri.isNotEmpty ? pwd.redirectUri : serviceUrl;
    var page = await _send('GET', target, headers: {'Accept': _htmlAccept});
    page = await _completePostLoginFlow(page);

    // 6. A real session has the JSESSIONID cookie.
    if (!hasSessionCookie) {
      throw const AcademiaLoginException(
          AcademiaLoginFailure.unexpected, 'no JSESSIONID after sign-in');
    }
  }

  static String _url(Response<dynamic> r) => r.realUri.toString();

  /// Go `completePostLoginFlow`: handles the "too many active sessions" and
  /// "daily sign-in limit" pages Zoho shows before the portal.
  Future<Response<dynamic>> _completePostLoginFlow(
      Response<dynamic> current) async {
    var last = current;
    for (var step = 0; step < 6; step++) {
      switch (ZohoLoginHelpers.classifyPage(_url(last), _body(last))) {
        case ZohoPageClass.sessions:
          last = await _completeSessionTermination(last);
        case ZohoPageClass.dailyLimit:
          last = await _runActions(last, 'daily sign-in warning',
              returnFirst: true);
        case ZohoPageClass.other:
          return last;
      }
    }
    throw const AcademiaLoginException(
        AcademiaLoginFailure.unexpected, 'post-login flow did not settle');
  }

  /// Go `completeSessionTermination`.
  Future<Response<dynamic>> _completeSessionTermination(
      Response<dynamic> current) async {
    var last = current;
    for (var step = 0; step < 4; step++) {
      final url = _url(last);
      if (ZohoLoginHelpers.classifyPage(url, _body(last)) !=
          ZohoPageClass.sessions) {
        return last;
      }
      if (url.toLowerCase().contains('/preannouncement/block-sessions')) {
        last = await _completePreannouncementTermination(last);
        continue;
      }
      last = await _runActions(last, 'session reminder');
    }
    if (ZohoLoginHelpers.classifyPage(_url(last), _body(last)) ==
        ZohoPageClass.sessions) {
      throw const AcademiaLoginException(
          AcademiaLoginFailure.unexpected, 'session reminder did not complete');
    }
    return last;
  }

  /// Runs the continue/terminate actions found on an interstitial page.
  /// Session pages stop at the first action that leaves the sessions page;
  /// the daily-limit page stops at the first action that succeeds.
  Future<Response<dynamic>> _runActions(Response<dynamic> current, String what,
      {bool returnFirst = false}) async {
    final url = _url(current);
    final html = _body(current);
    var actions = ZohoLoginHelpers.extractContinuationActions(html, url);
    if (actions.isEmpty) {
      var fallback = ZohoLoginHelpers.extractSessionContinueUrl(html, url);
      if (fallback.isEmpty) {
        fallback = ZohoLoginHelpers.deriveSessionContinueUrl(url);
      }
      if (fallback.isNotEmpty) actions = [ZohoSessionAction('GET', fallback)];
    }
    if (actions.isEmpty) {
      throw AcademiaLoginException(
          AcademiaLoginFailure.unexpected, '$what had no continue action');
    }
    Object? lastError;
    var last = current;
    var progressed = false;
    for (final action in actions) {
      try {
        last = await _send(action.method, action.url,
            headers: {'Accept': _htmlAccept, 'Referer': url},
            body: action.body,
            contentType: action.contentType);
      } on DioException catch (e) {
        lastError = e;
        continue;
      }
      progressed = true;
      if (returnFirst ||
          ZohoLoginHelpers.classifyPage(_url(last), _body(last)) !=
              ZohoPageClass.sessions) {
        return last;
      }
    }
    if (!progressed) {
      throw AcademiaLoginException(
          AcademiaLoginFailure.unexpected, '$what failed: $lastError');
    }
    return last;
  }

  /// Go `completePreannouncementSessionTermination`: DELETE the other
  /// sessions, then continue to `<page>/next`.
  Future<Response<dynamic>> _completePreannouncementTermination(
      Response<dynamic> current) async {
    final url = _url(current);
    final deleteUrl = ZohoLoginHelpers.derivePreannouncementDeleteUrl(url);
    final nextUrl = ZohoLoginHelpers.deriveSessionContinueUrl(url);
    if (deleteUrl.isEmpty || nextUrl.isEmpty) {
      throw const AcademiaLoginException(
          AcademiaLoginFailure.unexpected, 'block-sessions page unreadable');
    }
    final del = await _send('DELETE', deleteUrl,
        headers: {
          'Accept': _jsonAccept,
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': url,
        },
        followRedirects: false);
    final status = del.statusCode ?? 0;
    if (status < 200 || status > 299) {
      throw AcademiaLoginException(AcademiaLoginFailure.unexpected,
          'terminate sessions returned $status');
    }
    return _send('GET', nextUrl,
        headers: {'Accept': _htmlAccept, 'Referer': url});
  }

  // ─── Scrape Methods (With Cache-Busting Layer 2) ──────────────────────────────

  /// Fetches a Zoho page fragment with cache-busting headers and decodes it.
  /// Retries once with the portal home as Referer on a 403/404.
  /// Throws [SessionExpiredException] if the response is a sign-in page.
  Future<String> fetchDecodedPage(String pageUrl, {String? refererHash}) =>
      fetchParsedPage(pageUrl, _identity, refererHash: refererHash);

  /// Like [fetchDecodedPage], but decodes the page and runs [parse] on it in
  /// a background isolate, so large pages never stall the UI thread.
  /// [parse] must be a top-level or static function (or a closure that only
  /// captures sendable values).
  Future<T> fetchParsedPage<T>(
      String pageUrl, T Function(String decodedHtml) parse,
      {String? refererHash}) async {
    final raw = await _fetchRawPage(pageUrl, refererHash: refererHash);
    return _decodeAndParse(raw, parse);
  }

  static String _identity(String s) => s;

  /// Static so the isolate closure captures only [raw] and [parse].
  static Future<T> _decodeAndParse<T>(
          String raw, T Function(String decodedHtml) parse) =>
      Isolate.run(() => parse(AcademiaDecoder.decodeHTMLFragment(raw)));

  Future<String> _fetchRawPage(String pageUrl, {String? refererHash}) async {
    Future<String> attempt(String referer) async {
      final epoch = DateTime.now().millisecondsSinceEpoch;
      // Like Go fetchDecodedFragment, don't follow redirects: an
      // unauthenticated page request is redirected to the sign-in page.
      final response = await _send(
        'GET',
        '$pageUrl?_t=$epoch',
        headers: {
          'Accept': _htmlAccept,
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': referer,
        },
        followRedirects: false,
      );
      final status = response.statusCode ?? 0;
      final rawHtml = _body(response);
      if (status >= 300 && status < 400) {
        throw SessionExpiredException(
            'Zoho redirected the page request ($status)');
      }
      if (status == 401 ||
          looksLikeSigninPage(response.realUri.toString(), rawHtml)) {
        throw const SessionExpiredException(
            'Zoho session expired: landed on signin page');
      }
      if (status == 403 || status == 404) {
        throw _RetryableStatus(status);
      }
      return rawHtml;
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

  static const _attendanceReferer = '#Page:My_Time_Table_2023_24';

  /// Fetches the decoded My_Time_Table_2023_24 page. It carries attendance,
  /// the student info table, the Test Performance (marks) table, the personal
  /// course list and advisors.
  Future<String> fetchAttendancePage() => fetchDecodedPage(
        PortalEndpoints.attendanceUrl,
        refererHash: _attendanceReferer,
      );

  /// Fetches the My_Time_Table page and parses every section of it in one
  /// pass, off the UI thread.
  Future<AcademiaPageData> fetchAttendancePageData() => fetchParsedPage(
        PortalEndpoints.attendanceUrl,
        AcademiaParsers.parseAttendancePage,
        refererHash: _attendanceReferer,
      );

  /// Fetches attendance records with Zoho cache-busting headers.
  /// Throws [SessionExpiredException] if session has expired or was invalidated.
  Future<List<AttendanceInput>> fetchAttendance() => fetchParsedPage(
        PortalEndpoints.attendanceUrl,
        AcademiaParsers.parseAttendance,
        refererHash: _attendanceReferer,
      );

  /// Fetches the unified timetable slot grid for [batch] ("1" or "2").
  Future<Map<String, List<Map<String, dynamic>>>> fetchUnifiedSlotMap(
      String batch) {
    final isBatch2 = batch.trim() == '2';
    return fetchParsedPage(
      isBatch2
          ? PortalEndpoints.unifiedTimetableBatch2
          : PortalEndpoints.unifiedTimetableBatch1,
      AcademiaParsers.parseUnifiedSlotMap,
      refererHash: isBatch2
          ? '#Page:Unified_Time_Table_2025_batch_2'
          : '#Page:Unified_Time_Table_2025_Batch_1',
    );
  }

  /// Calendar pages already requested by this client, so the shared
  /// Academic_Reports page is downloaded once even when both semesters are
  /// fetched at the same time.
  final Map<String, Future<List<Map<String, dynamic>>>> _calendarPages = {};

  Future<List<Map<String, dynamic>>> _calendarPage(String url, String referer) {
    return _calendarPages.putIfAbsent(
        url,
        () => fetchParsedPage(url, AcademiaParsers.parseCalendar,
            refererHash: referer));
  }

  /// Fetches the academic calendar for [sem] ('odd' | 'even'), trying the
  /// Academic_Reports page first and the legacy planner pages after it.
  /// The planner pages are requested together; the first one (in order)
  /// that yields a calendar wins. Returns an empty list when none does.
  Future<List<Map<String, dynamic>>> fetchCalendar(String sem) async {
    final semToken = sem.toUpperCase();

    Future<List<Map<String, dynamic>>> tryPage(String url, String referer) =>
        _calendarPage(url, referer).catchError((Object e) {
          if (e is SessionExpiredException) throw e;
          return <Map<String, dynamic>>[];
        });

    final reports =
        await tryPage(PortalEndpoints.academicReportsUrl, '#Academic_Reports');
    if (reports.isNotEmpty) return reports;

    final planners = await Future.wait([
      for (final year in ['2026_27', '2025_26', '2024_25'])
        tryPage(
          '${PortalEndpoints.academiaBaseUrl}/srm_university/academia-academic-services/page/Academic_Planner_${year}_$semToken',
          '#Page:Academic_Planner_${year}_$semToken',
        ),
    ]);
    return planners.firstWhere((m) => m.isNotEmpty, orElse: () => []);
  }
}

class _RetryableStatus implements Exception {
  final int status;
  const _RetryableStatus(this.status);
}
