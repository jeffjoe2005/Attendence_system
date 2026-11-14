import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_system/providers/moderator_data_provider.dart';
import 'package:attendance_system/screens/teacher/local_professor_portal.dart';

void main() {
  test('Local professor identity uses one faculty match and only assigned courses', () {
    final data = ModeratorDataProvider(seedDefaults: false, loadFromStorageOnStart: false, persistLocal: false);
    data.addProfessor('anirban@nitgoa.ac.in', name: 'Dr. Anirban Chatterjee');
    data.addProfessor('smith@nitgoa.ac.in', name: 'Dr. Smith');
    data.addCourse('Antennas', 'EC351', branch: 'ECE', semester: 'VI Sem');
    data.assignProfessor('EC351', 'Dr. Anirban Chatterjee');
    expect(data.resolveLocalProfessor('hackathon1379@gmail.com'), 'anirban@nitgoa.ac.in');
    expect(data.resolveLocalProfessor('anirbanchatterjee@nitgoa.ac.in'), 'anirban@nitgoa.ac.in');
    expect(data.resolveLocalProfessor('23MCE1032@nitgoa.ac.in'), isNull);
    expect(data.isCourseAssignedToProfessor('EC351', 'anirban@nitgoa.ac.in'), isTrue);
    expect(data.isCourseAssignedToProfessor('EC351', 'smith@nitgoa.ac.in'), isFalse);
    data.addProfessor('another@nitgoa.ac.in', name: 'Anirban Other');
    expect(data.resolveLocalProfessor('anirban.new@nitgoa.ac.in'), isNull);
    data.dispose();
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('Local attendance and history work at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = ModeratorDataProvider(seedDefaults: false, loadFromStorageOnStart: false, persistLocal: false);
      data.addCourse('Antennas', 'EC351', branch: 'ECE', semester: 'VI Sem');
      data.ensureLocalDemoRoster(data.courses.single);
      data.registerLocalStudent('23EC1032@nitgoa.ac.in', 'Test Student');
      final today = DateTime.now().toIso8601String().split('T').first;
      data.recordAttendance(courseCode: 'EC351', date: today, lectureNumber: 1,
        markedBy: 'hackathon1379@gmail.com', markedByName: 'Dr. Anirban Chatterjee',
        presentRolls: data.students.map((s) => s['roll']!).toList(), absentRolls: []);
      final restored = ModeratorDataProvider(seedDefaults: false, loadFromStorageOnStart: false, persistLocal: false);
      restored.fromJson(data.toJson());
      expect(restored.getSessionsForCourse('EC351').length, 1);
      expect(restored.getStudentAttendanceStats('23EC1032')['percentage'], 100);
      await tester.pumpWidget(ChangeNotifierProvider.value(value: restored,
        child: MaterialApp(home: LocalAttendancePage(course: restored.courses.single,
          email: 'hackathon1379@gmail.com', professor: 'Dr. Anirban Chatterjee'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Save Correction'), findsOneWidget);
      await tester.ensureVisible(find.text('All Absent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All Absent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Correction'));
      await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 300)); });
      await tester.pumpAndSettle();
      expect(restored.getSessionsForCourse('EC351').length, 1);
      expect(restored.getStudentAttendanceStats('23EC1032')['percentage'], 0);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('local-history-tab')), -200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('local-history-tab')));
      await tester.pumpAndSettle();
      expect(find.text('Student Name'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      data.dispose(); restored.dispose();
    });
  }
}
