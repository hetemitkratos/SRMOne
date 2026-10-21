// test/scrapers/sp_mark_components_test.dart
// The Student Portal's marks page links each course to its components, and
// the "View Details" page lists them.

import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/scrapers/student_portal/sp_parsers.dart';

const _marksPage = '''
<table><thead><tr><th>Code</th><th>Description</th><th>Mark / Max. Mark</th><th></th></tr></thead>
<tbody>
<tr><td>21AAA101T</td><td>SAMPLE COURSE</td><td>18.70 / 20.00</td>
<td><button onclick="funViewComponentWiseMarks('12345', '21AAA101T', 'SAMPLE COURSE',2)">View Details</button></td></tr>
<tr><td>21BBB202T</td><td>OTHER COURSE</td><td>15.00 / 20.00</td><td></td></tr>
</tbody></table>
''';

const _componentsPage = '''
<table><thead><tr><th>Entered on</th><th>Component</th><th>Mark / Max. Mark</th></tr></thead>
<tbody>
<tr><td>01/Sep/2026</td><td>FT-I</td><td>4.60 / 5.00</td></tr>
<tr><td>30/Sep/2026</td><td>FT-II</td><td>14.10 / 15.00</td></tr>
</tbody></table>
''';

void main() {
  test('reads each course\'s View Details id and status', () {
    final rows = SPParsers.parseInternalMarks(_marksPage);
    expect(rows, hasLength(2));
    expect(rows[0].subjectId, '12345');
    expect(rows[0].status, '2');
    expect(rows[0].obtained, '18.70');
    expect(rows[1].subjectId, isNull);
  });

  test('parses component marks', () {
    final parts = SPParsers.parseMarkComponents(_componentsPage);
    expect(parts.map((p) => p.component), ['FT-I', 'FT-II']);
    expect(parts[0].obtained, '4.60');
    expect(parts[0].maxMark, '5.00');
    expect(parts[1].enteredOn, '30/Sep/2026');
  });

  test('no components table gives an empty list', () {
    expect(SPParsers.parseMarkComponents('<p>No data</p>'), isEmpty);
  });
}
