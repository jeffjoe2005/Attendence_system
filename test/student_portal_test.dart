import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_system/main.dart';
import 'package:attendance_system/providers/auth_provider.dart';
import 'package:attendance_system/providers/moderator_data_provider.dart';
import 'package:attendance_system/screens/auth/login_screen.dart';
import 'package:attendance_system/screens/student/student_dashboard.dart';

void main() {
  testWidgets('Student Portal shows registered courses, counts, percentages, and Red/Yellow/Green highlights without top summary or bars', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final modData = ModeratorDataProvider(
      seedDefaults: true,
      loadFromStorageOnStart: false,
    );
    final auth = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: modData),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          home: StudentDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default active student is 22ECE001 (Rahul Patil, ECE, VI Sem)
    expect(find.text('Rahul Patil'), findsOneWidget);
    expect(find.text('Registered Courses'), findsOneWidget);

    // Top overall attendance summary card, student switcher, and progress bars must NOT be present
    expect(find.text('Overall Attendance'), findsNothing);
    expect(find.text('Missed'), findsNothing);
    expect(find.text('Switch Student:'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // Per-course stat labels should appear
    expect(find.text('Classes Taken'), findsWidgets);
    expect(find.text('Attended'), findsWidgets);
    expect(find.text('Percentage'), findsWidgets);

    // Verify courses in all three color brackets + 0-class course for 22ECE001:
    // HS350: 9/10 = 90.0% (GREEN)
    expect(find.text('HS350'), findsOneWidget);
    expect(find.text('90.0%'), findsOneWidget);

    // ES300: 6/8 = 75.0% (YELLOW)
    expect(find.text('ES300'), findsOneWidget);
    expect(find.text('75.0%'), findsWidgets);

    // EC351: 6/10 = 60.0% (RED)
    expect(find.text('EC351'), findsOneWidget);
    expect(find.text('60.0%'), findsOneWidget);

    // Verify color highlighting on percentage texts
    final greenPctText = tester.widget<Text>(find.text('90.0%').first);
    expect(greenPctText.style?.color, equals(const Color(0xFF15803D)));

    final yellowPctText = tester.widget<Text>(find.text('75.0%').first);
    expect(yellowPctText.style?.color, equals(const Color(0xFFA16207)));

    final redPctText = tester.widget<Text>(find.text('60.0%').first);
    expect(redPctText.style?.color, equals(const Color(0xFFB91C1C)));

    // Scroll down to verify EC356 (0 classes) shows '—' and 'No Classes Yet'
    await tester.scrollUntilVisible(
      find.text('EC356'),
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('EC356'), findsOneWidget);
    expect(find.text('No Classes Yet'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('Student Portal threshold boundary check (Red <75%, Yellow 75-80%, Green >80%)', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final modData = ModeratorDataProvider(
      seedDefaults: true,
      loadFromStorageOnStart: false,
    );

    // Add 4 boundary test courses for CSE VI Sem (student 22CSE010 - Aarav Sharma)
    modData.addCourse('Course Red', 'CS101', branch: 'CSE', semester: 'VI Sem');
    modData.addCourse('Course Yellow Low', 'CS102', branch: 'CSE', semester: 'VI Sem');
    modData.addCourse('Course Yellow High', 'CS103', branch: 'CSE', semester: 'VI Sem');
    modData.addCourse('Course Green', 'CS104', branch: 'CSE', semester: 'VI Sem');

    // CS101: 7/10 = 70.0% -> RED (< 75%)
    for (int i = 1; i <= 10; i++) {
      modData.recordAttendance(
        courseCode: 'CS101',
        date: '2026-04-${i.toString().padLeft(2, '0')}',
        lectureNumber: i,
        markedBy: 'p@nitgoa.ac.in',
        markedByName: 'Prof',
        presentRolls: i <= 7 ? ['22CSE010'] : [],
        absentRolls: i <= 7 ? [] : ['22CSE010'],
      );
    }
    // CS102: 3/4 = 75.0% -> YELLOW (exact 75%)
    for (int i = 1; i <= 4; i++) {
      modData.recordAttendance(
        courseCode: 'CS102',
        date: '2026-04-${i.toString().padLeft(2, '0')}',
        lectureNumber: i,
        markedBy: 'p@nitgoa.ac.in',
        markedByName: 'Prof',
        presentRolls: i <= 3 ? ['22CSE010'] : [],
        absentRolls: i <= 3 ? [] : ['22CSE010'],
      );
    }
    // CS103: 4/5 = 80.0% -> YELLOW (exact 80%)
    for (int i = 1; i <= 5; i++) {
      modData.recordAttendance(
        courseCode: 'CS103',
        date: '2026-04-${i.toString().padLeft(2, '0')}',
        lectureNumber: i,
        markedBy: 'p@nitgoa.ac.in',
        markedByName: 'Prof',
        presentRolls: i <= 4 ? ['22CSE010'] : [],
        absentRolls: i <= 4 ? [] : ['22CSE010'],
      );
    }
    // CS104: 5/6 = 83.3% -> GREEN (> 80%)
    for (int i = 1; i <= 6; i++) {
      modData.recordAttendance(
        courseCode: 'CS104',
        date: '2026-04-${i.toString().padLeft(2, '0')}',
        lectureNumber: i,
        markedBy: 'p@nitgoa.ac.in',
        markedByName: 'Prof',
        presentRolls: i <= 5 ? ['22CSE010'] : [],
        absentRolls: i <= 5 ? [] : ['22CSE010'],
      );
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: modData),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MaterialApp(home: StudentDashboard(studentRoll: '22CSE010')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('Switch Student:'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);

    // Scroll to verify all 4 boundary percentages and their colors
    await tester.scrollUntilVisible(
      find.text('CS104'),
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text('70.0%')).style?.color, equals(const Color(0xFFB91C1C)));
    expect(tester.widget<Text>(find.text('75.0%').first).style?.color, equals(const Color(0xFFA16207)));
    expect(tester.widget<Text>(find.text('80.0%').first).style?.color, equals(const Color(0xFFA16207)));
    expect(tester.widget<Text>(find.text('83.3%')).style?.color, equals(const Color(0xFF15803D)));
  });

  testWidgets('Student Portal responsive mobile layout, search, and colour-band filter pills', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final modData = ModeratorDataProvider(
      seedDefaults: true,
      loadFromStorageOnStart: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: modData),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MaterialApp(home: StudentDashboard()),
      ),
    );
    await tester.pumpAndSettle();

    // Filter to < 75% Short courses
    await tester.tap(find.text('< 75% Short'));
    await tester.pumpAndSettle();
    expect(find.text('EC351'), findsOneWidget);
    expect(find.text('HS350'), findsNothing);

    // Search within courses after resetting band to All
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'HS350');
    await tester.pumpAndSettle();
    expect(find.text('Industrial Economics'), findsOneWidget);
    expect(find.text('EC351'), findsNothing);
  });

  testWidgets('AppRouter directs any @nitgoa.ac.in authenticated user directly to StudentDashboard', (tester) async {
    final modData = ModeratorDataProvider(
      seedDefaults: true,
      loadFromStorageOnStart: false,
    );
    final auth = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: modData),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(home: AppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    // Prior to login, LoginScreen is shown with Google sign-in button
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(StudentDashboard), findsNothing);

    // Sign in with any @nitgoa.ac.in account
    await auth.signInWithEmail('anyuser@nitgoa.ac.in', modData: modData);
    await tester.pumpAndSettle();

    // Verified: Opens directly in StudentDashboard
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(StudentDashboard), findsOneWidget);
    expect(find.text('Registered Courses'), findsOneWidget);
  });
}
