// Tests the Zoho sign-in flow against a fake Academia server that mimics the
// responses the Go loginprobe scraper handles.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/network/simple_cookie_jar.dart';
import 'package:srmone_mobile/scrapers/academia/academia_client.dart';
import 'package:srmone_mobile/scrapers/academia/zoho_login_helpers.dart';

class _Req {
  final String method;
  final Uri uri;
  final Map<String, dynamic> headers;
  final String body;
  _Req(this.method, this.uri, this.headers, this.body);
}

typedef _Handler = ResponseBody Function(_Req req);

class _FakeAdapter implements HttpClientAdapter {
  final _Handler handler;
  final List<_Req> log = [];
  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    var body = '';
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      body = utf8.decode(bytes);
    } else if (options.data is String) {
      body = options.data as String;
    }
    final req = _Req(options.method, options.uri, options.headers, body);
    log.add(req);
    return handler(req);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _resp(int status,
    {String body = '',
    List<String> cookies = const [],
    String? location,
    String contentType = 'text/html'}) {
  return ResponseBody.fromString(body, status, headers: {
    'content-type': [contentType],
    if (cookies.isNotEmpty) 'set-cookie': cookies,
    if (location != null) 'location': [location],
  });
}

const _signinHtml = '''
<html><script>
var csrfParam = "iamcsrcoo";
var csrfCookieName = "iamcsr";
var uriPrefix = "/accounts/p/40-10002227248";
</script></html>''';

/// A fake Academia that requires the Go-style password request and shows the
/// "terminate other sessions" interstitial before the portal.
class _FakeAcademia {
  final String password = 'secret-pw';
  final bool knownUser;
  final bool showSessionsPage;
  bool deletedSessions = false;

  _FakeAcademia({this.knownUser = true, this.showSessionsPage = true});

  ResponseBody handle(_Req r) {
    final path = r.uri.path;
    const prefix = '/accounts/p/40-10002227248';
    if (r.method == 'GET' && path == '$prefix/signin') {
      return _resp(200,
          body: _signinHtml, cookies: ['iamcsr=csrf123; Path=/; Secure']);
    }
    if (path == '$prefix/accounts/public/api/locate') {
      return _resp(200, body: '{}', contentType: 'application/json');
    }
    if (path.startsWith('$prefix/signin/v2/lookup/')) {
      if (!knownUser) {
        return _resp(200,
            contentType: 'application/json',
            body: jsonEncode({
              'code': 'U400',
              'localized_message': 'This account cannot be found.',
              'errors': [
                {'code': 'U400', 'message': 'User does not exist'}
              ],
            }));
      }
      return _resp(200,
          contentType: 'application/json',
          body: jsonEncode({
            'code': 'SI201',
            'resource_name': 'lookup',
            'lookup': {'identifier': 'ID-42', 'digest': 'dg-1'},
          }));
    }
    if (path == '$prefix/signin/v2/primary/ID-42/password') {
      final pw = (jsonDecode(r.body) as Map)['passwordauth']['password'];
      if (pw != password) {
        return _resp(200,
            contentType: 'application/json',
            body: jsonEncode({
              'code': 'IN102',
              'localized_message': 'Incorrect password. Please try again.',
              'errors': [
                {'code': 'IN102', 'message': 'Incorrect password.'}
              ],
            }));
      }
      return _resp(200,
          contentType: 'application/json',
          cookies: ['iamcsr=csrf456; Path=/'],
          body: jsonEncode({
            'code': 'SI303',
            'resource_name': 'passwordauth',
            'passwordauth': {
              'redirect_uri': 'https://academia.srmist.edu.in/portal-redirect',
            },
          }));
    }
    if (path == '/portal-redirect') {
      return showSessionsPage && !deletedSessions
          ? _resp(302,
              location: '$prefix/preannouncement/block-sessions?serviceurl=x')
          : _resp(302, location: '/');
    }
    if (path == '$prefix/preannouncement/block-sessions') {
      return _resp(200, body: '<html>Terminate other sessions</html>');
    }
    if (r.method == 'DELETE' &&
        path == '$prefix/webclient/v1/announcement/pre/blocksessions') {
      deletedSessions = true;
      return _resp(204);
    }
    if (path == '$prefix/preannouncement/block-sessions/next') {
      return deletedSessions ? _resp(302, location: '/') : _resp(403);
    }
    if (path == '/') {
      return _resp(200,
          body: '<html>Academia home</html>',
          cookies: ['JSESSIONID=sess-1; Path=/; HttpOnly']);
    }
    if (path.contains('/page/')) {
      final authed =
          (r.headers['Cookie'] ?? '').toString().contains('JSESSIONID');
      return authed
          ? _resp(200, body: '<table><tr><td>ok</td></tr></table>')
          : _resp(302, location: '$prefix/signin?serviceurl=x');
    }
    return _resp(404);
  }
}

(AcademiaClient, _FakeAdapter, SimpleCookieJar) _client(_FakeAcademia fake) {
  final adapter = _FakeAdapter(fake.handle);
  final dio = Dio(BaseOptions(
    followRedirects: false,
    validateStatus: (s) => s != null && s < 500,
  ))
    ..httpClientAdapter = adapter;
  final jar = SimpleCookieJar();
  return (AcademiaClient(cookieJar: jar, dio: dio), adapter, jar);
}

