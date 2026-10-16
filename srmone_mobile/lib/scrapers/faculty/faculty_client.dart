// lib/scrapers/faculty/faculty_client.dart
// Client for searching and fetching faculty profiles from www.srmist.edu.in.

import 'package:dio/dio.dart';
import '../../core/constants/portal_endpoints.dart';
import 'faculty_parser.dart';

class FacultyClient {
  final Dio _dio;

  FacultyClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'User-Agent': PortalEndpoints.defaultUserAgent,
                  'Accept':
                      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                },
              ),
            );

  /// Fetches and parses a faculty profile given their URL slug (e.g. 'dr-dhanalakshmi-j').
  Future<FacultyParsedProfile?> fetchProfileBySlug(String slug) async {
    final cleanSlug = slug.trim().replaceAll('/', '');
    final url = '${PortalEndpoints.facultyProfileBaseUrl}$cleanSlug/';

    try {
      final resp = await _dio.get<String>(url);
      if (resp.statusCode != 200 || resp.data == null) return null;
      return FacultyParser.parseProfile(resp.data!, url);
    } catch (_) {
      return null;
    }
  }

  /// Searches for faculty by query name and returns profile of first match if found.
  Future<FacultyParsedProfile?> searchFaculty(String query) async {
    final encoded = Uri.encodeComponent(query.trim());
    final searchUrl = 'https://www.srmist.edu.in/?s=$encoded&post_type=faculty';

    try {
      final resp = await _dio.get<String>(searchUrl);
      if (resp.statusCode != 200 || resp.data == null) return null;

      final html = resp.data!;
      // Find first faculty profile link matching /faculty/{slug}/
      final match = RegExp(r'https?://www\.srmist\.edu\.in/faculty/([^/"]+)/')
          .firstMatch(html);
      if (match != null) {
        final slug = match.group(1);
        if (slug != null) {
          return fetchProfileBySlug(slug);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
