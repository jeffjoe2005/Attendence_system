import 'api_service.dart';

class CourseApiService {
  CourseApiService._();
  static final CourseApiService instance = CourseApiService._();

  Future<List<Map<String, String>>> fetchCourses({
    String? branch,
    String? semester,
    String? professorEmail,
  }) async {
    final params = <String, String>{};
    if (branch != null && branch != 'All') params['branch'] = branch;
    if (semester != null && semester != 'All') params['semester'] = semester;
    if (professorEmail != null && professorEmail.isNotEmpty) params['professor_email'] = professorEmail;

    final data = await ApiService.instance.get('/api/courses', queryParams: params);
    if (data is List) {
      return data.map<Map<String, String>>((item) {
        return {
          'id': item['id']?.toString() ?? '',
          'code': item['course_code']?.toString() ?? '',
          'name': item['course_name']?.toString() ?? '',
          'branch': item['branch']?.toString() ?? 'ECE',
          'semester': item['semester_label']?.toString() ?? 'VI Sem',
          'type': item['type']?.toString() ?? 'Theory',
          'professor_name': item['professor_name']?.toString() ?? '',
          'professor_email': item['professor_email']?.toString() ?? '',
        };
      }).toList();
    }
    return [];
  }

  Future<void> createCourse({
    required String code,
    required String name,
    required String branch,
    required String semester,
    String type = 'Theory',
    String? professorName,
    String? professorEmail,
  }) async {
    await ApiService.instance.post(
      '/api/courses',
      body: {
        'code': code.trim().toUpperCase(),
        'name': name.trim(),
        'branch': branch.trim().toUpperCase(),
        'semester': semester.trim(),
        'type': type.trim(),
        if (professorName != null) 'professor_name': professorName.trim(),
        if (professorEmail != null) 'professor_email': professorEmail.trim().toLowerCase(),
      },
    );
  }

  Future<void> updateCourse({
    required String oldCode,
    required String newCode,
    required String newName,
    required String newBranch,
    required String newSemester,
    required String newType,
  }) async {
    await ApiService.instance.put(
      '/api/courses/$oldCode',
      body: {
        'new_code': newCode.trim().toUpperCase(),
        'new_name': newName.trim(),
        'new_branch': newBranch.trim().toUpperCase(),
        'new_semester': newSemester.trim(),
        'new_type': newType.trim(),
      },
    );
  }

  Future<void> deleteCourse(String code) async {
    await ApiService.instance.delete('/api/courses/$code');
  }

  Future<void> assignProfessor({
    required String courseCode,
    required String professorName,
    String? professorEmail,
  }) async {
    await ApiService.instance.post(
      '/api/courses/$courseCode/assign',
      body: {
        'professor_name': professorName.trim(),
        if (professorEmail != null) 'professor_email': professorEmail.trim().toLowerCase(),
      },
    );
  }

  Future<Map<String, dynamic>> bulkSyncCourses(List<Map<String, String>> courses) async {
    final payload = courses.map((c) => {
      'code': c['code'] ?? '',
      'name': c['name'] ?? '',
      'branch': c['branch'] ?? 'ECE',
      'semester': c['semester'] ?? 'VI Sem',
      'type': c['type'] ?? 'Theory',
      'professor_name': c['coordinator'] ?? c['professor_name'] ?? '',
      'professor_email': c['professor_email'] ?? '',
    }).toList();

    final res = await ApiService.instance.post('/api/courses/bulk-sync', body: payload);
    return res is Map<String, dynamic> ? res : {};
  }
}

