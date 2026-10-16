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
  });
}

class FacultyParser {
  FacultyParser._();

  static final _reFeaturedImage =
      RegExp(r'"featuredImage"\s*:\s*"(https:[^"]+\.(?:jpg|jpeg|png|webp))"');

  static FacultyParsedProfile parseProfile(String html, String profileUrl) {
    final doc = html_parser.parse(html);

    // Name (from og:title meta tag)
    String name = '';
    final ogTitle = doc.querySelector("meta[property='og:title']");
    if (ogTitle != null) {
      final content = ogTitle.attributes['content'] ?? '';
      name = content.replaceAll(' - SRMIST', '').trim();
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

    // List items (designation, department, email)
    final listItems = <String>[];
    for (final el in doc.querySelectorAll(
        'div.hide_empty_list_item .elementor-icon-list-items .elementor-icon-list-item .elementor-icon-list-text')) {
      final t = el.text.trim();
      if (t.isNotEmpty) listItems.add(t);
    }

    String designation = listItems.isNotEmpty ? listItems[0] : '';
    String email = '';
    String department = '';

    for (final item in listItems) {
      if (item.contains('@')) {
        email = item;
        break;
      }
    }

    if (listItems.length >= 2 && !listItems[1].contains('@')) {
      department = listItems[1];
    }

    // Campus
    String campus = '';
    final cdc = doc.querySelector('.faculty-cdc');
    if (cdc != null) {
      campus = cdc.text.replaceAll('CAMPUS:', '').trim();
    }

    // Experience, Research Interest, Courses
    String experience = '';
    String researchInterest = '';
    String courses = '';

    for (final el in doc.querySelectorAll(
        "div[data-widget_type='text-editor.default'] .elementor-widget-container")) {
      final text = el.text.trim();
      if (text.startsWith('EXPERIENCE')) {
        experience = text.replaceAll(RegExp(r'^EXPERIENCE\s*:?'), '').trim();
      } else if (text.startsWith('RESEARCH INTEREST')) {
        researchInterest =
            text.replaceAll(RegExp(r'^RESEARCH INTEREST\s*:?'), '').trim();
      } else if (text.startsWith('COURSES')) {
        courses = text.replaceAll(RegExp(r'^COURSES\s*:?'), '').trim();
      }
    }

    return FacultyParsedProfile(
      name: name,
      photoUrl: photoUrl,
      designation: designation,
      department: department,
      email: email,
      campus: campus,
      experience: experience,
      researchInterest: researchInterest,
      courses: courses,
      profileUrl: profileUrl,
    );
  }
}
