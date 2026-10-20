// lib/scrapers/faculty/faculty_parser.dart
// Port of Go faculty scraper parser from academia-backend/faculty-scraper/scraper/scraper.go

import 'package:html/parser.dart' as html_parser;

class FacultyParsedProfile {
  final String name;
  final String photoUrl;
  final String designation;
  final String department;
  final String email;
  final String campus;
  final String experience;
  final String researchInterest;
  final String courses;
  final String profileUrl;

  /// Research area shown under the designation (the "building" icon item).
  final String specialization;

  /// College, e.g. "Faculty of Engineering & Technology".
  final String college;

  const FacultyParsedProfile({
    required this.name,
    required this.photoUrl,
    required this.designation,
    required this.department,
    required this.email,
    required this.campus,
    required this.experience,
    required this.researchInterest,
    required this.courses,
    required this.profileUrl,
    this.specialization = '',
    this.college = '',
  });
}

class FacultyParser {
  FacultyParser._();

  static final _reFeaturedImage =
      RegExp(r'"featuredImage"\s*:\s*"(https:[^"]+\.(?:jpg|jpeg|png|webp))"');

  // "Dr. Jane Doe - SRMIST" / "Dr. Jane Doe | SRM Institute of ..."
  static final _reTitleSuffix =
      RegExp(r'\s*[-|\u2013\u2014]\s*SRM.*$', caseSensitive: false);

  static final _reSection = RegExp(
      r'^(EXPERIENCE|RESEARCH INTEREST|COURSES)\s*:?\s*(.*)$',
      caseSensitive: false);

  static FacultyParsedProfile parseProfile(String html, String profileUrl) {
    final doc = html_parser.parse(html);

    // Name (from og:title meta tag)
    String name = '';
    final ogTitle = doc.querySelector("meta[property='og:title']");
    if (ogTitle != null) {
      final content = ogTitle.attributes['content'] ?? '';
      name = content.replaceFirst(_reTitleSuffix, '').trim();
    }
    if (name.isEmpty) {
      name = doc.querySelector('h2.elementor-heading-title')?.text.trim() ?? '';
    }

    // Photo URL (from WordPress featuredImage JSON in script tag)
    String photoUrl = '';
    for (final script in doc.querySelectorAll('script')) {
      final text = script.text;
      final match = _reFeaturedImage.firstMatch(text);
      if (match != null) {
        photoUrl = match.group(1)!.replaceAll(r'\/', '/');
        break;
      }
    }

    // The icon-list widget holds designation, specialization, phone, email
    // and location, in that order, told apart only by unlabeled SVG icons.
    // Empty items are kept so positions still line up when one is blank.
    final info = <String, String>{};
    final listEls = doc.querySelectorAll(
        'div.hide_empty_list_item .elementor-icon-list-items .elementor-icon-list-item');
    const byPosition = [
      'designation',
      'specialization',
      'phone',
      'email',
      'location'
    ];
    for (var i = 0; i < listEls.length; i++) {
      final li = listEls[i];
      final text = (li.querySelector('.elementor-icon-list-text')?.text ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (text.isEmpty) continue;
      if (i < byPosition.length) info[byPosition[i]] = text;
    }
    var email = info['email'] ?? '';
    if (!email.contains('@')) {
      email = info.values.firstWhere((v) => v.contains('@'), orElse: () => '');
    }
    final designation = info['designation'] ?? '';
    final specialization = info['specialization'] ?? '';

    // "CAMPUS: <a>Department</a>, <a>College</a>, <a>Campus</a>"
    String department = '';
    String college = '';
    String campus = '';
    final cdc = doc.querySelector('.faculty-cdc');
    if (cdc != null) {
      final links = cdc
          .querySelectorAll('a')
          .map((a) => a.text.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (links.length >= 3) {
        department = links[0];
        college = links[1];
        campus = links.sublist(2).join(', ');
      } else if (links.isNotEmpty) {
        department = links[0];
        if (links.length == 2) campus = links[1];
      } else {
        campus = cdc.text
            .replaceAll('CAMPUS:', '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
    }

    // Experience, Research Interest, Courses: one text-editor widget each,
    // holding "<b>LABEL : </b>value".
    final sections = <String, String>{};
    for (final el in doc.querySelectorAll(
        "div[data-widget_type='text-editor.default'] .elementor-widget-container")) {
      final m =
          _reSection.firstMatch(el.text.replaceAll(RegExp(r'\s+'), ' ').trim());
      if (m == null) continue;
      sections.putIfAbsent(m.group(1)!.toUpperCase(), () => m.group(2)!.trim());
    }

    return FacultyParsedProfile(
      name: name,
      photoUrl: photoUrl,
      designation: designation,
      department: department,
      email: email,
      campus: campus,
      experience: sections['EXPERIENCE'] ?? '',
      researchInterest: sections['RESEARCH INTEREST'] ?? '',
      courses: sections['COURSES'] ?? '',
      specialization: specialization,
      college: college,
      profileUrl: profileUrl,
    );
  }
}
