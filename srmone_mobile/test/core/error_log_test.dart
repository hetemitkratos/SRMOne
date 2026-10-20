// test/core/error_log_test.dart
// The shareable error log must not carry the student's identity or session.

import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/diagnostics/error_log.dart';

void main() {
  test('redact masks emails, registration numbers and session values', () {
    final out = ErrorLog.redact(
        'GET https://academia.srmist.edu.in/lookup/ab1234@srmist.edu.in '
        'for RA2111003010001 with Cookie: JSESSIONID=abc123; '
        'iamcsrcoo=xyz token=t0k3n password: hunter2');

    expect(out, isNot(contains('ab1234')));
    expect(out, isNot(contains('RA2111003010001')));
    expect(out, isNot(contains('t0k3n')));
    expect(out, isNot(contains('hunter2')));
    expect(out, contains('<email>'));
    expect(out, contains('<reg-no>'));
  });

  test('record without init only prints and never throws', () async {
    await ErrorLog.record(StateError('boom'), StackTrace.current);
    expect(await ErrorLog.file(), isNull);
  });
}
