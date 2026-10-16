// lib/core/network/simple_cookie_jar.dart
// Exact Dart port of Go's custom SimpleCookieJar from
// academia-scraper/cmd/loginprobe/client.go
//
// IMPORTANT: Do NOT use a strict RFC-6265 cookie jar. Both Go scrapers use a
// simplified hostname-scoped key-value map with specific deletion semantics.

import 'dart:convert';

/// Simplified hostname-scoped cookie jar.
/// Stores cookies as Map<host, Map<cookieName, cookieValue>>.
/// Does NOT enforce RFC-6265 path/domain matching.
class SimpleCookieJar {
  /// Internal storage: [host][cookieName] = cookieValue
  final Map<String, Map<String, String>> _cookies = {};

  /// Process `Set-Cookie` header values from an HTTP response for the given [host].
  ///
  /// For each header value:
  /// - Takes only the first `name=value` pair (before the first `;`).
  /// - Trims whitespace from name and value.
  /// - If value is `""`, `"delete"` (case-insensitive), or `"null"` (case-insensitive),
  ///   removes the cookie. Otherwise sets it.
  void processSetCookieHeaders(String host, List<String> setCookieHeaders) {
    for (final header in setCookieHeaders) {
      final firstPart = header.split(';').first.trim();
      final eqIdx = firstPart.indexOf('=');
      if (eqIdx < 0) continue;

      final name = firstPart.substring(0, eqIdx).trim();
      final value = firstPart.substring(eqIdx + 1).trim();

      if (name.isEmpty) continue;

      final normalized = value.toLowerCase();
      if (value.isEmpty || normalized == 'delete' || normalized == 'null') {
        _cookies[host]?.remove(name);
      } else {
        _cookies.putIfAbsent(host, () => {})[name] = value;
      }
    }
  }

  /// Returns the `Cookie` request header string for the given [host].
  /// Format: `name1=val1; name2=val2`
  String getCookieHeader(String host) {
    final map = _cookies[host];
    if (map == null || map.isEmpty) return '';
    return map.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// Returns the value of a single named cookie for [host], or null if absent.
  String? get(String host, String name) => _cookies[host]?[name];

  /// Sets a cookie directly (used for programmatic injection).
  void set(String host, String name, String value) {
    _cookies.putIfAbsent(host, () => {})[name] = value;
  }

  /// Removes all cookies for the given [host].
  void clearHost(String host) => _cookies.remove(host);

  /// Clears the entire cookie jar.
  void clearAll() => _cookies.clear();

  /// Returns true if the jar contains at least one cookie for [host].
  bool hasAny(String host) =>
      _cookies[host] != null && _cookies[host]!.isNotEmpty;

  /// Serializes to JSON string for persisting in flutter_secure_storage.
  String toJson() => jsonEncode(_cookies);

  /// Restores from a JSON string previously produced by [toJson].
  static SimpleCookieJar fromJson(String json) {
    final jar = SimpleCookieJar();
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      for (final host in decoded.keys) {
        final cookies = decoded[host] as Map<String, dynamic>;
        jar._cookies[host] = cookies.map((k, v) => MapEntry(k, v as String));
      }
    } catch (_) {
      // Corrupt JSON → start fresh
    }
    return jar;
  }

  @override
  String toString() => 'SimpleCookieJar($_cookies)';
}
