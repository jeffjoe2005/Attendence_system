import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_system/providers/auth_provider.dart';
import 'package:attendance_system/providers/moderator_data_provider.dart';
import 'package:attendance_system/screens/moderator/moderator_dashboard.dart';
import 'package:attendance_system/screens/teacher/teacher_dashboard.dart';

void main() {
  testWidgets('Test clicking + Course button in ModeratorDashboard', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final modData = ModeratorDataProvider();
    final auth = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: modData),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          home: ModeratorDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find the '+ Course' button
    final plusCourseBtn = find.text('+ Course');
    expect(plusCourseBtn, findsOneWidget);

    // Tap + Course
    await tester.tap(plusCourseBtn);
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Add course'), findsOneWidget);
    expect(find.text('Course code'), findsOneWidget);
    expect(find.text('Course name'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Add course'), findsNothing);
  });

  testWidgets('Test clicking on a course row in the table', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final modData = ModeratorDataProvider();
    final auth = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: modData),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          home: ModeratorDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll until EC250 is visible
    final ec250Finder = find.text('EC250');
    await tester.scrollUntilVisible(ec250Finder.first, 500.0, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(ec250Finder, findsWidgets);

    // Tap on EC250
    await tester.tap(ec250Finder.first);
    await tester.pumpAndSettle();

    // Verify Edit course dialog appears
    expect(find.text('Edit course'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit course'), findsNothing);
  });

  testWidgets('Test clicking Take Attendance in TeacherDashboard', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final modData = ModeratorDataProvider();
    final auth = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: modData),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          home: ProfessorDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final takeAttendanceBtn = find.text('Take Attendance');
    if (takeAttendanceBtn.evaluate().isNotEmpty) {
      await tester.tap(takeAttendanceBtn.first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Mark Attendance'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Test tapping edit icon in ModeratorDashboard table', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final modData = ModeratorDataProvider();
    final auth = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: modData),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          home: ModeratorDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editIcons = find.byIcon(Icons.edit_outlined);
    expect(editIcons, findsWidgets);

    // Tap first edit icon
    await tester.tap(editIcons.first);
    await tester.pumpAndSettle();

    expect(find.text('Edit course'), findsOneWidget);

    // Close
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit course'), findsNothing);
  });
}
