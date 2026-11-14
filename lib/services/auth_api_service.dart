import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
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

  /// Windows uses the system browser and a loopback OAuth callback. The other
  /// supported platforms use the google_sign_in platform implementation.
  static bool get supportsGoogleSignIn =>
      kIsWeb ||
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

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
    if (!supportsGoogleSignIn) {
      throw UnsupportedError(
        'Google sign-in is not supported in the Windows desktop app. '
        'Open the web app or use Android, iOS, or macOS.',
      );
    }

    try {
      if (isWindows) {
        final firebaseIdToken = await _signInInSystemBrowser();
        return await _authenticateFirebaseToken(firebaseIdToken);
      }

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

      return await _authenticateIdToken(idToken);
    } on TimeoutException {
      throw Exception(
          'Server unreachable: Could not connect to backend on port 8001.');
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<String> _signInInSystemBrowser() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final state = _randomUrlSafe(32);
    final options = Firebase.app().options;
    final authDomain = options.authDomain?.trim();
    final config = jsonEncode({
      'apiKey': options.apiKey,
      'authDomain': authDomain == null || authDomain.isEmpty
          ? 'attendence-system-79bda.firebaseapp.com'
          : authDomain,
      'projectId': options.projectId,
      'appId': options.appId,
      'messagingSenderId': options.messagingSenderId,
      'storageBucket': options.storageBucket,
    });
    final completed = Completer<String>();

    try {
      server.listen((request) async {
        if (request.uri.path == '/') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..headers.set('Cache-Control', 'no-store')
            ..write(_browserSignInPage(config, state));
          await request.response.close();
          return;
        }
        if (request.uri.path == '/complete' && request.method == 'POST') {
          try {
            final body = jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
            if (body['state'] != state) {
              throw Exception('Sign-in state validation failed. Please retry.');
            }
            final idToken = body['idToken'] as String?;
            if (idToken == null || idToken.isEmpty) {
              throw Exception('Firebase did not return an ID token.');
            }
            if (!completed.isCompleted) completed.complete(idToken);
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.html
              ..write(
                  '<!doctype html><title>Done</title><p>Sign-in complete. Return to NIT Goa Attendance.</p>');
          } catch (error) {
            request.response
              ..statusCode = HttpStatus.badRequest
              ..write(
                  'Sign-in could not be completed. Return to the app and retry.');
            if (!completed.isCompleted) completed.completeError(error);
          }
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      final browserUri = Uri.parse(
        'http://localhost:${server.port}/?state=$state',
      );
      final opened = await launchUrl(
        browserUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('Could not open your default web browser.');
      }
      return await completed.future.timeout(const Duration(minutes: 5));
    } on TimeoutException {
      throw Exception('Google sign-in timed out. Please try again.');
    } finally {
      await server.close(force: true);
    }
  }

  String _browserSignInPage(String config, String state) => '''
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>NIT Goa Attendance sign-in</title><style>body{font:16px Arial,sans-serif;max-width:440px;margin:15vh auto;padding:24px;color:#0f172a;text-align:center}button{padding:14px 24px;border:1px solid #cbd5e1;border-radius:10px;background:white;font-size:16px;font-weight:bold;cursor:pointer}#message{color:#b91c1c;margin-top:18px}</style></head>
<body><h2>NIT Goa Attendance</h2><p>Continue with your Google account</p><button id="signin">Sign in with Google</button><p id="message"></p>
<script type="module">
import {initializeApp} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import {getAuth,GoogleAuthProvider,signInWithPopup} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';
const app=initializeApp($config), auth=getAuth(app), state=${jsonEncode(state)};
const provider=new GoogleAuthProvider();
provider.setCustomParameters({prompt:'select_account'});
document.getElementById('signin').addEventListener('click',async()=>{
 const button=document.getElementById('signin'), message=document.getElementById('message'); button.disabled=true; message.textContent='';
 try { const result=await signInWithPopup(auth,provider); const idToken=await result.user.getIdToken();
  const response=await fetch('/complete',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({state,idToken})});
  if(!response.ok) throw new Error('Could not return sign-in to the app.'); document.body.innerHTML='<h2>Sign-in complete</h2><p>You can close this tab and return to the app.</p>';
 } catch(error) { message.textContent=error.message||'Sign-in failed. Please try again.'; button.disabled=false; }
});
</script></body></html>''';

  Future<UserModel> _authenticateFirebaseToken(String idToken) async {
    await ApiService.instance.checkConnection();
    final data = await ApiService.instance.post(
      '/api/auth/firebase',
      body: {'id_token': idToken},
    );
    await ApiService.setAuthToken(data['access_token'] as String?);
    return _parseUserModel(data['user'] as Map<String, dynamic>);
  }

  String _randomUrlSafe(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<UserModel> _authenticateIdToken(String idToken) async {
    await ApiService.instance.checkConnection();
    final data = await ApiService.instance.post(
      '/api/auth/google',
      body: {'id_token': idToken},
    );
    await ApiService.setAuthToken(data['access_token'] as String?);
    return _parseUserModel(data['user'] as Map<String, dynamic>);
  }

  /// Dev login to test specific accounts without Google OAuth UI
  Future<UserModel> devLogin(String email, {String? role}) async {
    final data = await ApiService.instance.post(
      '/api/auth/dev-login',
      body: {
        'email': email.trim().toLowerCase(),
        if (role != null) 'role': role
      },
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
