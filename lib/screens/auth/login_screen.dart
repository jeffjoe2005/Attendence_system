import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/constants.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Attendance System',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your role to continue',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 48),
              _roleButton(context, auth, 'Student', AppConstants.roleStudent),
              const SizedBox(height: 12),
              _roleButton(context, auth, 'CR', AppConstants.roleCR),
              const SizedBox(height: 12),
              _roleButton(context, auth, 'Professor', AppConstants.roleProfessor),
              const SizedBox(height: 12),
              _roleButton(context, auth, 'Admin', AppConstants.roleAdmin),
              const SizedBox(height: 12),
              _roleButton(context, auth, 'Moderator', AppConstants.roleModerator),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleButton(
      BuildContext context, AuthProvider auth, String label, String role) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: () => auth.mockSignIn(role),
        child: Text(label),
      ),
    );
  }
}
