// lib/scrapers/faculty/faculty_client.dart
// Client for searching and fetching faculty profiles from www.srmist.edu.in.
// Port of academia-backend/faculty-scraper plus the name cleanup, search
// fallbacks and slug guessing the legacy `/faculty` route layered on top.

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/constants/portal_endpoints.dart';
import 'faculty_name.dart';
import 'faculty_parser.dart';

class FacultyClient {
  final Dio _dio;

  FacultyClient({Dio? dio}) : _dio = dio ?? _defaultDio();

  static Dio _defaultDio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          // A missing slug is a 404, which is an answer, not an error.
          validateStatus: (s) => s != null && s < 500,
          headers: {
            'User-Agent': PortalEndpoints.defaultUserAgent,
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );

  /// Headers the SRM site wants on faculty photo requests (hotlink protection).
  static const Map<String, String> photoHeaders = {
    'Referer': 'https://www.srmist.edu.in/',
    'User-Agent': PortalEndpoints.defaultUserAgent,
  };

  /// Profiles already looked up this run, keyed by cleaned name. Holding the
  /// future also merges concurrent lookups of the same person.
  static final Map<String, Future<FacultyParsedProfile?>> _cache = {};

  static const _maxSearchProfiles = 6;
  static const _slugBatch = 4;

  /// Finds the profile for an Academia faculty name such as
  /// "Dr.J.Shobana (102927)". Returns null when SRM has no matching profile.
  Future<FacultyParsedProfile?> lookup(String rawName) {
    final query = FacultyNameQuery.parse(rawName);
    if (query.cacheKey.isEmpty) return Future.value(null);
    return _cache.putIfAbsent(query.cacheKey, () async {
      try {
        return await _lookup(query);
      } catch (_) {
        // Network trouble: don't remember the miss, so a retry can succeed.
        _cache.remove(query.cacheKey);
        return null;
      }
    });
  }

  /// Kept for existing callers.
  Future<FacultyParsedProfile?> searchFaculty(String query) => lookup(query);

  Future<FacultyParsedProfile?> _lookup(FacultyNameQuery q) async {
    for (final term in q.searchTerms) {
      final slugs = await searchSlugs(term);
      if (slugs.isEmpty) continue;
      final profiles = (await Future.wait(
              slugs.take(_maxSearchProfiles).map(_fetchProfileOrNull)))
          .whereType<FacultyParsedProfile>()
          .toList();
      final best = pickBestMatch(q.cleanName, profiles);
      if (best != null) return best;
    }

    for (var i = 0; i < q.slugCandidates.length; i += _slugBatch) {
      final batch = q.slugCandidates.skip(i).take(_slugBatch);
      final found = await Future.wait(batch.map(_fetchProfileOrNull));
      for (final p in found) {
        if (p != null) return p;
      }
    }
    return null;
  }

  /// Runs SRM's WordPress faculty search and returns profile slugs in order.
  Future<List<String>> searchSlugs(String term) async {
    final url = PortalEndpoints.facultySearchUrl
        .replaceFirst('{query}', Uri.encodeQueryComponent(term.trim()));
    final resp = await _dio.get<String>(url);
    if (resp.statusCode != 200 || resp.data == null) return const [];
    return parseSearchSlugs(resp.data!);
  }

  /// Fetches and parses a faculty profile given its URL slug
  /// (e.g. 'dr-dhanalakshmi-j'). Returns null for a missing or empty page.
  Future<FacultyParsedProfile?> fetchProfileBySlug(String slug) async {
    final cleanSlug = slug.trim().replaceAll('/', '');
    if (cleanSlug.isEmpty) return null;
    final url = '${PortalEndpoints.facultyProfileBaseUrl}$cleanSlug/';
    final resp = await _dio.get<String>(url);
    if (resp.statusCode != 200 || resp.data == null) return null;
    final profile = FacultyParser.parseProfile(resp.data!, url);
    return profile.name.isEmpty ? null : profile;
  }

  Future<FacultyParsedProfile?> _fetchProfileOrNull(String slug) async {
    try {
      return await fetchProfileBySlug(slug);
    } on DioException catch (e) {
      // A dead slug is fine; a dead connection should surface to [lookup].
      if (e.type == DioExceptionType.badResponse) return null;
      rethrow;
    }
  }

  static final _profileHref =
      RegExp(r'^(?:https?://www\.srmist\.edu\.in)?/faculty/([^/?#]+)/?$');

  /// Extracts faculty profile slugs from a search results page.
  ///
  /// SRM's theme lists results as `section.search-result-container >
  /// div.article-wrapper`, each with a `p.post-type` ("Staff", "department",
  /// ...) and an `a.read-more` link. The page's `<article>`s are unrelated
  /// news posts, and `post_type=faculty` is ignored, so filter on the link.
  static List<String> parseSearchSlugs(String html) {
    final doc = html_parser.parse(html);
    final scope = doc.querySelector('section.search-result-container') ??
        doc.querySelector('#content') ??
        doc.body;
    if (scope == null) return const [];
    final seen = <String>{};
    for (final a in scope.querySelectorAll('a[href]')) {
      final m = _profileHref.firstMatch((a.attributes['href'] ?? '').trim());
      final slug = m?.group(1);
      if (slug != null && slug.isNotEmpty && slug != 'page') seen.add(slug);
    }
    return seen.toList();
  }

  /// Picks the profile whose name matches [cleanName] best: an exact match
  /// first, then the most shared name words. Null when nothing overlaps.
  static FacultyParsedProfile? pickBestMatch(
      String cleanName, List<FacultyParsedProfile> profiles) {
    if (profiles.isEmpty) return null;
    final target = FacultyNameQuery.normalizeForMatch(cleanName);
    for (final p in profiles) {
      if (FacultyNameQuery.normalizeForMatch(p.name) == target) return p;
    }
    final targetWords = target.split(' ').where((w) => w.isNotEmpty).toSet();
    FacultyParsedProfile? best;
    var bestScore = 0;
    for (final p in profiles) {
      final words = FacultyNameQuery.normalizeForMatch(p.name).split(' ');
      // Full words count double so "Shobana" beats a shared initial "J".
      final score = words
          .where(targetWords.contains)
          .fold<int>(0, (s, w) => s + (w.length > 1 ? 2 : 1));
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    return bestScore >= 2 ? best : null;
  }
}
