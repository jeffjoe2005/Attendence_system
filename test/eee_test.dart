import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_system/providers/moderator_data_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inspect EEE Department Excel file import', () {
    final file = File(r'C:\Users\spars\Downloads\EEE Department - Course List Even Semester 2026.xlsx');
    if (!file.existsSync()) {
      print('File not found at path: ${file.path}');
      return;
    }

    final bytes = file.readAsBytesSync();
    final provider = ModeratorDataProvider();

    // Test smart import with Auto-detect and filename
    final res = provider.importExcelBytes(bytes, fileName: file.path);
    print('Import result: $res');

    final eeeCourses = provider.courses.where((c) => c['branch'] == 'EEE').toList();
    print('Total EEE courses imported: ${eeeCourses.length}');
    expect(eeeCourses.isNotEmpty, isTrue);

    for (final c in eeeCourses.take(15)) {
      final prof = provider.getProfessorForCourse(c['code']!);
      print('${c['code']} | ${c['semester']} | ${c['name']} -> $prof');
      expect(prof, isNotNull);
      expect(prof, isNot(equals('Unassigned')));
    }

    // Verify coordinators are actual EEE faculty
    final sampleProfs = eeeCourses.map((c) => provider.getProfessorForCourse(c['code']!)).toSet();
    print('Sample assigned coordinators in EEE: $sampleProfs');
    expect(sampleProfs.any((p) => p != null && (p.contains('Suresh') || p.contains('Soumitra') || p.contains('Rahulkar') || p.contains('Chawrasia') || p.contains('Vyjayanthi') || p.contains('Sreeraj'))), isTrue);
  });
}
