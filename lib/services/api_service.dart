import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  ApiService._();
  @visibleForTesting
  static http.Client client = http.Client();
  static final ApiService instance = ApiService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static String? _cachedToken;

  /// Default API URL:
  /// - Override at build time via `--dart-define=API_BASE_URL=...`
  /// - Android Emulator: 10.0.2.2:8000 (auto-detects adb-reversed localhost:8000 on physical devices)
  /// - Windows / Web / iOS Simulator: localhost:8000
  /// - EC2 / Production: Set via setBaseUrl("https://your-ec2-domain.com") or API_BASE_URL
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static bool _hasCustomBaseUrl = _envBaseUrl.isNotEmpty;
  static String _baseUrl = _defaultBaseUrl();

  static String _defaultBaseUrl() {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl.endsWith('/')
          ? _envBaseUrl.substring(0, _envBaseUrl.length - 1)
          : _envBaseUrl;
    }
    if (kIsWeb) return Uri.base.origin;
    try {
      if (Platform.isAndroid) return 'http://localhost:8001';
    } catch (_) {}
    return 'http://localhost:8001';
  }

  static String get baseUrl => _baseUrl;
  static void setBaseUrl(String url) {
    _hasCustomBaseUrl = true;
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Sets or clears the JWT authentication token
  static Future<void> setAuthToken(String? token) async {
    _cachedToken = token;
    try {
      if (token != null) {
        await _storage.write(key: 'jwt_token', value: token);
      } else {
        await _storage.delete(key: 'jwt_token');
      }
    } catch (_) {}
  }

  /// Loads the stored JWT authentication token
  static Future<String?> getAuthToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      _cachedToken = await _storage.read(key: 'jwt_token');
    } catch (_) {}
    return _cachedToken;
  }

  /// Headers with Bearer token injection
  static Future<Map<String, String>> _headers(
      {Map<String, String>? extra}) async {
    final token = await getAuthToken();
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    if (extra != null) {
      h.addAll(extra);
    }
    return h;
  }

  /// Set to true in tests to skip real HTTP calls in checkConnection().
  static bool testMode = false;

  /// Health check to detect if the backend server is reachable
  Future<bool> checkConnection() async {
    if (testMode) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    } catch (_) {}

    if (_hasCustomBaseUrl || kIsWeb) {
      try {
        final res = await client
            .get(
              Uri.parse('$_baseUrl/api/health'),
            )
            .timeout(const Duration(seconds: 3));
        return res.statusCode == 200;
      } catch (_) {
        return false;
      }
    }

    final candidates = [
      'http://localhost:8001',
      'http://localhost:8000',
      'http://10.0.2.2:8001',
      'http://10.0.2.2:8000',
    ];

    for (final candidate in candidates) {
      try {
        final res = await client
            .get(Uri.parse('$candidate/api/health'))
            .timeout(const Duration(milliseconds: 1500));
        if (res.statusCode == 200) {
          _baseUrl = candidate;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// HTTP GET
  Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('$_baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  /// HTTP POST
  Future<dynamic> post(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final response = await client
        .post(
          uri,
          headers: await _headers(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 12));
    return _handleResponse(response);
  }

  /// HTTP PUT
  Future<dynamic> put(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final response = await client
        .put(
          uri,
          headers: await _headers(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  /// HTTP DELETE
  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final response = await client
        .delete(uri, headers: await _headers())
        .timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    } else {
      String message = 'HTTP ${response.statusCode}';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err.containsKey('detail')) {
          message = err['detail'].toString();
        }
      } catch (_) {}
      throw ApiException(statusCode: response.statusCode, message: message);
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
