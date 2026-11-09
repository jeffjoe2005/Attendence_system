import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static String? _cachedToken;

  /// Default API URL:
  /// - Android Emulator: 10.0.2.2:8000
  /// - Windows / Web / iOS Simulator: localhost:8000
  /// - EC2 / Production: Set via setBaseUrl("https://your-ec2-domain.com")
  static String _baseUrl = _defaultBaseUrl();

  static String _defaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {}
    return 'http://localhost:8000';
  }

  static String get baseUrl => _baseUrl;
  static void setBaseUrl(String url) {
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
  static Future<Map<String, String>> _headers({Map<String, String>? extra}) async {
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

  /// Health check to detect if the backend server is reachable
  Future<bool> checkConnection() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/health'),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// HTTP GET
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('$_baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  /// HTTP POST
  Future<dynamic> post(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final response = await http.post(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 12));
    return _handleResponse(response);
  }

  /// HTTP PUT
  Future<dynamic> put(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final response = await http.put(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  /// HTTP DELETE
  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final response = await http.delete(uri, headers: await _headers()).timeout(const Duration(seconds: 10));
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