void main() {
  group('AcademiaClient.login', () {
    test('runs the Zoho flow, clears other sessions and gets JSESSIONID',
        () async {
      final fake = _FakeAcademia();
      final (client, adapter, jar) = _client(fake);

      expect(await client.login('ab1234', 'secret-pw'), isTrue);
      expect(jar.get('academia.srmist.edu.in', 'JSESSIONID'), 'sess-1');
      expect(fake.deletedSessions, isTrue);

      final lookup =
          adapter.log.firstWhere((r) => r.uri.path.contains('/lookup/'));
      expect(lookup.uri.path, endsWith('/lookup/ab1234@srmist.edu.in'));
      expect(lookup.headers['X-ZCSRF-TOKEN'], 'iamcsrcoo=csrf123');

      final pw =
          adapter.log.firstWhere((r) => r.uri.path.endsWith('/password'));
      expect(pw.method, 'POST');
      expect(pw.uri.queryParameters['digest'], 'dg-1');
      expect(jsonDecode(pw.body), {
        'passwordauth': {'password': 'secret-pw'}
      });
    });

    test('accepts a full NetID email', () async {
      final (client, adapter, _) = _client(_FakeAcademia());
      expect(await client.login(' AB1234@srmist.edu.in ', 'secret-pw'), isTrue);
      final lookup =
          adapter.log.firstWhere((r) => r.uri.path.contains('/lookup/'));
      expect(lookup.uri.path, endsWith('/lookup/ab1234@srmist.edu.in'));
    });

    test('returns false for a wrong password', () async {
      final (client, _, jar) = _client(_FakeAcademia());
      expect(await client.login('ab1234', 'wrong'), isFalse);
      expect(jar.get('academia.srmist.edu.in', 'JSESSIONID'), isNull);
    });

    test('reports an unknown NetID', () async {
      final (client, _, _) = _client(_FakeAcademia(knownUser: false));
      await expectLater(
        client.login('zz9999', 'secret-pw'),
        throwsA(isA<AcademiaLoginException>().having(
            (e) => e.kind, 'kind', AcademiaLoginFailure.accountNotFound)),
      );
    });

    test('page fetch works after login and expires without a session',
        () async {
      final (client, _, jar) = _client(_FakeAcademia(showSessionsPage: false));
      await expectLater(client.fetchAttendancePage(),
          throwsA(isA<SessionExpiredException>()));
      expect(await client.login('ab1234', 'secret-pw'), isTrue);
      expect(await client.fetchAttendancePage(), contains('ok'));
      expect(jar.get('academia.srmist.edu.in', 'JSESSIONID'), 'sess-1');
    });
  });

  group('ZohoLoginHelpers', () {
    test('derives the session continue and delete URLs', () {
      const block =
          'https://academia.srmist.edu.in/accounts/p/1/preannouncement/block-sessions?x=1';
      expect(ZohoLoginHelpers.deriveSessionContinueUrl(block),
          'https://academia.srmist.edu.in/accounts/p/1/preannouncement/block-sessions/next');
      expect(ZohoLoginHelpers.derivePreannouncementDeleteUrl(block),
          'https://academia.srmist.edu.in/accounts/p/1/webclient/v1/announcement/pre/blocksessions');
      expect(
          ZohoLoginHelpers.deriveSessionContinueUrl(
              'https://a.example/announcement/sessions-reminder?b=2'),
          'https://a.example/announcement/sessions-reminder/next?b=2&status=2');
    });

    test('classifies interstitial pages', () {
      expect(ZohoLoginHelpers.classifyPage('https://x/sessions-reminder', ''),
          ZohoPageClass.sessions);
      expect(
          ZohoLoginHelpers.classifyPage(
              'https://x/y', 'You have signed in 18 times today'),
          ZohoPageClass.dailyLimit);
      expect(ZohoLoginHelpers.classifyPage('https://x/', '<html/>'),
          ZohoPageClass.other);
    });

    test('extracts continue actions from links, forms and onclick', () {
      const html = '''
<a href="/other">Help</a>
<a href="/announcement/sessions-reminder/next?status=2">Continue</a>
<form action="/terminate" method="post"><input name="all" value="1"><input type="submit" name="go"></form>
<button onclick="window.location='/signin-block/understand'">I understand</button>''';
      final actions = ZohoLoginHelpers.extractContinuationActions(
          html, 'https://a.example/announcement/sessions-reminder');
      expect(actions.map((a) => a.toString()), [
        'GET https://a.example/announcement/sessions-reminder/next?status=2',
        'POST https://a.example/terminate',
        'GET https://a.example/signin-block/understand',
      ]);
      expect(actions[1].body, 'all=1');
    });

    test('maps Zoho error codes', () {
      expect(ZohoLoginHelpers.classifyError('Incorrect password', 'IN102'),
          AcademiaLoginFailure.invalidCredentials);
      expect(ZohoLoginHelpers.classifyError('', 'IN107'),
          AcademiaLoginFailure.captchaRequired);
      expect(
          ZohoLoginHelpers.classifyError('User does not exist', 'U400',
              duringLookup: true),
          AcademiaLoginFailure.accountNotFound);
    });
  });
}
