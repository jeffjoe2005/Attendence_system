import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthApiService {
  AuthApiService._();
  static final AuthApiService instance = AuthApiService._();

  static const String _webClientId =
      '592828977116-qnjuo9akgsg7lhb1jr5gf5msr49hmbo7.apps.googleusercontent.com';

  static const List<String> developerEmails = [
    'sparshraul2@gmail.com',
  ];

  static bool isAllowedEmail(String email) {
    final clean = email.trim().toLowerCase();
    if (developerEmails.contains(clean)) return true;
    return clean.endsWith('@nitgoa.ac.in');
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb ? _webClientId : null,
    serverClientId: kIsWeb ? null : _webClientId,
  );

  /// Authenticates using native Google Sign-In and verifies server-side with FastAPI
  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled by the user.');
      }

      final email = googleUser.email.trim().toLowerCase();
      if (!isAllowedEmail(email)) {
        await _googleSignIn.signOut();
        throw Exception(
          'Access restricted: Only @nitgoa.ac.in email accounts are permitted.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Failed to obtain Google ID Token.');
      }

      await ApiService.instance.checkConnection();
      final data = await ApiService.instance.post(
        '/api/auth/google',
        body: {'id_token': idToken},
      );

      final token = data['access_token'] as String?;
      await ApiService.setAuthToken(token);

      final userJson = data['user'] as Map<String, dynamic>;
      return _parseUserModel(userJson);
    } on TimeoutException {
      throw Exception('Server unreachable: Could not connect to backend on port 8001.');
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Dev login to test specific accounts without Google OAuth UI
  Future<UserModel> devLogin(String email, {String? role}) async {
    final data = await ApiService.instance.post(
      '/api/auth/dev-login',
      body: {'email': email.trim().toLowerCase(), if (role != null) 'role': role},
    );

    final token = data['access_token'] as String?;
    await ApiService.setAuthToken(token);

    final userJson = data['user'] as Map<String, dynamic>;
    return _parseUserModel(userJson);
  }

  /// Fetches current user profile from backend
  Future<UserModel?> getProfile() async {
    try {
      final data = await ApiService.instance.get('/api/auth/me');
      if (data is Map<String, dynamic>) {
        return _parseUserModel(data);
      }
    } catch (_) {}
    return null;
  }

  /// Updates user profile on backend
  Future<UserModel> updateProfile({
    required String name,
    required String rollNumber,
    required String branch,
    required int year,
    required int semester,
    String? section,
  }) async {
    final data = await ApiService.instance.put(
      '/api/auth/profile',
      body: {
        'name': name.trim(),
        'roll_number': rollNumber.trim().toUpperCase(),
        'branch': branch.trim().toUpperCase(),
        'year': year,
        'semester': semester,
        if (section != null) 'section': section,
      },
    );

    final userJson = data as Map<String, dynamic>;
    return _parseUserModel(userJson);
  }

  /// Signs out from Google and clears stored JWT token
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await ApiService.setAuthToken(null);
  }

  UserModel _parseUserModel(Map<String, dynamic> data) {
    return UserModel(
      uid: data['id'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      rollNumber: data['roll_number'] ?? '',
      branch: data['branch'] ?? 'ECE',
      year: data['year'] ?? 1,
      semester: data['semester'] ?? 1,
      section: data['section'],
      role: data['role'] ?? 'student',
      profileCompleted: data['profile_completed'] ?? false,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

