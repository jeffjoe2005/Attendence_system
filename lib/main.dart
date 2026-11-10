import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/constants.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/moderator_data_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/teacher/teacher_dashboard.dart';
// import 'screens/hod/hod_dashboard.dart'; // Kept intact: Admin portal backend & dashboard logic preserved
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
        ChangeNotifierProvider(create: (_) => ModeratorDataProvider(enableBackendSync: true)..syncWithBackend()),
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

/// Routes the user to LoginScreen or the role-matched dashboard based on auth state.
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    switch (auth.userRole.toLowerCase()) {
      case AppConstants.roleModerator:
        return const ModeratorDashboard();
      // case AppConstants.roleAdmin:
      //   return const AdminDashboard();
      case AppConstants.roleProfessor:
        return const ProfessorDashboard();
      case AppConstants.roleCR:
        return const CRDashboard();
      default:
        return const StudentDashboard();
    }
  }
}

/// Direct Portal Switcher — allows switching between portals directly
/// without needing the login screen during development.
class PortalShell extends StatefulWidget {
  const PortalShell({super.key});

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  int _currentIndex = 0; // 0: Moderator, 1: Professor, 2: CR, 3: Student

  final List<Widget> _portals = const [
    ModeratorDashboard(),
    // AdminDashboard(), // Temporarily hidden from frontend; backend logic kept alive
    ProfessorDashboard(),
    CRDashboard(),
    StudentDashboard(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _portals,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0F172A),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined, size: 20),
              activeIcon: Icon(Icons.shield_rounded, size: 20),
              label: 'Moderator',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined, size: 20),
              activeIcon: Icon(Icons.school_rounded, size: 20),
              label: 'Professor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.badge_outlined, size: 20),
              activeIcon: Icon(Icons.badge_rounded, size: 20),
              label: 'CR',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded, size: 20),
              activeIcon: Icon(Icons.person_rounded, size: 20),
              label: 'Student',
            ),
          ],
        ),
      ),
    );
  }
}
