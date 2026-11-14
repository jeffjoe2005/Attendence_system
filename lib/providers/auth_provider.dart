import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';
import '../services/auth_api_service.dart';
import '../services/api_service.dart';
import 'moderator_data_provider.dart';

/// Manages authentication state:
/// - Supports native Google OAuth 2.0 via GoogleSignIn and FastAPI verification
/// - Saves authenticated users directly to AWS RDS PostgreSQL
/// - Retains offline mock & dev sign-in support for seamless local testing
class AuthProvider extends ChangeNotifier {
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  bool _isBackendConnected = false;

  // ─── Getters ──────────────────────────────────────────────
  UserModel? get userModel => _userModel;
  UserModel? get currentUser => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _userModel != null;
  bool get isProfileCompleted => _userModel?.profileCompleted ?? false;
  bool get isBackendConnected => _isBackendConnected;
  String get userRole => _userModel?.role ?? 'student';
  String get userName => _userModel?.name ?? '';
  String get userEmail => _userModel?.email ?? '';

  // ─── Initialize ───────────────────────────────────────────
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isBackendConnected = await ApiService.instance.checkConnection();
      if (_isBackendConnected) {
        final profile = await AuthApiService.instance.getProfile();
        if (profile != null) {
          _userModel = profile;
        }
      }
    } catch (_) {}

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  // ─── Google OAuth Sign-In ─────────────────────────────────
  /// Prompts Google Sign-In, obtains ID token, verifies with backend,
  /// and saves or retrieves the user from PostgreSQL RDS.
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await AuthApiService.instance.signInWithGoogle();
      _userModel = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Direct Email Sign In ─────────────────────────────────
  /// Signs in by email. Tries FastAPI dev endpoint if backend is available,
  /// otherwise uses local roster lookup.
  Future<bool> signInWithEmail(String email, {ModeratorDataProvider? modData}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();

    // 1. Attempt API dev login if backend is online
    try {
      final isOnline = await ApiService.instance.checkConnection();
      if (isOnline) {
        final user = await AuthApiService.instance.devLogin(cleanEmail);
        _userModel = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Fallback to local logic below
    }

    await Future.delayed(const Duration(milliseconds: 300));

    // 2. Check if registered as Professor by Moderator
    if (modData != null && modData.isProfessorEmail(cleanEmail)) {
      final profName = modData.getProfessorNameByEmail(cleanEmail) ??
          ModeratorDataProvider.extractNameFromEmail(cleanEmail);
      _userModel = UserModel(
        uid: 'prof_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
        email: cleanEmail,
        name: profName,
        rollNumber: '',
        branch: 'ECE',
        year: 0,
        semester: 0,
        role: 'professor',
        profileCompleted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    }

    // 3. Check if registered as CR by Moderator
    if (modData != null && modData.crs.any((c) => c['email']?.toLowerCase() == cleanEmail)) {
      final crName = ModeratorDataProvider.extractNameFromEmail(cleanEmail);
      _userModel = UserModel(
        uid: 'cr_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
        email: cleanEmail,
        name: crName,
        rollNumber: '22ECE001',
        branch: 'ECE',
        year: 3,
        semester: 6,
        role: 'cr',
        profileCompleted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    }

    // 4. Fallback: check MockDataService
    final users = MockDataService.getUsers();
    try {
      _userModel = users.firstWhere(
        (u) => u.email.toLowerCase() == cleanEmail,
      );
    } catch (_) {
      // Default to student
      _userModel = UserModel(
        uid: 'user_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
        email: cleanEmail,
        name: ModeratorDataProvider.extractNameFromEmail(cleanEmail),
        rollNumber: '22ECE099',
        branch: 'ECE',
        year: 3,
        semester: 6,
        role: 'student',
        profileCompleted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  // ─── Mock Sign In by Role ─────────────────────────────────
  /// For quick testing: signs in as a specific role
  Future<bool> mockSignIn(String role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Try backend dev-login with default role emails
    final defaultEmails = {
      'moderator': 'moderator@nitgoa.ac.in',
      'admin': 'admin@nitgoa.ac.in',
      'professor': 'trilochan.panigrahi@nitgoa.ac.in',
      'cr': 'cr.ece3@nitgoa.ac.in',
      'student': 'student1@nitgoa.ac.in',
    };
    final email = defaultEmails[role.toLowerCase()] ?? '$role@nitgoa.ac.in';

    try {
      final isOnline = await ApiService.instance.checkConnection();
      if (isOnline) {
        final user = await AuthApiService.instance.devLogin(email, role: role.toLowerCase());
        _userModel = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 300));

    final users = MockDataService.getUsers();
    try {
      _userModel = users.firstWhere(
        (u) => u.role.toLowerCase() == role.toLowerCase() && u.profileCompleted,
      );
      _error = null;
    } catch (_) {
      _error = 'No mock user found for role: $role';
    }

    _isLoading = false;
    notifyListeners();
    return _userModel != null;
  }

  /// Sign in as a new student (profile not completed)
  Future<bool> mockSignInAsNewStudent() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));

    final users = MockDataService.getUsers();
    try {
      _userModel = users.firstWhere((u) => !u.profileCompleted);
    } catch (_) {
      _userModel = UserModel.empty('new_uid', 'newuser@nitgoa.ac.in');
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  // ─── Update Profile ───────────────────────────────────────
  Future<bool> updateProfile({
    required String name,
    required String rollNumber,
    required String branch,
    required int year,
    required int semester,
    String? section,
  }) async {
    if (_userModel == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final updatedUser = await AuthApiService.instance.updateProfile(
        name: name,
        rollNumber: rollNumber,
        branch: branch,
        year: year,
        semester: semester,
        section: section,
      );
      _userModel = updatedUser;
    } catch (_) {
      _userModel = _userModel!.copyWith(
        name: name,
        rollNumber: rollNumber,
        branch: branch,
        year: year,
        semester: semester,
        section: section,
        profileCompleted: true,
        updatedAt: DateTime.now(),
      );
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  // ─── Sign Out ─────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await AuthApiService.instance.signOut();
    } catch (_) {}
    _userModel = null;
    _error = null;
    notifyListeners();
  }

  // ─── Clear Error ──────────────────────────────────────────
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
