// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_system/providers/moderator_data_provider.dart';

void main() {
  test('Test Excel import on ECE department Excel file', () {
    final file = File(r'C:\Users\spars\Downloads\ECE_Department_Courses_Even_Sem_2026.xlsx');
    expect(file.existsSync(), isTrue, reason: 'File should exist');
    final bytes = file.readAsBytesSync();

    final provider = ModeratorDataProvider();
    final result = provider.importExcelBytes(bytes);
    expect((result['courses'] ?? 0) > 0, isTrue);

    print('=== IMPORTED COURSES ===');
    for (final c in provider.courses) {
      final code = c['code']!;
      final prof = provider.getProfessorForCourse(code);
      print('${c['code']?.padRight(8)} | ${c['semester']?.padRight(12)} | ${c['branch']?.padRight(6)} | ${c['name']?.padRight(40)} | $prof');
    }

    // Check specific courses
    final hs350 = provider.courses.firstWhere((c) => c['code'] == 'HS350', orElse: () => {});
    expect(hs350.isNotEmpty, isTrue, reason: 'HS350 should be present');
    print('HS350: $hs350');

    final es300 = provider.courses.firstWhere((c) => c['code'] == 'ES300', orElse: () => {});
    expect(es300.isNotEmpty, isTrue, reason: 'ES300 should be present');
    print('ES300: $es300');

    final ec520 = provider.courses.firstWhere((c) => c['code'] == 'EC520', orElse: () => {});
    expect(ec520.isNotEmpty, isTrue, reason: 'EC520 should be present');
    print('EC520: $ec520');

    final cs901 = provider.courses.firstWhere((c) => c['code'] == 'CS901', orElse: () => {});
    expect(cs901.isNotEmpty, isTrue, reason: 'CS901 should be present');
    print('CS901: $cs901');
  });
}
