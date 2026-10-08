import 'package:flutter/material.dart';
import 'package:excel/excel.dart';

/// Shared centralized data store for Moderator, Admin, Professor, CR, and Student portals.
/// Supports 5 engineering branches: CSE, ECE, EEE, ME, CE.
class ModeratorDataProvider extends ChangeNotifier {
  ModeratorDataProvider() {
    seedDefaultData();
  }

  // ── Supported Branches ──
  static const List<String> supportedBranches = ['CSE', 'ECE', 'EEE', 'ME', 'CE'];

  // ── Helper to derive branch from course code ──
  static String deriveBranch(String code) {
    final upper = code.trim().toUpperCase();
    if (upper.startsWith('CS')) return 'CSE';
    if (upper.startsWith('EC')) return 'ECE';
    if (upper.startsWith('EE')) return 'EEE';
    if (upper.startsWith('ME')) return 'ME';
    if (upper.startsWith('CE') || upper.startsWith('CV')) return 'CE';
    if (upper.startsWith('HS') || upper.startsWith('ES') || upper.startsWith('IE')) {
      // General engineering / Humanities
      return 'General';
    }
    return 'General';
  }

  // ── Helper to derive semester from code ──
  static String deriveSemester(String code) {
    final match = RegExp(r'\d+').firstMatch(code);
    if (match != null) {
      final num = int.tryParse(match.group(0) ?? '') ?? 0;
      if (num >= 200 && num < 300) return 'IV Sem';
      if (num >= 300 && num < 400) return 'VI Sem';
      if (num >= 400 && num < 600) return 'VIII Sem';
      if (num >= 600 && num < 900) return 'M.Tech';
      if (num >= 900) return 'Open Elective';
    }
    return 'General';
  }

