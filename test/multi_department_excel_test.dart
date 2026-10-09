import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_system/providers/moderator_data_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Department Import Tests (Civil, Mechanical, CSE)', () {
    test('Civil Engineering (CE) Import: branch, courses, and coordinators', () {
      final provider = ModeratorDataProvider();
      provider.resetSemester();

      // Simulate a Civil Engineering CSV/Excel data content
      final ceData = '''
Department of Civil Engineering - Course List Even Semester 2026
Sl No,Course Code,Course Name,L-T-P,Semester,Course Coordinator
1,CE250,Structural Analysis-I,3-0-0,IV Sem,Dr. Sarath Babu
2,CE251,Geotechnical Engineering,3-0-0,IV Sem,Dr. Rajesh Prabhu Gaonkar
3,CE252,Surveying & Geomatics,3-0-0,IV Sem,Dr. Sarath Babu
4,CE253,Geotechnical Engineering Lab,0-0-3,IV Sem,Dr. Rajesh Prabhu Gaonkar
5,HU350,Professional Ethics & Human Values,3-0-0,VI Sem,Dr. Sarani Ghosal Mondal
6,CE350,Design of Concrete Structures,3-0-0,VI Sem,Dr. Sarath Babu
7,CE351,Transportation Engineering,3-0-0,VI Sem,Dr. Rajesh Prabhu Gaonkar
''';

      final res = provider.importCsvData(ceData);
      expect(res['courses'], equals(7));

      final ceCourses = provider.courses.where((c) => c['branch'] == 'CVE').toList();
      expect(ceCourses.length, equals(7));

      // Verify specific course assignments and faculty departments
      expect(provider.getProfessorForCourse('CE250'), equals('Dr. Sarath Babu'));
      expect(provider.getProfessorForCourse('CE251'), equals('Dr. Rajesh Prabhu Gaonkar'));
      expect(provider.getProfessorForCourse('HU350'), equals('Dr. Sarani Ghosal Mondal'));

      // Check professor departments
      final sarath = provider.professors.firstWhere((p) => p['name'] == 'Dr. Sarath Babu');
      expect(sarath['department'], equals('CVE'));
      expect(sarath['email'], contains('nitgoa.ac.in'));
    });

    test('Mechanical Engineering (MCE) Import: branch, courses, and coordinators', () {
      final provider = ModeratorDataProvider();
      provider.resetSemester();

      final meData = '''
Department of Mechanical Engineering - Course List Even Semester 2026
Sl No,Course Code,Course Name,L-T-P,Semester,Course Coordinator
1,ME250,Fluid Mechanics & Machinery,3-0-0,IV Sem,Dr. Shiba Sundar Mahapatra
2,ME251,Kinematics of Machinery,3-0-0,IV Sem,Dr. Ravi Raghav
3,ME252,Manufacturing Technology,3-0-0,IV Sem,Dr. Prashant Kumar
4,IE250,Innovation and Entrepreneurship,3-0-0,IV Sem,Dr. Sunil Kumar A
5,ME350,Heat & Mass Transfer,3-0-0,VI Sem,Dr. Ravi Raghav
6,ME351,Design of Machine Elements,3-0-0,VI Sem,Dr. Prashant Kumar
''';

      final res = provider.importCsvData(meData);
      expect(res['courses'], equals(6));

      final meCourses = provider.courses.where((c) => c['branch'] == 'MCE').toList();
      expect(meCourses.length, equals(6));

      expect(provider.getProfessorForCourse('ME250'), equals('Dr. Shiba Sundar Mahapatra'));
      expect(provider.getProfessorForCourse('ME251'), equals('Dr. Ravi Raghav'));
      expect(provider.getProfessorForCourse('ME252'), equals('Dr. Prashant Kumar'));
      expect(provider.getProfessorForCourse('IE250'), equals('Dr. Sunil Kumar A'));

      final shiba = provider.professors.firstWhere((p) => p['name'] == 'Dr. Shiba Sundar Mahapatra');
      expect(shiba['department'], equals('MCE'));
    });

    test('Computer Science & Engineering (CSE) Import: branch, courses, and coordinators', () {
      final provider = ModeratorDataProvider();
      provider.resetSemester();

      final cseData = '''
Department of Computer Science and Engineering - Course List Even Semester 2026
Sl No,Course Code,Course Name,L-T-P,Semester,Course Coordinator
1,CS250,Data Structures & Algorithms,3-0-0,IV Sem,Dr. Pravati Swain
2,CS251,Computer Organization & Architecture,3-0-0,IV Sem,Dr. Damodar Reddy
3,CS252,Database Management Systems,3-0-0,IV Sem,Dr. Venkat Subba Reddy
4,CS253,Theory of Computation,3-0-0,IV Sem,Dr. B. R. Chandavarkar
5,HS350,Industrial Economics,3-0-0,VI Sem,Dr. Sunil Kumar A
6,CS350,Compiler Design,3-0-0,VI Sem,Dr. Damodar Reddy
7,CS351,Computer Networks,3-0-0,VI Sem,Dr. Pravati Swain
''';

      final res = provider.importCsvData(cseData);
      expect(res['courses'], equals(7));

      final cseCourses = provider.courses.where((c) => c['branch'] == 'CSE').toList();
      expect(cseCourses.length, equals(7));

      expect(provider.getProfessorForCourse('CS250'), equals('Dr. Pravati Swain'));
      expect(provider.getProfessorForCourse('CS251'), equals('Dr. Damodar Reddy'));
      expect(provider.getProfessorForCourse('CS252'), equals('Dr. Venkat Subba Reddy'));
      expect(provider.getProfessorForCourse('CS253'), equals('Dr. B. R. Chandavarkar'));
      expect(provider.getProfessorForCourse('HS350'), equals('Dr. Sunil Kumar A'));

      final pravati = provider.professors.firstWhere((p) => p['name'] == 'Dr. Pravati Swain');
      expect(pravati['department'], equals('CSE'));
    });

    test('Dynamic Faculty Auto-Generation for New/Unregistered Professor', () {
      final provider = ModeratorDataProvider();

      final newProfData = '''
Department of Civil Engineering
Sl No,Course Code,Course Name,Semester,Course Coordinator
1,CE450,Advanced Bridge Engineering,VIII Sem,Dr. Vikram Malhotra
2,CE451,Smart City Transportation,VIII Sem,Dr. Ananya Sen
''';

      final res = provider.importCsvData(newProfData);
      expect(res['courses'], equals(2));

      // Verifies newly encountered professors are dynamically created
      expect(provider.getProfessorForCourse('CE450'), equals('Dr. Vikram Malhotra'));
      expect(provider.getProfessorForCourse('CE451'), equals('Dr. Ananya Sen'));

      final vikram = provider.professors.firstWhere((p) => p['name'] == 'Dr. Vikram Malhotra');
      expect(vikram['department'], equals('CVE'));
      expect(vikram['email'], equals('dr.vikram.malhotra@nitgoa.ac.in'));
    });
  });
}
