// lib/scrapers/academia/zoho_login_helpers.dart
// Pure helpers for the Zoho IAM sign-in flow used by SRM Academia.
// Ported from academia-backend/academia-scraper/cmd/loginprobe/parsers.go
// (lookup/password response parsing, page classification and the
// session-reminder / daily-limit continuation helpers).

import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

/// Why a sign-in attempt failed, so the UI can show a useful message.
enum AcademiaLoginFailure {
  invalidCredentials,
  accountNotFound,
  captchaRequired,
  tooManyAttempts,
  unexpected,
}

class AcademiaLoginException implements Exception {
  final AcademiaLoginFailure kind;

  /// Diagnostic detail (portal error code / step). Never contains the password.
  final String detail;

  const AcademiaLoginException(this.kind, [this.detail = '']);

  /// Message suitable for showing to the student.
  String get userMessage => switch (kind) {
        AcademiaLoginFailure.invalidCredentials =>
          'Incorrect NetID or password.',
        AcademiaLoginFailure.accountNotFound =>
          "SRM Academia doesn't recognise that NetID. Use the part before "
              '@srmist.edu.in, for example ab1234.',
        AcademiaLoginFailure.captchaRequired =>
          'SRM Academia wants a CAPTCHA after several failed attempts. Sign in '
              'once at academia.srmist.edu.in in a browser, then try again here.',
        AcademiaLoginFailure.tooManyAttempts =>
          'Too many sign-in attempts. Wait a few minutes and try again.',
        AcademiaLoginFailure.unexpected =>
          "Couldn't finish signing in to SRM Academia. Try again in a moment.",
      };

  @override
  String toString() => 'AcademiaLoginException($kind, $detail)';
}

/// Result of the `/signin/v2/lookup/<email>` call.
class ZohoLookupResult {
  final String identifier;
  final String digest;
  final String errorCode;
  final String message;
  const ZohoLookupResult({
    this.identifier = '',
    this.digest = '',
    this.errorCode = '',
    this.message = '',
  });
}

/// Result of the `/signin/v2/primary/<identifier>/password` call.
class ZohoPasswordResult {
  final String code;
  final String redirectUri;
  final String errorCode;
  final String message;
  const ZohoPasswordResult({
    this.code = '',
    this.redirectUri = '',
    this.errorCode = '',
    this.message = '',
  });
}

/// A follow-up request needed to get past a Zoho interstitial page.
class ZohoSessionAction {
  final String method;
  final String url;
  final String? body;
  final String? contentType;
  const ZohoSessionAction(this.method, this.url, {this.body, this.contentType});

  @override
  String toString() => '$method $url';
}

enum ZohoPageClass { sessions, dailyLimit, other }

class ZohoLoginHelpers {
  ZohoLoginHelpers._();

  /// Go `extractJSQuotedValue`.
  static String? extractJsQuotedValue(String raw, String name) {
    for (final pattern in [
      'var $name\\s*=\\s*"([^"]*)"',
      "var $name\\s*=\\s*'([^']*)'",
    ]) {
      final m = RegExp(pattern).firstMatch(raw);
      final value = m?.group(1);
      if (value != null && value.isNotEmpty) {
        return value.replaceAll(r'\/', '/').replaceAll(r'\"', '"');
      }
    }
    return null;
  }