  // ── Helper to extract name from email ──
  static String extractNameFromEmail(String email) {
    final prefix = email.split('@').first.trim();
    final parts = prefix.split(RegExp(r'[._\-]'));
    return parts
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + (p.length > 1 ? p.substring(1).toLowerCase() : ''))
        .join(' ');
  }

  // ═══════════════════════════════════════════════════════════
  // 1. COURSES
  // Map fields: 'code', 'name', 'branch', 'semester', 'type'
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, String>> _courses = [];
  List<Map<String, String>> get courses => List.unmodifiable(_courses);

  void addCourse(
    String name,
    String code, {
    String? branch,
    String? semester,
    String type = 'Theory',
  }) {
    final cleanCode = code.trim().toUpperCase();
    final cleanName = name.trim();
    if (cleanCode.isEmpty || cleanName.isEmpty) return;

    final determinedBranch = (branch != null && branch.trim().isNotEmpty)
        ? branch.trim()
        : deriveBranch(cleanCode);

    final determinedSemester = (semester != null && semester.trim().isNotEmpty)
        ? semester.trim()
        : deriveSemester(cleanCode);

    // Remove existing if duplicate code
    _courses.removeWhere((c) => c['code'] == cleanCode);
    _courses.add({
      'code': cleanCode,
      'name': cleanName,
      'branch': determinedBranch,
      'semester': determinedSemester,
      'type': type,
    });
    notifyListeners();
  }

  void updateCourse(
    String oldCode, {
    required String newCode,
    required String newName,
    String? newBranch,
    required String newSemester,
    required String newType,
  }) {
    final idx = _courses.indexWhere((c) => c['code'] == oldCode);
    if (idx != -1) {
      final cleanNewCode = newCode.trim().toUpperCase();
      final mapping = _mappings.remove(oldCode);
      if (mapping != null) {
        _mappings[cleanNewCode] = mapping;
      }
      _courses[idx] = {
        'code': cleanNewCode,
        'name': newName.trim(),
        'branch': (newBranch != null && newBranch.trim().isNotEmpty)
            ? newBranch.trim()
            : deriveBranch(cleanNewCode),
        'semester': newSemester.trim(),
        'type': newType.trim(),
      };
      notifyListeners();
    }
  }

  void removeCourse(String code) {
    _mappings.remove(code);
    _courses.removeWhere((c) => c['code'] == code);
    notifyListeners();
  }

  void removeCourseAt(int index) {
    if (index >= 0 && index < _courses.length) {
      final code = _courses[index]['code'] ?? '';
      _mappings.remove(code);
      _courses.removeAt(index);
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 2. PROFESSORS
  // Map fields: 'email', 'name', 'department'
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, String>> _professors = [];
  List<Map<String, String>> get professors => List.unmodifiable(_professors);
  List<String> get professorEmails => _professors.map((p) => p['email'] ?? '').toList();

  void addProfessor(String email, {String? name, String? department}) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return;

    final profName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : extractNameFromEmail(cleanEmail);

    _professors.removeWhere((p) => p['email'] == cleanEmail);
    _professors.add({
      'email': cleanEmail,
      'name': profName,
      'department': department ?? 'ECE',
    });
    notifyListeners();
  }

  void addProfessorEmail(String email) => addProfessor(email);

  void removeProfessor(String email) {
    _mappings.removeWhere((_, profIdentifier) => profIdentifier.contains(email));
    _professors.removeWhere((p) => p['email'] == email);
    notifyListeners();
  }

  void removeProfessorAt(int index) {
    if (index >= 0 && index < _professors.length) {
      final email = _professors[index]['email'] ?? '';
      removeProfessor(email);
    }
  }

  bool isProfessorEmail(String email) {
    final clean = email.trim().toLowerCase();
    return _professors.any((p) => p['email']?.toLowerCase() == clean);
  }

  String? getProfessorNameByEmail(String email) {
    final clean = email.trim().toLowerCase();
    final found = _professors.where((p) => p['email']?.toLowerCase() == clean);
    return found.isNotEmpty ? found.first['name'] : null;
  }

  // ═══════════════════════════════════════════════════════════
  // 3. CLASS REPRESENTATIVES (CRs)
  // Map fields: 'email', 'name', 'branch', 'semester'
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, String>> _crs = [];
  List<Map<String, String>> get crs => List.unmodifiable(_crs);
  List<String> get crEmails => _crs.map((c) => c['email'] ?? '').toList();

  void addCR(String email, {String? name, String? branch, String? semester}) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return;

    final crName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : extractNameFromEmail(cleanEmail);

    _crs.removeWhere((c) => c['email'] == cleanEmail);
    _crs.add({
      'email': cleanEmail,
      'name': crName,
      'branch': branch ?? 'ECE',
      'semester': semester ?? 'IV Sem',
    });
    notifyListeners();
  }

  void addCREmail(String email) => addCR(email);

  void removeCR(String email) {
    _crs.removeWhere((c) => c['email'] == email);
    notifyListeners();
  }

  void removeCRAt(int index) {
    if (index >= 0 && index < _crs.length) {
      _crs.removeAt(index);
      notifyListeners();
    }
  }

  bool isCREmail(String email) {
    final clean = email.trim().toLowerCase();
    return _crs.any((c) => c['email']?.toLowerCase() == clean);
  }

  // ═══════════════════════════════════════════════════════════
  // 4. PROFESSOR ↔ COURSE MAPPINGS
  // courseCode → professorDisplayNameOrEmail
  // ═══════════════════════════════════════════════════════════
  final Map<String, String> _mappings = {};
  Map<String, String> get mappings => Map.unmodifiable(_mappings);

  void assignProfessor(String courseCode, String professorNameOrEmail) {
    _mappings[courseCode.trim().toUpperCase()] = professorNameOrEmail.trim();
    notifyListeners();
  }

  void removeAssignment(String courseCode) {
    _mappings.remove(courseCode.trim().toUpperCase());
    notifyListeners();
  }

  String? getProfessorForCourse(String courseCode) =>
      _mappings[courseCode.trim().toUpperCase()];

  List<Map<String, String>> get unassignedCourses =>
      _courses.where((c) => !_mappings.containsKey(c['code'])).toList();

  List<Map<String, String>> get assignedCourses =>
      _courses.where((c) => _mappings.containsKey(c['code'])).toList();

  // ═══════════════════════════════════════════════════════════
  // 5. STUDENTS (by branch & semester)
  // Map fields: 'roll', 'name', 'branch', 'semester', 'email'
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, String>> _students = [];
  List<Map<String, String>> get students => List.unmodifiable(_students);

  List<Map<String, String>> getStudentsForCourse(String courseCode) {
    final course = _courses.firstWhere(
      (c) => c['code'] == courseCode,
      orElse: () => {},
    );
    if (course.isEmpty) return _students.take(15).toList();

    final branch = course['branch'] ?? 'ECE';
    final sem = course['semester'] ?? 'IV Sem';

    final matched = _students.where((s) {
      final sBranch = s['branch'] ?? '';
      final sSem = s['semester'] ?? '';
      return (branch == 'General' || sBranch == branch) && sSem == sem;
    }).toList();

    if (matched.isNotEmpty) return matched;
    // Fallback: Return students from that branch or sample list
    final branchStudents = _students.where((s) => s['branch'] == branch).toList();
    return branchStudents.isNotEmpty ? branchStudents : _students.take(15).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 6. ATTENDANCE SESSIONS & RECORDS
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> _attendanceSessions = [];
  List<Map<String, dynamic>> get attendanceSessions => List.unmodifiable(_attendanceSessions);

  void recordAttendance({
    required String courseCode,
    required String date,
    required int lectureNumber,
    required String markedBy,
    required String markedByName,
    required List<String> presentRolls,
    required List<String> absentRolls,
  }) {
    final id = 'att_${courseCode}_${date}_$lectureNumber';
    _attendanceSessions.removeWhere((s) => s['id'] == id);

    _attendanceSessions.add({
      'id': id,
      'courseCode': courseCode,
      'date': date,
      'lectureNumber': lectureNumber,
      'markedBy': markedBy,
      'markedByName': markedByName,
      'presentRolls': List<String>.from(presentRolls),
      'absentRolls': List<String>.from(absentRolls),
      'totalStudents': presentRolls.length + absentRolls.length,
      'timestamp': DateTime.now(),
    });
    notifyListeners();
  }

  List<Map<String, dynamic>> getSessionsForCourse(String courseCode) {
    return _attendanceSessions
        .where((s) => s['courseCode'] == courseCode)
        .toList()
      ..sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
  }

  Map<String, dynamic> getStudentAttendanceStats(String rollNumber) {
    int total = 0;
    int attended = 0;

    for (final s in _attendanceSessions) {
      final present = (s['presentRolls'] as List<String>? ?? []);
      final absent = (s['absentRolls'] as List<String>? ?? []);

      if (present.contains(rollNumber)) {
        total++;
        attended++;
      } else if (absent.contains(rollNumber)) {
        total++;
      }
    }

    final percentage = total > 0 ? (attended / total) * 100 : 85.0;
    return {
      'total': total > 0 ? total : 20,
      'attended': total > 0 ? attended : 17,
      'percentage': total > 0 ? percentage : 85.0,
    };
  }

  // ═══════════════════════════════════════════════════════════
  // 7. CSV / EXCEL PARSERS
  // ═══════════════════════════════════════════════════════════
  Map<String, int> importCsvData(String csvContent, {String? defaultBranch}) {
    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return {'courses': 0, 'professors': 0};

    final firstLine = lines.first;
    String delimiter = ',';
    if (firstLine.contains('\t')) {
      delimiter = '\t';
    } else if (firstLine.contains(';') && !firstLine.contains(',')) {
      delimiter = ';';
    }

    int headerIndex = 0;
    List<String> headers = [];
    for (int i = 0; i < lines.length && i < 5; i++) {
      final cells = lines[i].split(delimiter).map((c) => c.trim().toLowerCase()).toList();
      if (cells.any((c) => c.contains('code') || c.contains('course') || c.contains('subject'))) {
        headerIndex = i;
        headers = cells;
        break;
      }
    }

    if (headers.isEmpty) {
      headers = lines.first.split(delimiter).map((c) => c.trim().toLowerCase()).toList();
    }

    int codeIdx = -1;
    int nameIdx = -1;
    int branchIdx = -1;
    int semIdx = -1;
    int typeIdx = -1;
    int profIdx = -1;

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (codeIdx == -1 && (h.contains('code') || h == 'sub code' || h == 'course_code')) {
        codeIdx = i;
      } else if (nameIdx == -1 && (h.contains('name') || h.contains('title') || h.contains('subject') || h == 'course')) {
        nameIdx = i;
      } else if (branchIdx == -1 && (h.contains('branch') || h.contains('dept') || h.contains('department'))) {
        branchIdx = i;
      } else if (semIdx == -1 && (h.contains('sem') || h.contains('year') || h.contains('program'))) {
        semIdx = i;
      } else if (typeIdx == -1 && (h.contains('type') || h == 'l-t-p' || h == 'category')) {
        typeIdx = i;
      } else if (profIdx == -1 && (h.contains('coordinator') || h.contains('prof') || h.contains('faculty') || h.contains('teacher') || h.contains('instructor'))) {
        profIdx = i;
      }
    }

    if (codeIdx == -1 && headers.length > 1) codeIdx = 1;
    if (nameIdx == -1 && headers.length > 2) nameIdx = 2;

    int coursesAdded = 0;
    int profsAdded = 0;

    for (int i = headerIndex + 1; i < lines.length; i++) {
      final cells = lines[i].split(delimiter).map((c) => c.trim().replaceAll('"', '')).toList();
      if (codeIdx != -1 && codeIdx < cells.length) {
        final code = cells[codeIdx].toUpperCase();
        if (code.isEmpty || code.toLowerCase() == 'code' || code.toLowerCase().contains('sl')) continue;

        final name = (nameIdx != -1 && nameIdx < cells.length && cells[nameIdx].isNotEmpty)
            ? cells[nameIdx]
            : 'Course $code';

        final branch = (branchIdx != -1 && branchIdx < cells.length && cells[branchIdx].isNotEmpty)
            ? cells[branchIdx].toUpperCase()
            : (defaultBranch ?? deriveBranch(code));

        final sem = (semIdx != -1 && semIdx < cells.length && cells[semIdx].isNotEmpty)
            ? cells[semIdx]
            : deriveSemester(code);

        final type = (typeIdx != -1 && typeIdx < cells.length && cells[typeIdx].isNotEmpty)
            ? cells[typeIdx]
            : 'Theory';

        addCourse(name, code, branch: branch, semester: sem, type: type);
        coursesAdded++;

        if (profIdx != -1 && profIdx < cells.length) {
          final profValue = cells[profIdx].trim();
          if (profValue.isNotEmpty &&
              profValue.toLowerCase() != 'na' &&
              profValue.toLowerCase() != 'nil' &&
              profValue.toLowerCase() != '-') {
            String profName = profValue;
            String profEmail;
            if (profValue.contains('@')) {
              profEmail = profValue.toLowerCase();
              profName = extractNameFromEmail(profEmail);
            } else {
              final clean = profValue.replaceAll(RegExp(r'^(Dr\.|Prof\.|Mr\.|Ms\.)\s*', caseSensitive: false), '').trim();
              final emailSlug = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
              profEmail = '$emailSlug@nitgoa.ac.in';
            }

            addProfessor(profEmail, name: profName, department: branch);
            assignProfessor(code, '$profName ($profEmail)');
            profsAdded++;
          }
        }
      }
    }

    notifyListeners();
    return {'courses': coursesAdded, 'professors': profsAdded};
  }

  Map<String, int> importExcelBytes(List<int> bytes, {String? defaultBranch}) {
    final excel = Excel.decodeBytes(bytes);
    int coursesAdded = 0;
    int profsAdded = 0;

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.maxRows == 0) continue;

      final rows = <List<String>>[];
      for (final row in sheet.rows) {
        rows.add(row.map((cell) => cell?.value?.toString().trim() ?? '').toList());
      }

      if (rows.isEmpty) continue;

      int headerIdx = -1;
      List<String> headers = [];
      for (int r = 0; r < rows.length && r < 10; r++) {
        final line = rows[r].map((c) => c.toLowerCase()).toList();
        if (line.any((c) => c.contains('code') || c.contains('course') || c.contains('subject'))) {
          headerIdx = r;
          headers = line;
          break;
        }
      }

      if (headerIdx == -1) {
        headerIdx = 0;
        headers = rows.first.map((c) => c.toLowerCase()).toList();
      }

      int codeIdx = -1;
      int nameIdx = -1;
      int branchIdx = -1;
      int semIdx = -1;
      int typeIdx = -1;
      int profIdx = -1;

      for (int i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (codeIdx == -1 && (h.contains('code') || h.contains('sub code') || h.contains('course_code'))) {
          codeIdx = i;
        } else if (nameIdx == -1 && (h.contains('name') || h.contains('title') || h.contains('subject') || h.contains('course name'))) {
          nameIdx = i;
        } else if (branchIdx == -1 && (h.contains('branch') || h.contains('dept') || h.contains('department'))) {
          branchIdx = i;
        } else if (semIdx == -1 && (h.contains('sem') || h.contains('year') || h.contains('program'))) {
          semIdx = i;
        } else if (typeIdx == -1 && (h.contains('type') || h == 'l-t-p' || h == 'category')) {
          typeIdx = i;
        } else if (profIdx == -1 && (h.contains('coordinator') || h.contains('prof') || h.contains('faculty') || h.contains('teacher') || h.contains('instructor'))) {
          profIdx = i;
        }
      }

      if (codeIdx == -1 && headers.length > 1) codeIdx = 1;
      if (nameIdx == -1 && headers.length > 2) nameIdx = 2;

      for (int r = headerIdx + 1; r < rows.length; r++) {
        final cells = rows[r];
        if (codeIdx != -1 && codeIdx < cells.length) {
          final code = cells[codeIdx].toUpperCase();
          if (code.isEmpty || code.toLowerCase() == 'code' || code.toLowerCase().contains('sl') || code == 'SL. NO') continue;

          final name = (nameIdx != -1 && nameIdx < cells.length && cells[nameIdx].isNotEmpty)
              ? cells[nameIdx]
              : 'Course $code';

          final branch = (branchIdx != -1 && branchIdx < cells.length && cells[branchIdx].isNotEmpty)
              ? cells[branchIdx].toUpperCase()
              : (defaultBranch ?? deriveBranch(code));

          final sem = (semIdx != -1 && semIdx < cells.length && cells[semIdx].isNotEmpty)
              ? cells[semIdx]
              : deriveSemester(code);

          final type = (typeIdx != -1 && typeIdx < cells.length && cells[typeIdx].isNotEmpty)
              ? cells[typeIdx]
              : 'Theory';

          addCourse(name, code, branch: branch, semester: sem, type: type);
          coursesAdded++;

          if (profIdx != -1 && profIdx < cells.length) {
            final profValue = cells[profIdx].trim();
            if (profValue.isNotEmpty &&
                profValue.toLowerCase() != 'na' &&
                profValue.toLowerCase() != 'nil' &&
                profValue.toLowerCase() != '-') {
              String profName = profValue;
              String profEmail;
              if (profValue.contains('@')) {
                profEmail = profValue.toLowerCase();
                profName = extractNameFromEmail(profEmail);
              } else {
                final clean = profValue.replaceAll(RegExp(r'^(Dr\.|Prof\.|Mr\.|Ms\.)\s*', caseSensitive: false), '').trim();
                final emailSlug = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                profEmail = '$emailSlug@nitgoa.ac.in';
              }

              addProfessor(profEmail, name: profName, department: branch);
              assignProfessor(code, '$profName ($profEmail)');
              profsAdded++;
            }
          }
        }
      }
    }

    notifyListeners();
    return {'courses': coursesAdded, 'professors': profsAdded};
  }

  // ── Reset everything ──
  void resetSemester() {
    _courses.clear();
    _professors.clear();
    _crs.clear();
    _mappings.clear();
    _attendanceSessions.clear();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // 8. RICH SEED DATA FOR ALL 5 NIT GOA BRANCHES
  // (CSE, ECE, EEE, ME, CE)
  // ═══════════════════════════════════════════════════════════
  void seedDefaultData() {
    _courses.clear();
    _professors.clear();
    _crs.clear();
    _mappings.clear();
    _students.clear();
    _attendanceSessions.clear();

    // ── 1. ECE COURSES ──
    _courses.addAll([
      {'code': 'EC250', 'name': 'Numerical Methods for ECE', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EC251', 'name': 'Analog Electronics', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EC252', 'name': 'Principle of Communication Systems', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EC253', 'name': 'Sensor Technologies', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EC254', 'name': 'Semiconductor Devices', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EC255', 'name': 'Analog Electronics Lab', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Practical'},
      {'code': 'EC256', 'name': 'Communication Systems Lab', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Practical'},
      {'code': 'EC350', 'name': 'Digital Communication', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'EC351', 'name': 'Principles of Antenna & Radiation', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'EC352', 'name': 'VLSI Circuit Design', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'EC353', 'name': 'Digital Communication Lab', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Practical'},
      {'code': 'EC405', 'name': 'Digital System Design', 'branch': 'ECE', 'semester': 'VIII Sem', 'type': 'Theory'},
      {'code': 'EC424', 'name': 'Low-Power VLSI Circuit Design', 'branch': 'ECE', 'semester': 'VIII Sem', 'type': 'Theory'},
    ]);

    // ── 2. CSE COURSES ──
    _courses.addAll([
      {'code': 'CS250', 'name': 'Data Structures & Algorithms', 'branch': 'CSE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'CS251', 'name': 'Computer Organization & Architecture', 'branch': 'CSE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'CS252', 'name': 'Database Management Systems', 'branch': 'CSE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'CS253', 'name': 'Theory of Computation', 'branch': 'CSE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'CS254', 'name': 'DBMS Laboratory', 'branch': 'CSE', 'semester': 'IV Sem', 'type': 'Practical'},
      {'code': 'CS350', 'name': 'Compiler Design', 'branch': 'CSE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'CS351', 'name': 'Computer Networks', 'branch': 'CSE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'CS352', 'name': 'Software Engineering', 'branch': 'CSE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'CS522', 'name': 'Artificial Intelligence & Machine Learning', 'branch': 'CSE', 'semester': 'VIII Sem', 'type': 'Theory'},
      {'code': 'CS901', 'name': 'Object Oriented Programming (OE)', 'branch': 'CSE', 'semester': 'VI Sem', 'type': 'Open Elective'},
    ]);

    // ── 3. EEE COURSES ──
    _courses.addAll([
      {'code': 'EE250', 'name': 'Electrical Machines-I', 'branch': 'EEE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EE251', 'name': 'Power Electronics', 'branch': 'EEE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EE252', 'name': 'Control Systems Engineering', 'branch': 'EEE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EE253', 'name': 'Power Electronics Lab', 'branch': 'EEE', 'semester': 'IV Sem', 'type': 'Practical'},
      {'code': 'EE350', 'name': 'Power System Analysis', 'branch': 'EEE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'EE351', 'name': 'Microcontrollers & Applications', 'branch': 'EEE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'EE401', 'name': 'Renewable Energy Systems', 'branch': 'EEE', 'semester': 'VIII Sem', 'type': 'Theory'},
    ]);

    // ── 4. ME COURSES ──
    _courses.addAll([
      {'code': 'ME250', 'name': 'Fluid Mechanics & Machinery', 'branch': 'ME', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'ME251', 'name': 'Kinematics of Machinery', 'branch': 'ME', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'ME252', 'name': 'Manufacturing Technology', 'branch': 'ME', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'ME253', 'name': 'Fluid Mechanics Lab', 'branch': 'ME', 'semester': 'IV Sem', 'type': 'Practical'},
      {'code': 'ME350', 'name': 'Heat & Mass Transfer', 'branch': 'ME', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'ME351', 'name': 'Design of Machine Elements', 'branch': 'ME', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'ME401', 'name': 'Automobile Engineering', 'branch': 'ME', 'semester': 'VIII Sem', 'type': 'Theory'},
    ]);

    // ── 5. CE COURSES ──
    _courses.addAll([
      {'code': 'CE250', 'name': 'Structural Analysis-I', 'branch': 'CE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'CE251', 'name': 'Geotechnical Engineering', 'branch': 'CE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'CE252', 'name': 'Surveying & Geomatics', 'branch': 'CE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'CE253', 'name': 'Geotechnical Engineering Lab', 'branch': 'CE', 'semester': 'IV Sem', 'type': 'Practical'},
      {'code': 'CE350', 'name': 'Design of Concrete Structures', 'branch': 'CE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'CE351', 'name': 'Transportation Engineering', 'branch': 'CE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'CE401', 'name': 'Environmental Engineering', 'branch': 'CE', 'semester': 'VIII Sem', 'type': 'Theory'},
    ]);

    // ── Common / Humanities / Interdisciplinary ──
    _courses.addAll([
      {'code': 'HS350', 'name': 'Industrial Economics & Management', 'branch': 'General', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'ES300', 'name': 'Environmental Studies', 'branch': 'General', 'semester': 'VI Sem', 'type': 'MLC'},
      {'code': 'IE250', 'name': 'Innovation & Entrepreneurship', 'branch': 'General', 'semester': 'IV Sem', 'type': 'Theory'},
    ]);

    // ── SEED PROFESSORS ACROSS ALL BRANCHES ──
    _professors.addAll([
      // ECE Faculty
      {'email': 'najiya.vk@nitgoa.ac.in', 'name': 'Dr. Najiya V K', 'department': 'ECE'},
      {'email': 'lokesh.kumar@nitgoa.ac.in', 'name': 'Dr. Lokesh Kumar B', 'department': 'ECE'},
      {'email': 'pragati.patel@nitgoa.ac.in', 'name': 'Dr. Pragati Patel', 'department': 'ECE'},
      {'email': 'e.mallikarjun@nitgoa.ac.in', 'name': 'Dr. E. Mallikarjun', 'department': 'ECE'},
      {'email': 'lalat.indu@nitgoa.ac.in', 'name': 'Dr. Lalat Indu Giri', 'department': 'ECE'},
      {'email': 'trilochan.panigrahi@nitgoa.ac.in', 'name': 'Dr. Trilochan Panigrahi', 'department': 'ECE'},
      {'email': 'anirban.chatterjee@nitgoa.ac.in', 'name': 'Dr. Anirban Chatterjee', 'department': 'ECE'},
      {'email': 'nithin.kumar@nitgoa.ac.in', 'name': 'Dr. Nithin Kumar Y.B.', 'department': 'ECE'},
      {'email': 't.veerakumar@nitgoa.ac.in', 'name': 'Dr. T. Veerakumar', 'department': 'ECE'},
      {'email': 'vasantha.mh@nitgoa.ac.in', 'name': 'Dr. Vasantha M.H', 'department': 'ECE'},
      {'email': 'ishaan.bhate@nitgoa.ac.in', 'name': 'Ishaan Bhate', 'department': 'ECE'},

      // CSE Faculty
      {'email': 'pravati.swain@nitgoa.ac.in', 'name': 'Dr. Pravati Swain', 'department': 'CSE'},
      {'email': 'damodar.reddy@nitgoa.ac.in', 'name': 'Dr. Damodar Reddy', 'department': 'CSE'},
      {'email': 'keshavamurthy@nitgoa.ac.in', 'name': 'Dr. B. R. Chandavarkar', 'department': 'CSE'},
      {'email': 'venkat.subba@nitgoa.ac.in', 'name': 'Dr. Venkat Subba Reddy', 'department': 'CSE'},

      // EEE Faculty
      {'email': 'sreeraj.es@nitgoa.ac.in', 'name': 'Dr. Sreeraj E.S.', 'department': 'EEE'},
      {'email': 'amresh.kumar@nitgoa.ac.in', 'name': 'Dr. Amresh Kumar', 'department': 'EEE'},
      {'email': 'c.vyjayanthi@nitgoa.ac.in', 'name': 'Dr. C. Vyjayanthi', 'department': 'EEE'},

      // ME Faculty
      {'email': 'shiba.sundar@nitgoa.ac.in', 'name': 'Dr. Shiba Sundar Mahapatra', 'department': 'ME'},
      {'email': 'ravi.raghav@nitgoa.ac.in', 'name': 'Dr. Ravi Raghav', 'department': 'ME'},
      {'email': 'prashant.kumar@nitgoa.ac.in', 'name': 'Dr. Prashant Kumar', 'department': 'ME'},

      // CE Faculty
      {'email': 'sarath.babu@nitgoa.ac.in', 'name': 'Dr. Sarath Babu', 'department': 'CE'},
      {'email': 'rajesh.prabhu@nitgoa.ac.in', 'name': 'Dr. Rajesh Prabhu Gaonkar', 'department': 'CE'},

      // General / Humanities
      {'email': 'sunil.kumar@nitgoa.ac.in', 'name': 'Dr. Sunil Kumar A', 'department': 'Humanities'},
      {'email': 'velavan.k@nitgoa.ac.in', 'name': 'Dr. Velavan K', 'department': 'Humanities'},
      {'email': 'sarani.ghosal@nitgoa.ac.in', 'name': 'Dr. Sarani Ghosal Mondal', 'department': 'Humanities'},
    ]);

    // ── SEED CLASS REPRESENTATIVES FOR ALL 5 BRANCHES ──
    _crs.addAll([
      {'email': 'cr.ece4@nitgoa.ac.in', 'name': 'Rahul Patil (ECE CR)', 'branch': 'ECE', 'semester': 'IV Sem'},
      {'email': 'cr.cse4@nitgoa.ac.in', 'name': 'Aarav Sharma (CSE CR)', 'branch': 'CSE', 'semester': 'IV Sem'},
      {'email': 'cr.eee4@nitgoa.ac.in', 'name': 'Aditya Verma (EEE CR)', 'branch': 'EEE', 'semester': 'IV Sem'},
      {'email': 'cr.me4@nitgoa.ac.in', 'name': 'Rohan Kulkarni (ME CR)', 'branch': 'ME', 'semester': 'IV Sem'},
      {'email': 'cr.ce4@nitgoa.ac.in', 'name': 'Siddharth Pai (CE CR)', 'branch': 'CE', 'semester': 'IV Sem'},
    ]);

    // ── SEED COURSE ↔ PROFESSOR MAPPINGS ──
    // ECE Mappings
    _mappings['EC250'] = 'Dr. Najiya V K (najiya.vk@nitgoa.ac.in)';
    _mappings['EC251'] = 'Dr. Lokesh Kumar B (lokesh.kumar@nitgoa.ac.in)';
    _mappings['EC252'] = 'Dr. Pragati Patel (pragati.patel@nitgoa.ac.in)';
    _mappings['EC253'] = 'Dr. E. Mallikarjun (e.mallikarjun@nitgoa.ac.in)';
    _mappings['EC254'] = 'Dr. Lalat Indu Giri (lalat.indu@nitgoa.ac.in)';
    _mappings['EC255'] = 'Dr. Lokesh Kumar B (lokesh.kumar@nitgoa.ac.in)';
    _mappings['EC256'] = 'Dr. Pragati Patel (pragati.patel@nitgoa.ac.in)';
    _mappings['EC350'] = 'Dr. Trilochan Panigrahi (trilochan.panigrahi@nitgoa.ac.in)';
    _mappings['EC351'] = 'Dr. Anirban Chatterjee (anirban.chatterjee@nitgoa.ac.in)';
    _mappings['EC352'] = 'Dr. Nithin Kumar Y.B. (nithin.kumar@nitgoa.ac.in)';
    _mappings['EC353'] = 'Dr. Trilochan Panigrahi (trilochan.panigrahi@nitgoa.ac.in)';
    _mappings['EC405'] = 'Dr. Vasantha M.H (vasantha.mh@nitgoa.ac.in)';
    _mappings['EC424'] = 'Ishaan Bhate (ishaan.bhate@nitgoa.ac.in)';

    // CSE Mappings
    _mappings['CS250'] = 'Dr. Pravati Swain (pravati.swain@nitgoa.ac.in)';
    _mappings['CS251'] = 'Dr. Damodar Reddy (damodar.reddy@nitgoa.ac.in)';
    _mappings['CS252'] = 'Dr. Venkat Subba Reddy (venkat.subba@nitgoa.ac.in)';
    _mappings['CS253'] = 'Dr. B. R. Chandavarkar (keshavamurthy@nitgoa.ac.in)';
    _mappings['CS254'] = 'Dr. Venkat Subba Reddy (venkat.subba@nitgoa.ac.in)';
    _mappings['CS350'] = 'Dr. Damodar Reddy (damodar.reddy@nitgoa.ac.in)';
    _mappings['CS351'] = 'Dr. Pravati Swain (pravati.swain@nitgoa.ac.in)';
    _mappings['CS352'] = 'Dr. B. R. Chandavarkar (keshavamurthy@nitgoa.ac.in)';
    _mappings['CS522'] = 'Dr. Pravati Swain (pravati.swain@nitgoa.ac.in)';

    // EEE Mappings
    _mappings['EE250'] = 'Dr. Sreeraj E.S. (sreeraj.es@nitgoa.ac.in)';
    _mappings['EE251'] = 'Dr. Amresh Kumar (amresh.kumar@nitgoa.ac.in)';
    _mappings['EE252'] = 'Dr. C. Vyjayanthi (c.vyjayanthi@nitgoa.ac.in)';
    _mappings['EE253'] = 'Dr. Amresh Kumar (amresh.kumar@nitgoa.ac.in)';
    _mappings['EE350'] = 'Dr. C. Vyjayanthi (c.vyjayanthi@nitgoa.ac.in)';
    _mappings['EE351'] = 'Dr. Sreeraj E.S. (sreeraj.es@nitgoa.ac.in)';
    _mappings['EE401'] = 'Dr. Amresh Kumar (amresh.kumar@nitgoa.ac.in)';

    // ME Mappings
    _mappings['ME250'] = 'Dr. Shiba Sundar Mahapatra (shiba.sundar@nitgoa.ac.in)';
    _mappings['ME251'] = 'Dr. Ravi Raghav (ravi.raghav@nitgoa.ac.in)';
    _mappings['ME252'] = 'Dr. Prashant Kumar (prashant.kumar@nitgoa.ac.in)';
    _mappings['ME253'] = 'Dr. Shiba Sundar Mahapatra (shiba.sundar@nitgoa.ac.in)';
    _mappings['ME350'] = 'Dr. Ravi Raghav (ravi.raghav@nitgoa.ac.in)';
    _mappings['ME351'] = 'Dr. Prashant Kumar (prashant.kumar@nitgoa.ac.in)';

    // CE Mappings
    _mappings['CE250'] = 'Dr. Sarath Babu (sarath.babu@nitgoa.ac.in)';
    _mappings['CE251'] = 'Dr. Rajesh Prabhu Gaonkar (rajesh.prabhu@nitgoa.ac.in)';
    _mappings['CE252'] = 'Dr. Sarath Babu (sarath.babu@nitgoa.ac.in)';
    _mappings['CE253'] = 'Dr. Rajesh Prabhu Gaonkar (rajesh.prabhu@nitgoa.ac.in)';
    _mappings['CE350'] = 'Dr. Sarath Babu (sarath.babu@nitgoa.ac.in)';

    // General Mappings
    _mappings['HS350'] = 'Dr. Sunil Kumar A (sunil.kumar@nitgoa.ac.in)';
    _mappings['ES300'] = 'Dr. Velavan K (velavan.k@nitgoa.ac.in)';
    // Note: IE250 and CS901 are intentionally unassigned for mapping testing!

    // ── SEED REALISTIC STUDENTS FOR EACH BRANCH ──
    final branchCodes = ['ECE', 'CSE', 'EEE', 'ME', 'CE'];
    final sampleStudentNames = [
      ['Aarav Naik', 'Ananya Shenoy', 'Kavya Kamath', 'Rohan Dessai', 'Tanvi Prabhu', 'Varun Rao', 'Aditi Sawant', 'Sahil Borkar'],
      ['Dhruv Bhat', 'Isha Kulkarni', 'Meera Hegde', 'Nikhil Pai', 'Pooja Nayak', 'Sanket Joshi', 'Sneha Varde', 'Tejas Chari'],
      ['Abhishek Vernekar', 'Diya Gawas', 'Gaurav Faldesai', 'Neha Salgaonkar', 'Pranav Redkar', 'Rhea Coutinho', 'Siddhesh Shirodkar'],
      ['Akash Shet', 'Chinmayee Rane', 'Harsh Gaonkar', 'Manish Parsekar', 'Priyanka Mandrekar', 'Rushikesh Lotlikar', 'Tanmay Prabhu'],
      ['Alok Bandodkar', 'Deepa Sinari', 'Kunal Velip', 'Mrunal Dhargalkar', 'Omkar Parab', 'Sanika Gaude', 'Vivek Mascarenhas'],
    ];

    for (int b = 0; b < branchCodes.length; b++) {
      final br = branchCodes[b];
      final names = sampleStudentNames[b];
      for (int i = 0; i < names.length; i++) {
        final rollNo = '24$br${(i + 1).toString().padLeft(3, '0')}';
        final emailSlug = names[i].toLowerCase().replaceAll(' ', '.');
        _students.add({
          'roll': rollNo,
          'name': names[i],
          'branch': br,
          'semester': 'IV Sem',
          'email': '$emailSlug@nitgoa.ac.in',
        });
      }
    }

    // ── SEED INITIAL ATTENDANCE SESSIONS ──
    _attendanceSessions.addAll([
      {
        'id': 'att_EC250_2026-03-24_1',
        'courseCode': 'EC250',
        'date': '2026-03-24',
        'lectureNumber': 1,
        'markedBy': 'najiya.vk@nitgoa.ac.in',
        'markedByName': 'Dr. Najiya V K',
        'presentRolls': ['24ECE001', '24ECE002', '24ECE003', '24ECE004', '24ECE005', '24ECE006', '24ECE007'],
        'absentRolls': ['24ECE008'],
        'totalStudents': 8,
        'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      },
      {
        'id': 'att_EC250_2026-03-25_2',
        'courseCode': 'EC250',
        'date': '2026-03-25',
        'lectureNumber': 2,
        'markedBy': 'najiya.vk@nitgoa.ac.in',
        'markedByName': 'Dr. Najiya V K',
        'presentRolls': ['24ECE001', '24ECE002', '24ECE004', '24ECE005', '24ECE006', '24ECE008'],
        'absentRolls': ['24ECE003', '24ECE007'],
        'totalStudents': 8,
        'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      },
    ]);

    notifyListeners();
  }
}
