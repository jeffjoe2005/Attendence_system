import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/moderator_data_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/teacher/teacher_dashboard.dart';
import 'screens/hod/hod_dashboard.dart';
import 'screens/moderator/moderator_dashboard.dart';
import 'screens/cr/cr_dashboard.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ModeratorDataProvider()),
      ],
      child: MaterialApp(
        title: 'Attendance System',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppRouter(),
      ),
    );
  }
}

/// Routes the user to the correct screen based on auth state and role
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Still initializing
    if (!auth.isInitialized || auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    // Not logged in
    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    // Route to correct dashboard
    switch (auth.userRole) {
      case AppConstants.roleModerator:
        return const ModeratorDashboard();
      case AppConstants.roleAdmin:
        return const AdminDashboard();
      case AppConstants.roleProfessor:
        return const ProfessorDashboard();
      case AppConstants.roleCR:
        return const CRDashboard();
      default:
        return const StudentDashboard();
    }
  }
}
