// test/scrapers/scrapers_test.dart
// Unit tests for pure Dart scrapers, decoders, and cookie jar against sanitized fixtures.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/network/simple_cookie_jar.dart';
import 'package:srmone_mobile/scrapers/academia/academia_decoder.dart';
import 'package:srmone_mobile/scrapers/student_portal/sp_parsers.dart';

void main() {
  group('SimpleCookieJar', () {
    test('hostname isolation: cookies for host A do not leak to host B', () {
      final jar = SimpleCookieJar();
      jar.processSetCookieHeaders(
          'academia.srmist.edu.in', ['JSESSIONID=12345; Path=/']);
      jar.processSetCookieHeaders(
          'sp.srmist.edu.in', ['JSESSIONID=67890; Path=/']);

      expect(jar.get('academia.srmist.edu.in', 'JSESSIONID'), '12345');
      expect(jar.get('sp.srmist.edu.in', 'JSESSIONID'), '67890');
      expect(jar.getCookieHeader('academia.srmist.edu.in'), 'JSESSIONID=12345');
      expect(jar.getCookieHeader('sp.srmist.edu.in'), 'JSESSIONID=67890');
    });

    test('deletion semantics: empty, "delete", and "null" remove cookie', () {
      final jar = SimpleCookieJar();
      jar.set('example.com', 'c1', 'v1');
      jar.set('example.com', 'c2', 'v2');
      jar.set('example.com', 'c3', 'v3');

      jar.processSetCookieHeaders('example.com', [
        'c1=; Path=/',
        'c2=delete; Path=/',
        'c3=null; Path=/',
      ]);

      expect(jar.get('example.com', 'c1'), isNull);
      expect(jar.get('example.com', 'c2'), isNull);
      expect(jar.get('example.com', 'c3'), isNull);
      expect(jar.hasAny('example.com'), false);
    });

    test('JSON serialization round-trip for secure storage', () {
      final jar = SimpleCookieJar();
      jar.set('example.com', 'token', 'abc-123');
      final json = jar.toJson();

      final restored = SimpleCookieJar.fromJson(json);
      expect(restored.get('example.com', 'token'), 'abc-123');
    });
  });

  group('AcademiaDecoder', () {
    test('decodeJSString handles hex, unicode, and common escapes', () {
      const input = r"Hello\x20World\u0021\nTab:\tQuote:\'Slash:\\";
      final output = AcademiaDecoder.decodeJSString(input);
      expect(output, "Hello World!\nTab:\tQuote:'Slash:\\");
    });

    test(
        'extractSanitizePayload extracts content between pageSanitizer.sanitize(\' and \')',
        () {
      const raw =
          'var x = pageSanitizer.sanitize(\'<table><tr><td>21CSC402P</td></tr></table>\');';
      final payload = AcademiaDecoder.extractSanitizePayload(raw);
      expect(payload, '<table><tr><td>21CSC402P</td></tr></table>');
    });

    test('decodeSanitizedHTML unescapes table fragment correctly', () {
      const raw =
          r"pageSanitizer.sanitize('<table\x3e<tr\x3e<td\x3e21CSC402P<\/td\x3e<\/tr\x3e<\/table\x3e')";
      final decoded = AcademiaDecoder.decodeSanitizedHTML(raw);
      expect(decoded, '<table><tr><td>21CSC402P</td></tr></table>');
    });
  });

  group('SPParsers against sanitized fixtures', () {
    late String spAttendanceHtml;

    setUpAll(() {
      final attendanceFile = File('test/fixtures/sp_attendance_response.html');
      spAttendanceHtml =
          attendanceFile.existsSync() ? attendanceFile.readAsStringSync() : '';
    });

    test('parseAttendance extracts subjects from sp_attendance_response.html',
        () {
      if (spAttendanceHtml.isEmpty) return;

      final records = SPParsers.parseAttendance(spAttendanceHtml);
      expect(records, isNotEmpty);
      expect(records.length, greaterThanOrEqualTo(3));

      final first = records.first;
      expect(first.courseCode, '21CSC402P');
      expect(first.courseTitle, 'REPORT WRITING');
      expect(first.hoursConducted, 8);
      expect(first.hoursAbsent, 6);
      expect(first.attendancePct, closeTo(25.0, 0.01));
    });

    test('parseSecureConfig extracts config tokens from login page HTML', () {
      const sampleLoginHtml = '''
        <script>
          window.SECURE_CONFIG = {};
          SECURE_CONFIG.captchaText = 'DECOY789';
          SECURE_CONFIG.captchaFieldName = 'cptoken_abc123';
          SECURE_CONFIG.domainFieldName = 'dtoken_xyz789';
          SECURE_CONFIG.randomDelimiter = ':::';
          var obj = { nonce: 'test_nonce_val' };
        </script>
      ''';
      final config = SPParsers.parseSecureConfig(sampleLoginHtml);
      expect(config.captchaText, 'DECOY789');
      expect(config.captchaFieldName, 'cptoken_abc123');
      expect(config.domainFieldName, 'dtoken_xyz789');
      expect(config.randomDelimiter, ':::');
      expect(config.nonce, 'test_nonce_val');
    });

    test('extractHoneypotNames finds ph_ inputs in login form', () {
      const sampleFormHtml = '''
        <form>
          <input type="text" name="username" />
          <input type="password" name="password" />
          <input type="text" name="ph_email_trap" value="" />
          <input type="hidden" name="ph_hidden_trap" value="" />
        </form>
      ''';
      final honeypots = SPParsers.extractHoneypotNames(sampleFormHtml);
      expect(honeypots, ['ph_email_trap', 'ph_hidden_trap']);
    });

    test('parseInternalMarks handles slash format (obtained/maxMark)', () {
      const sampleHtml = '''
        <table>
          <tr><th>Code</th><th>Description</th><th>Mark / Max. Mark</th></tr>
          <tr><td>21CSC402P</td><td>Report Writing</td><td>42.50 / 50.00</td></tr>
        </table>
      ''';
      final marks = SPParsers.parseInternalMarks(sampleHtml);
      expect(marks.length, 1);
      expect(marks[0].courseCode, '21CSC402P');
      expect(marks[0].obtained, '42.50');
      expect(marks[0].maxMark, '50.00');
    });
  });
}
