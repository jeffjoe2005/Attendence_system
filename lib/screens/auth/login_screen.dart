import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';
import '../../config/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _handleEmailLogin() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final modData = context.read<ModeratorDataProvider>();
    auth.signInWithEmail(email, modData: modData);
  }

  Future<void> _handleGoogleSignIn() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (!success && mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error!),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Header
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'NIT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'NIT Goa Attendance',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Connected to AWS RDS PostgreSQL',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),

                  // Error banner if any
                  if (auth.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.error!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.w500),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                            onPressed: () => auth.clearError(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        ],
                      ),
                    ),

                  // ─── 1. Google OAuth Sign-In Button ───
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: auth.isLoading ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google Logo representation
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Continue with Google Account',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR USE COLLEGE EMAIL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Email Input Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'College Email Direct Access',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter your @nitgoa.ac.in faculty, CR, or student email',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. trilochan.panigrahi@nitgoa.ac.in',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _handleEmailLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Login with Email',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR TEST BY ROLE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 1-Tap Quick Testing Buttons
                  _roleButton(context, auth, 'Moderator', AppConstants.roleModerator, const Color(0xFF7C3AED)),
                  const SizedBox(height: 10),
                  _roleButton(context, auth, 'Admin', AppConstants.roleAdmin, const Color(0xFF2563EB)),
                  const SizedBox(height: 10),
                  _roleButton(context, auth, 'Professor', AppConstants.roleProfessor, const Color(0xFF059669)),
                  const SizedBox(height: 10),
                  _roleButton(context, auth, 'CR', AppConstants.roleCR, const Color(0xFFD97706)),
                  const SizedBox(height: 10),
                  _roleButton(context, auth, 'Student', AppConstants.roleStudent, const Color(0xFF475569)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleButton(
    BuildContext context,
    AuthProvider auth,
    String label,
    String role,
    Color color,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: auth.isLoading ? null : () => auth.mockSignIn(role),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: color.withValues(alpha: 0.06),
        ),
        child: Text(
          '$label Portal',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
