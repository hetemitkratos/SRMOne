// lib/core/network/manual_redirect_client.dart
// 10-hop manual redirect follower — exact port of Go client.go behavior.
// Configures Dio with followRedirects: false and wraps it to manually follow
// 301/302/303/307/308 responses, switching POST→GET for 301/302/303.

import 'package:dio/dio.dart';
import 'simple_cookie_jar.dart';

class ManualRedirectClient {
  static const int maxRedirects = 10;

  final Dio _dio;
  final SimpleCookieJar cookieJar;

  /// [dio] can be injected by tests (for example with a fake adapter).
  ManualRedirectClient({required this.cookieJar, Dio? dio})
      : _dio = dio ?? _shared;

  /// One Dio (and so one connection pool) for every client in this isolate,
  /// so later syncs reuse open TLS connections. Cookies never live in Dio:
  /// each request carries its own jar's Cookie header.
  static final Dio _shared = Dio(
    BaseOptions(
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
      receiveDataWhenStatusError: true,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// Execute a request with manual redirect following and automatic cookie management.
  ///
  /// [method]: 'GET' or 'POST'
  /// [url]: Initial request URL
  /// [headers]: Request headers (Cookie header will be injected automatically)
  /// [data]: Request body for POST (String or Map)
  /// [contentType]: Optional content-type override
  Future<Response<dynamic>> request(
    String method,
    String url, {
    Map<String, String>? headers,
    dynamic data,
    String? contentType,
    ResponseType? responseType,
    bool followRedirects = true,
  }) async {
    String currentMethod = method.toUpperCase();
    String currentUrl = url;
    dynamic currentData = data;
    String? currentContentType = contentType;
    int hops = 0;

    Response<dynamic>? response;

    while (hops <= maxRedirects) {
      final uri = Uri.parse(currentUrl);
      final host = uri.host;

      // Inject cookies from jar
      final cookieHeader = cookieJar.getCookieHeader(host);
      final mergedHeaders = <String, String>{
        if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
        ...?headers,
      };

      final options = Options(
        method: currentMethod,
        headers: mergedHeaders,
        contentType: currentContentType,
        responseType: responseType,
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
      );

      response = await _dio.request<dynamic>(
        currentUrl,
        data: currentData,
        options: options,
      );

      // Process Set-Cookie headers from response
      final setCookieList = response.headers.map['set-cookie'];
      if (setCookieList != null) {
        cookieJar.processSetCookieHeaders(host, setCookieList);
      }

      final statusCode = response.statusCode ?? 0;

      // Follow redirects
      if (followRedirects &&
          (statusCode == 301 ||
              statusCode == 302 ||
              statusCode == 303 ||
              statusCode == 307 ||
              statusCode == 308)) {
        final location = response.headers.value('location');
        if (location == null || location.isEmpty) break;

        // Resolve relative Location URLs against current URL
        final resolvedUri = uri.resolve(location);
        currentUrl = resolvedUri.toString();
        hops++;

        // 301/302/303: switch non-GET/HEAD methods to GET, clear body
        if (statusCode == 301 || statusCode == 302 || statusCode == 303) {
          if (currentMethod != 'GET' && currentMethod != 'HEAD') {
            currentMethod = 'GET';
            currentData = null;
            currentContentType = null;
          }
        }

        continue;
      }

      // Not a redirect — done
      break;
    }

    return response!;
  }

  /// Convenience GET
  Future<Response<dynamic>> get(
    String url, {
    Map<String, String>? headers,
    ResponseType? responseType,
    bool followRedirects = true,
  }) =>
      request('GET', url,
          headers: headers,
          responseType: responseType,
          followRedirects: followRedirects);

  /// Convenience POST with url-encoded body
  Future<Response<dynamic>> post(
    String url, {
    Map<String, String>? headers,
    String? body,
    String contentType = 'application/x-www-form-urlencoded;charset=UTF-8',
    ResponseType? responseType,
    bool followRedirects = true,
  }) =>
      request(
        'POST',
        url,
        headers: headers,
        data: body,
        contentType: contentType,
        responseType: responseType,
        followRedirects: followRedirects,
      );
}
