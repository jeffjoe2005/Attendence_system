import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_system/providers/moderator_data_provider.dart';
import 'package:attendance_system/services/local_storage_service.dart';

void main() {
  test('Verify local storage saves and loads attendance system state', () async {
    final provider = ModeratorDataProvider();
    // Verify provider initializes with data
    expect(provider.courses.isNotEmpty, isTrue);
    expect(provider.professors.isNotEmpty, isTrue);

    // Add a test course
    provider.addCourse('Cloud Computing Test', 'CS899', branch: 'CSE', semester: 'VIII Sem');
    provider.assignProfessor('CS899', 'Dr. Damodar Reddy');

    // Force save
    await provider.saveToStorage();

    // Verify storage file exists
    final file = await LocalStorageService.getStorageFile();
    expect(file.existsSync(), isTrue);

    final content = await file.readAsString();
    expect(content.contains('CS899'), isTrue);
    expect(content.contains('Dr. Damodar Reddy'), isTrue);

    // Create a new provider instance and verify loadFromStorage restores state
    final newProvider = ModeratorDataProvider();
    await newProvider.loadFromStorage();
    final loadedCourse = newProvider.courses.firstWhere((c) => c['code'] == 'CS899', orElse: () => {});
    expect(loadedCourse.isNotEmpty, isTrue);
    expect(loadedCourse['name'], equals('Cloud Computing Test'));
    expect(newProvider.getProfessorForCourse('CS899'), equals('Dr. Damodar Reddy'));

    // Test JSON export and import
    final jsonString = newProvider.exportJsonString();
    expect(jsonString.contains('CS899'), isTrue);

    final restoreResult = await newProvider.importJsonString(jsonString);
    expect(restoreResult, isTrue);

    // Test restore defaults
    await newProvider.restoreDefaults();
    final afterRestoreCodes = newProvider.courses.map((c) => c['code']).toList();
    expect(afterRestoreCodes.contains('CS899'), isFalse);
    expect(newProvider.courses.isNotEmpty, isTrue);
  });
}