  static Map<String, dynamic>? _json(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String _str(Map<String, dynamic>? m, String key) {
    final v = m?[key];
    return v == null ? '' : v.toString();
  }

  static Map<String, dynamic>? _nested(Map<String, dynamic>? m, String key) {
    if (m == null || key.isEmpty) return null;
    final v = m[key];
    return v is Map<String, dynamic> ? v : null;
  }

  /// Go `firstErrorCode`.
  static String _firstErrorCode(Map<String, dynamic>? m) {
    final errors = m?['errors'];
    if (errors is List && errors.isNotEmpty && errors.first is Map) {
      return (errors.first as Map)['code']?.toString() ?? '';
    }
    return '';
  }

  /// Go `parseLookupResponse`.
  static ZohoLookupResult parseLookup(String body) {
    final payload = _json(body);
    if (payload == null) return const ZohoLookupResult();
    final resource = _nested(payload, _str(payload, 'resource_name')) ??
        _nested(payload, 'lookup');
    return ZohoLookupResult(
      identifier: _str(resource, 'identifier'),
      digest: _str(resource, 'digest'),
      errorCode: _firstErrorCode(payload),
      message: _str(payload, 'localized_message'),
    );
  }

  /// Go `parsePasswordResponse`. [location] is the Location header, used when
  /// the body carries no redirect_uri.
  static ZohoPasswordResult parsePassword(String body, String? location) {
    final payload = _json(body);
    if (payload == null) {
      return ZohoPasswordResult(redirectUri: location ?? '');
    }
    final resource = _nested(payload, _str(payload, 'resource_name'));
    final redirect = _str(resource, 'redirect_uri');
    return ZohoPasswordResult(
      code: _str(payload, 'code'),
      redirectUri: redirect.isNotEmpty ? redirect : (location ?? ''),
      errorCode: _firstErrorCode(payload),
      message: _str(payload, 'localized_message'),
    );
  }

  /// Maps a Zoho error code / message to a failure kind
  /// (Go `classifyFromMessage`, plus the lookup "no such user" case).
  static AcademiaLoginFailure classifyError(String message, String errorCode,
      {bool duringLookup = false}) {
    final lower = message.toLowerCase();
    if (lower.contains('captcha') ||
        errorCode == 'IN107' ||
        errorCode == 'IN108') {
      return AcademiaLoginFailure.captchaRequired;
    }
    if (lower.contains('throttle') ||
        lower.contains('too many') ||
        lower.contains('temporarily blocked')) {
      return AcademiaLoginFailure.tooManyAttempts;
    }
    if (duringLookup &&
        (errorCode == 'U400' ||
            lower.contains('does not exist') ||
            lower.contains('not exist') ||
            lower.contains('no account') ||
            lower.contains('not found'))) {
      return AcademiaLoginFailure.accountNotFound;
    }
    if (lower.contains('incorrect password') ||
        lower.contains('invalid password') ||
        lower.contains('verify your email address') ||
        errorCode == 'U401' ||
        errorCode == 'IN102') {
      return AcademiaLoginFailure.invalidCredentials;
    }
    if (duringLookup) return AcademiaLoginFailure.accountNotFound;
    return AcademiaLoginFailure.unexpected;
  }

  /// Go `classifyPage`.
  static ZohoPageClass classifyPage(String pageUrl, String body) {
    final url = pageUrl.toLowerCase();
    final b = body.toLowerCase();
    if (url.contains('sessions-reminder') ||
        url.contains('block-sessions') ||
        url.contains('preannouncement/continue') ||
        url.contains('announcement/continue')) {
      return ZohoPageClass.sessions;
    }
    if (b.contains('daily sign-in limit') ||
        (b.contains('signed in') && b.contains('times today')) ||
        (url.contains('signin-block') && b.contains('i understand'))) {
      return ZohoPageClass.dailyLimit;
    }
    return ZohoPageClass.other;
  }

  static String _sortedQuery(Map<String, List<String>> params) {
    final keys = params.keys.toList()..sort();
    return [
      for (final k in keys)
        for (final v in params[k]!)
          '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v)}'
    ].join('&');
  }

  static String _trimRightSlash(String s) => s.replaceAll(RegExp(r'/+$'), '');

  /// Go `deriveSessionContinueURL`.
  static String deriveSessionContinueUrl(String currentUrl) {
    final Uri u;
    try {
      u = Uri.parse(currentUrl);
    } catch (_) {
      return '';
    }
    final nextPath = '${_trimRightSlash(u.path)}/next';
    if (u.path.contains('/preannouncement/block-sessions')) {
      return u
          .replace(path: nextPath, query: '')
          .toString()
          .replaceAll(RegExp(r'\?$'), '');
    }
    final params = Map<String, List<String>>.from(u.queryParametersAll);
    params['status'] = ['2'];
    return u.replace(path: nextPath, query: _sortedQuery(params)).toString();
  }

  /// Go `derivePreannouncementDeleteURL`.
  static String derivePreannouncementDeleteUrl(String currentUrl) {
    final Uri u;
    try {
      u = Uri.parse(currentUrl);
    } catch (_) {
      return '';
    }
    final idx = u.path.indexOf('/preannouncement/');
    if (idx < 0) return '';
    final path =
        '${_trimRightSlash(u.path.substring(0, idx))}/webclient/v1/announcement/pre/blocksessions';
    return u
        .replace(path: path, query: '')
        .toString()
        .replaceAll(RegExp(r'\?$'), '');
  }

  static String? _resolve(String base, String target) {
    try {
      return Uri.parse(base).resolve(target).toString();
    } catch (_) {
      return null;
    }
  }

  /// Go `extractSessionContinueURL`.
  static String extractSessionContinueUrl(String rawHtml, String currentUrl) {
    final doc = html_parser.parse(rawHtml);
    for (final selector in [
      '#continue_button[href]',
      '.continue_button[href]',
      'a[href*="/next?status=2"]',
      'a[href*="status=2"]',
      'button[href*="status=2"]',
    ]) {
      final href = doc.querySelector(selector)?.attributes['href']?.trim();
      if (href != null && href.isNotEmpty) {
        final resolved = _resolve(currentUrl, href);
        if (resolved != null) return resolved;
      }
    }
    final m = RegExp(r'href="([^"]*/next\?status=2[^"]*)"').firstMatch(rawHtml);
    if (m != null) return _resolve(currentUrl, m.group(1)!) ?? '';
    return '';
  }

  /// Go `resolveSessionActionURL`: only keeps links that look like a
  /// continue / terminate-sessions action.
  static String? resolveSessionActionUrl(String currentUrl, String rawTarget) {
    var target = rawTarget.trim();
    target = target.replaceAll(RegExp(r'''^["']+|["']+$'''), '');
    if (target.isEmpty) return null;
    final lower = target.toLowerCase();
    const markers = [
      'block-sessions',
      'sessions-reminder',
      'signin-block',
      'terminate',
      'status=2',
      'continue',
      'understand',
    ];
    if (!markers.any(lower.contains)) return null;
    return _resolve(currentUrl, target);
  }

  /// Go `extractJSURLCandidates`.
  static List<String> extractJsUrlCandidates(String raw) {
    final patterns = [
      r'''location\.href\s*=\s*['"]([^'"]+)['"]''',
      r'''window\.location\s*=\s*['"]([^'"]+)['"]''',
      r'''window\.open\(\s*['"]([^'"]+)['"]''',
      r'''['"]([^'"]*(?:block-sessions|sessions-reminder|status=2|terminate|continue)[^'"]*)['"]''',
    ];
    final seen = <String>{};
    final out = <String>[];
    for (final p in patterns) {
      for (final m in RegExp(p).allMatches(raw)) {
        final c = m.group(1)!.trim();
        if (c.isNotEmpty && seen.add(c)) out.add(c);
      }
    }
    return out;
  }

  /// Go `extractContinuationActions`.
  static List<ZohoSessionAction> extractContinuationActions(
      String rawHtml, String currentUrl) {
    final doc = html_parser.parse(rawHtml);
    final actions = <ZohoSessionAction>[];
    final seen = <String>{};
    void add(ZohoSessionAction a) {
      if (a.url.trim().isEmpty) return;
      if (seen.add('${a.method} ${a.url} ${a.body ?? ''}')) actions.add(a);
    }

    for (final el
        in doc.querySelectorAll('a[href], button[href], [data-href]')) {
      for (final attr in ['href', 'data-href']) {
        final target = el.attributes[attr];
        if (target == null) continue;
        final resolved = resolveSessionActionUrl(currentUrl, target);
        if (resolved != null) add(ZohoSessionAction('GET', resolved));
      }
    }

    for (final form in doc.querySelectorAll('form')) {
      var action = form.attributes['action'] ?? '';
      if (action.trim().isEmpty) action = currentUrl;
      final resolved = resolveSessionActionUrl(currentUrl, action);
      if (resolved == null) continue;
      final method = (form.attributes['method'] ?? 'GET').trim().toUpperCase();
      final values = <String, List<String>>{};
      for (final field in form.querySelectorAll('input,select,textarea')) {
        final name = field.attributes['name']?.trim() ?? '';
        if (name.isEmpty) continue;
        final type = (field.attributes['type'] ?? '').trim().toLowerCase();
        if (type == 'submit' || type == 'button') continue;
        values.putIfAbsent(name, () => []).add(field.attributes['value'] ?? '');
      }
      if (method != 'GET' && values.isNotEmpty) {
        add(ZohoSessionAction(method, resolved,
            body: _sortedQuery(values),
            contentType: 'application/x-www-form-urlencoded;charset=UTF-8'));
      } else {
        add(ZohoSessionAction(method.isEmpty ? 'GET' : method, resolved));
      }
    }

    for (final el in doc.querySelectorAll('[onclick]')) {
      for (final c in extractJsUrlCandidates(el.attributes['onclick'] ?? '')) {
        final resolved = resolveSessionActionUrl(currentUrl, c);
        if (resolved != null) add(ZohoSessionAction('GET', resolved));
      }
    }
    return actions;
  }
}
