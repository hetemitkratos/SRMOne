// lib/core/network/cache_buster_interceptor.dart
// Dio interceptor that appends ?_t=<epoch_ms> and sets no-cache headers on
// every GET request to SRM Academia endpoints, implementing Layer 2 of the
// 4-Layer Zero-Logout Attendance Auto-Refresh architecture.

import 'package:dio/dio.dart';
import '../constants/portal_endpoints.dart';

class CacheBusterInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final url = options.uri.toString();

    // Apply cache-busting only to Academia portal GET requests
    if (options.method == 'GET' &&
        url.contains(PortalEndpoints.academiaBaseUrl)) {
      // Append epoch timestamp query parameter
      final uri = options.uri;
      final newUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        '_t': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      options.path = newUri.toString();

      // Set no-cache headers (Layer 2 — Zoho & OS Cache Busting)
      options.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
      options.headers['Pragma'] = 'no-cache';
      options.headers['Expires'] = '0';
      options.headers['X-Requested-With'] = 'XMLHttpRequest';
      options.headers['Referer'] = '${PortalEndpoints.academiaBaseUrl}/';
    }

    handler.next(options);
  }
}
