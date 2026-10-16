// test/scrapers/faculty_test.dart
// Faculty directory scraper against sanitized copies of the real
// www.srmist.edu.in search and profile pages.

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/scrapers/faculty/faculty_client.dart';
import 'package:srmone_mobile/scrapers/faculty/faculty_name.dart';
import 'package:srmone_mobile/scrapers/faculty/faculty_parser.dart';

String _fixture(String name) =>
    File('test/fixtures/faculty/$name').readAsStringSync();

class _FakeSite implements HttpClientAdapter {
  final Map<String, String> pages; // path or "?s=term" -> html
  final List<Uri> requests = [];
  _FakeSite(this.pages);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final uri = options.uri;
    requests.add(uri);
    final key = uri.queryParameters.containsKey('s')
        ? '?s=${uri.queryParameters['s']}'
        : uri.path;
    final html = pages[key];
    if (html == null) {
      return ResponseBody.fromString('Not found', 404, headers: {
        'content-type': ['text/html'],
      });
    }
    return ResponseBody.fromString(html, 200, headers: {
      'content-type': ['text/html; charset=utf-8'],
    });
  }

  @override
  void close({bool force = false}) {}
}

FacultyClient _client(_FakeSite site) {
  final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s < 500))
    ..httpClientAdapter = site;
  return FacultyClient(dio: dio);
}

FacultyParsedProfile _p(String name) => FacultyParsedProfile(
      name: name,
      photoUrl: '',
      designation: '',
      department: '',
      email: '',
      campus: '',
      experience: '',
      researchInterest: '',
      courses: '',
      profileUrl: '',
    );

void main() {
  group('FacultyNameQuery', () {
    test('drops the staff ID and title before searching', () {
      final q = FacultyNameQuery.parse('Dr. Samsudeen S (103528)');
      expect(q.cleanName, 'Dr. Samsudeen S');
      expect(q.searchTerms, ['Samsudeen S', 'Samsudeen']);
      expect(q.slugCandidates.first, 'dr-samsudeen-s');
    });

    test('strips dotted leading initials', () {
      expect(FacultyNameQuery.parse('Dr.J.Shobana (102927)').searchTerms,
          ['Shobana']);
      expect(FacultyNameQuery.parse('Mr.M.Palanivendhan (101735)').searchTerms,
          ['Palanivendhan']);
      expect(
          FacultyNameQuery.parse('S.Sindhu (101956)').searchTerms, ['Sindhu']);
    });

    test('keeps names that merely start like a title', () {
      expect(FacultyNameQuery.parse('Drishya K').searchName, 'Drishya K');
    });

    test('guesses slugs with the trailing initial moved around', () {
      final slugs =
          FacultyNameQuery.parse('Dr.Dhanalakshmi J (103427)').slugCandidates;
      expect(slugs, containsAll(['dr-dhanalakshmi-j', 'dr-j-dhanalakshmi']));
      final lead = FacultyNameQuery.parse('R.Mangalagowri').slugCandidates;
      expect(lead, containsAll(['mangalagowri-r', 'dr-mangalagowri-r']));
    });
  });

  group('FacultyClient.parseSearchSlugs', () {
    test('reads results from the search-result list, not news articles', () {
      expect(FacultyClient.parseSearchSlugs(_fixture('search_results.html')),
          ['dr-jane-doe', 'dr-jane-doering']);
    });

    test('finds nothing on a no-results page, ignoring menu links', () {
      expect(FacultyClient.parseSearchSlugs(_fixture('search_empty.html')),
          isEmpty);
    });
  });

  group('FacultyParser.parseProfile', () {
    final p = FacultyParser.parseProfile(_fixture('profile.html'),
        'https://www.srmist.edu.in/faculty/dr-jane-doe/');

    test('reads name, photo and contact details', () {
      expect(p.name, 'Dr. Jane Doe');
      expect(p.photoUrl,
          'https://www.srmist.edu.in/wp-content/uploads/2025/04/srm-faculty-00.jpg');
      expect(p.designation, 'Assistant Professor');
      expect(p.specialization, 'Data Analytics [Applied to Example Domains]');
      expect(p.email, 'janedoe@example.edu.in');
    });

    test('takes department, college and campus from the CAMPUS line', () {
      expect(p.department, 'Department of Computing Technologies');
      expect(p.college, 'Faculty of Engineering & Technology');
      expect(p.campus, 'Kattankulathur - Chennai');
    });

    test('splits experience, research interest and courses', () {
      expect(p.experience, '7.8 years of experience');
      expect(p.researchInterest,
          'Data Analytics, Integration of Data Analytics to Other Domains');
      expect(p.courses, 'Big Data Analytics, Data Science, Cloud');
    });
  });

  group('FacultyClient.pickBestMatch', () {
    test('prefers the exact name over a longer one', () {
      final best = FacultyClient.pickBestMatch(
          'Dr. Jane Doe', [_p('Dr. Jane Doering'), _p('Dr. Jane Doe')]);
      expect(best?.name, 'Dr. Jane Doe');
    });

    test('rejects profiles that share no real name word', () {
      expect(FacultyClient.pickBestMatch('Dr.J.Shobana', [_p('Dr. J. Kumar')]),
          isNull);
    });
  });

  group('FacultyClient.lookup', () {
    test('finds a portal name with a staff ID via the cleaned search',
        () async {
      final site = _FakeSite({
        '?s=Jane Doe': _fixture('search_results.html'),
        '?s=Dr. Jane Doe (100001)': _fixture('search_empty.html'),
        '/faculty/dr-jane-doe/': _fixture('profile.html'),
        '/faculty/dr-jane-doering/': _fixture('profile.html')
            .replaceAll('Dr. Jane Doe - SRMIST', 'Dr. Jane Doering - SRMIST'),
      });
      final profile = await _client(site).lookup('Dr. Jane Doe (100001)');
      expect(profile?.name, 'Dr. Jane Doe');
      expect(profile?.department, 'Department of Computing Technologies');
      expect(site.requests.first.queryParameters['s'], 'Jane Doe');
    });

    test('falls back to guessed slugs when search finds nothing', () async {
      final site = _FakeSite({
        '?s=Jane Q': _fixture('search_empty.html'),
        '?s=Jane': _fixture('search_empty.html'),
        '/faculty/dr-jane-q/': _fixture('profile.html'),
      });
      final profile = await _client(site).lookup('Dr. Jane Q (100002)');
      expect(
          profile?.profileUrl, 'https://www.srmist.edu.in/faculty/dr-jane-q/');
    });

    test('returns null when nobody matches and caches the answer', () async {
      final site = _FakeSite({});
      final client = _client(site);
      expect(await client.lookup('Mr. Nobody Here (100003)'), isNull);
      final calls = site.requests.length;
      expect(await client.lookup('Mr. Nobody Here (100003)'), isNull);
      expect(site.requests.length, calls);
    });
  });
}
