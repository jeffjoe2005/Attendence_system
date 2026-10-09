import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../services/course_matcher_service.dart';
import '../services/local_storage_service.dart';

/// Shared centralized data store for Moderator, Admin, Professor, CR, and Student portals.
/// Supports 5 engineering branches: CSE, ECE, EEE, ME, CE.
class ModeratorDataProvider extends ChangeNotifier {
  bool _isLoadingFromStorage = false;
  bool _isSeeding = false;
  Future<void>? _loadFuture;

  ModeratorDataProvider() {
    _isSeeding = true;
    seedDefaultData();
    _isSeeding = false;
    _loadFuture = _performLoadFromStorage();
  }

  // ── Supported Branches (Official NIT Goa Acronyms) ──
  static const List<String> supportedBranches = ['CSE', 'ECE', 'EEE', 'MCE', 'CVE'];

  /// Normalizes any branch variation or legacy alias to official NIT Goa acronym
  static String normalizeBranch(String branch) {
    final clean = branch.trim().toUpperCase();
    if (clean == 'ME' || clean == 'MCE' || clean.contains('MECH')) return 'MCE';
    if (clean == 'CE' || clean == 'CVE' || clean.contains('CIVIL')) return 'CVE';
    if (clean == 'EEE' || clean.contains('ELECTRICAL')) return 'EEE';
    if (clean == 'ECE' || clean.contains('ELECTRONIC')) return 'ECE';
    if (clean == 'CSE' || clean.contains('COMPUTER')) return 'CSE';
    return clean;
  }

  // ── Helper to derive branch (avoids course code prefix logic separating courses) ──
  static String deriveBranch(String code, {String defaultBranch = 'ECE'}) {
    return defaultBranch;
  }

  // ── Helper to detect semester from text/label ──
  static String? detectSemesterFromText(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();

    // Must look like a semester header or designation
    // e.g. "BTech, VI Sem", "VI Sem", "Semester 6", "M.Tech", "4th Sem", "IV Sem"
    if (lower.contains('m.tech') || lower.contains('mtech') || lower.contains('m tech')) return 'M.Tech';
    if (lower.contains('open') && lower.contains('elective')) return 'Open Elective';

    final hasSemKeyword = lower.contains('sem') || lower.contains('btech') || lower.contains('b.tech') || lower.contains('year');

    // Check VIII
    if (RegExp(r'\b(viii|8th)\b').hasMatch(lower) || (hasSemKeyword && (lower.contains('8') || lower.contains('viii')))) return 'VIII Sem';

    // Check VII
    if (RegExp(r'\b(vii|7th)\b').hasMatch(lower) || (hasSemKeyword && (lower.contains('7') || lower.contains('vii')))) return 'VII Sem';

    // Check VI
    if (RegExp(r'\b(vi|6th)\b').hasMatch(lower) || (hasSemKeyword && (lower.contains('6') || lower.contains('vi')))) return 'VI Sem';

    // Check IV
    if (RegExp(r'\b(iv|4th)\b').hasMatch(lower) || (hasSemKeyword && (lower.contains('4') || lower.contains('iv')))) return 'IV Sem';

    // Check V
    if (RegExp(r'\b(5th)\b').hasMatch(lower) || (hasSemKeyword && (lower.contains('5') || RegExp(r'\bv\b').hasMatch(lower)))) return 'V Sem';

    // Check III
    if (RegExp(r'\b(iii|3rd)\b').hasMatch(lower) || (hasSemKeyword && (lower.contains('3') || lower.contains('iii')))) return 'III Sem';

    // Standalone Roman numerals with Sem or strict Sem label
    if (lower == 'vi sem' || lower == 'sem vi' || lower == 'semester vi' || lower == 'sem 6' || lower == 'vi') return 'VI Sem';
    if (lower == 'iv sem' || lower == 'sem iv' || lower == 'semester iv' || lower == 'sem 4' || lower == 'iv') return 'IV Sem';
    if (lower == 'viii sem' || lower == 'sem viii' || lower == 'semester viii' || lower == 'sem 8' || lower == 'viii') return 'VIII Sem';

    return null;
  }

  // ── Helper to derive semester from code ──
  static String deriveSemester(String code, {String defaultSemester = 'VI Sem'}) {
    final match = RegExp(r'\d+').firstMatch(code);
    if (match != null) {
      final num = int.tryParse(match.group(0) ?? '') ?? 0;
      if (num >= 200 && num < 300) return 'IV Sem';
      if (num >= 300 && num < 400) return 'VI Sem';
      if (num >= 400 && num < 600) return 'VIII Sem';
      if (num >= 600 && num < 900) return 'M.Tech';
    }
    return defaultSemester;
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
        ? normalizeBranch(branch)
        : 'ECE';

    final determinedSemester = (semester != null && semester.trim().isNotEmpty)
        ? (detectSemesterFromText(semester) ?? semester.trim())
        : deriveSemester(cleanCode);

    // Remove existing if duplicate code in the same branch
    _courses.removeWhere((c) => c['code'] == cleanCode && c['branch'] == determinedBranch);
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
            ? newBranch.trim().toUpperCase()
            : (_courses[idx]['branch'] ?? 'ECE'),
        'semester': (detectSemesterFromText(newSemester) ?? newSemester.trim()),
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
      'department': normalizeBranch(department ?? 'ECE'),
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

  String? getProfessorEmailByName(String name) {
    final clean = name.trim().toLowerCase();
    final found = _professors.where((p) => (p['name'] ?? '').trim().toLowerCase() == clean);
    return found.isNotEmpty ? found.first['email'] : null;
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
      'branch': normalizeBranch(branch ?? 'ECE'),
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
    var cleaned = professorNameOrEmail.trim();
    if (cleaned.contains('(') && cleaned.endsWith(')')) {
      final namePart = cleaned.substring(0, cleaned.indexOf('(')).trim();
      if (namePart.isNotEmpty) {
        cleaned = namePart;
      }
    } else if (cleaned.contains('@')) {
      cleaned = getProfessorNameByEmail(cleaned) ?? extractNameFromEmail(cleaned);
    }
    _mappings[courseCode.trim().toUpperCase()] = cleaned;
    notifyListeners();
  }

  bool isCourseAssignedToProfessor(String courseCode, String email) {
    final assigned = getProfessorForCourse(courseCode);
    if (assigned == null || email.trim().isEmpty) return false;
    final assignedClean = assigned.trim().toLowerCase();
    final emailClean = email.trim().toLowerCase();
    if (assignedClean.contains(emailClean)) return true;
    final name = getProfessorNameByEmail(email);
    if (name != null) {
      final nameClean = name.trim().toLowerCase();
      if (assignedClean == nameClean || assignedClean.contains(nameClean) || nameClean.contains(assignedClean)) {
        return true;
      }
    }
    return false;
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
      final present = List<String>.from(s['presentRolls'] as Iterable? ?? []);
      final absent = List<String>.from(s['absentRolls'] as Iterable? ?? []);

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
  static String detectBranchFromLines(Iterable<String> lines) {
    for (final line in lines.take(15)) {
      final l = line.toLowerCase();
      if (l.contains('eee department') || l.contains('electrical') || l.contains('dept of eee') || l.contains('department of eee')) {
        return 'EEE';
      }
      if (l.contains('ece department') || l.contains('electronics') || l.contains('dept of ece') || l.contains('department of ece')) {
        return 'ECE';
      }
      if (l.contains('cse department') || l.contains('computer science') || l.contains('dept of cse') || l.contains('department of cse')) {
        return 'CSE';
      }
      if (l.contains('mechanical') || l.contains('mce department') || l.contains('me department') || l.contains('dept of mce') || l.contains('department of mce')) {
        return 'MCE';
      }
      if (l.contains('civil') || l.contains('cve department') || l.contains('ce department') || l.contains('dept of cve') || l.contains('department of cve')) {
        return 'CVE';
      }
    }

    // Secondary fallback: count course code prefixes
    int cveCount = 0;
    int mceCount = 0;
    int cseCount = 0;
    int eeeCount = 0;
    int eceCount = 0;
    final codeRegex = RegExp(r'\b(CVE|CE|MCE|ME|CS|EE|EC)\d{3}\b', caseSensitive: false);
    for (final line in lines) {
      for (final match in codeRegex.allMatches(line)) {
        final prefix = (match.group(1) ?? '').toUpperCase();
        if (prefix == 'CE' || prefix == 'CVE') {
          cveCount++;
        } else if (prefix == 'ME' || prefix == 'MCE') {
          mceCount++;
        } else if (prefix == 'CS') {
          cseCount++;
        } else if (prefix == 'EE') {
          eeeCount++;
        } else if (prefix == 'EC') {
          eceCount++;
        }
      }
    }
    if (cveCount > 0 && cveCount >= mceCount && cveCount >= cseCount && cveCount >= eeeCount && cveCount >= eceCount) {
      return 'CVE';
    }
    if (mceCount > 0 && mceCount >= cveCount && mceCount >= cseCount && mceCount >= eeeCount && mceCount >= eceCount) {
      return 'MCE';
    }
    if (cseCount > 0 && cseCount >= cveCount && cseCount >= mceCount && cseCount >= eeeCount && cseCount >= eceCount) {
      return 'CSE';
    }
    if (eeeCount > 0 && eeeCount >= cveCount && eeeCount >= mceCount && eeeCount >= cseCount && eeeCount >= eceCount) {
      return 'EEE';
    }
    if (eceCount > 0 && eceCount >= cveCount && eceCount >= mceCount && eceCount >= cseCount && eceCount >= eeeCount) {
      return 'ECE';
    }

    return '';
  }

  static String resolveCourseBranch(String code, {String? cellBranch, required String fallbackBranch}) {
    if (cellBranch != null && cellBranch.trim().isNotEmpty && !cellBranch.toLowerCase().contains('sem')) {
      final b = normalizeBranch(cellBranch);
      if (supportedBranches.contains(b)) return b;
    }
    final clean = code.trim().toUpperCase();
    if (clean.startsWith('EE')) return 'EEE';
    if (clean.startsWith('CS')) return 'CSE';
    if (clean.startsWith('EC')) return 'ECE';
    if (clean.startsWith('ME') || clean.startsWith('MCE')) return 'MCE';
    if (clean.startsWith('CE') || clean.startsWith('CVE')) return 'CVE';
    return normalizeBranch(fallbackBranch);
  }

  int assignImportedFaculty(List<Map<String, String>> rawCourses, String targetBranch) {
    int profsAssigned = 0;
    final unassignedCourses = <Map<String, String>>[];

    for (final c in rawCourses) {
      final code = c['code']!;
      final branch = c['branch']!;
      final rawCoord = c['coordinator'] ?? '';
      if (rawCoord.trim().isNotEmpty) {
        final coordinators = CourseMatcherService.splitCoordinators(rawCoord);
        final primaryCoord = coordinators.isNotEmpty ? coordinators.first : CourseMatcherService.normalizeProfName(rawCoord);
        if (primaryCoord.isNotEmpty) {
          final normalized = CourseMatcherService.normalizeProfName(primaryCoord);
          final email = CourseMatcherService.facultyEmails[normalized] ??
              '${normalized.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '.').replaceAll(RegExp(r'\.+'), '.')}@nitgoa.ac.in';
          addProfessor(email, name: normalized, department: branch);
          assignProfessor(code, normalized);
          profsAssigned++;
          continue;
        }
      }
      unassignedCourses.add(c);
    }

    // Only for courses that had NO coordinator in the file, use CourseMatcherService
    if (unassignedCourses.isNotEmpty) {
      final matched = CourseMatcherService.matchCourses(rawCourses: unassignedCourses);
      matched.forEach((cCode, res) {
        addProfessor(res.professorEmail, name: res.professorName, department: targetBranch);
        assignProfessor(cCode, res.displayMapping);
        profsAssigned++;
      });
    }

    return profsAssigned;
  }

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
    for (int i = 0; i < lines.length && i < 10; i++) {
      final cells = lines[i].split(delimiter).map((c) => c.trim().toLowerCase()).toList();
      if (cells.length >= 3 &&
          (cells.any((c) => c.contains('code') || c == 'sub code' || c == 'course_code') ||
           (cells.any((c) => c.contains('course')) && cells.any((c2) => c2.contains('name') || c2.contains('coord') || c2.contains('prof'))))) {
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
    int slIdx = -1;

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (slIdx == -1 && (h.contains('sl') || h.contains('s.no') || h.contains('sr') || h == '#')) {
        slIdx = i;
      } else if (codeIdx == -1 && (h.contains('code') || h == 'sub code' || h == 'course_code')) {
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
    final rawCourses = <Map<String, String>>[];

    String currentSemester = 'VI Sem';
    final detectedFileBranch = detectBranchFromLines(lines);
    final targetBranch = (defaultBranch != null && defaultBranch.trim().isNotEmpty && defaultBranch != 'Auto-detect')
        ? defaultBranch.trim().toUpperCase()
        : (detectedFileBranch.isNotEmpty ? detectedFileBranch : 'ECE');

    for (int i = headerIndex + 1; i < lines.length; i++) {
      final cells = lines[i].split(delimiter).map((c) => c.trim().replaceAll('"', '')).toList();

      // Check if any non-name/non-code cell in this row indicates a semester change (e.g. "BTech, VI Sem")
      for (int c = 0; c < cells.length; c++) {
        if (c == nameIdx || c == codeIdx || c == profIdx || c == slIdx) continue;
        final detected = detectSemesterFromText(cells[c]);
        if (detected != null) {
          currentSemester = detected;
          break;
        }
      }

      if (codeIdx != -1 && codeIdx < cells.length) {
        final code = cells[codeIdx].toUpperCase();
        if (code.isEmpty ||
            code.toLowerCase() == 'code' ||
            code.toLowerCase() == 'course code' ||
            code.toLowerCase().contains('sl') ||
            code.contains('BTECH') ||
            code.contains('MTECH')) {
          continue;
        }

        final name = (nameIdx != -1 && nameIdx < cells.length && cells[nameIdx].isNotEmpty)
            ? cells[nameIdx]
            : 'Course $code';

        final cellBranch = (branchIdx != -1 && branchIdx < cells.length) ? cells[branchIdx] : null;
        final branch = resolveCourseBranch(code, cellBranch: cellBranch, fallbackBranch: targetBranch);

        final sem = (semIdx != -1 && semIdx < cells.length && cells[semIdx].isNotEmpty)
            ? (detectSemesterFromText(cells[semIdx]) ?? cells[semIdx])
            : currentSemester;

        final type = (typeIdx != -1 && typeIdx < cells.length && cells[typeIdx].isNotEmpty)
            ? cells[typeIdx]
            : 'Theory';

        addCourse(name, code, branch: branch, semester: sem, type: type);
        coursesAdded++;

        final profValue = (profIdx != -1 && profIdx < cells.length) ? cells[profIdx].trim() : '';
        rawCourses.add({
          'code': code,
          'name': name,
          'branch': branch,
          'semester': sem,
          'type': type,
          'coordinator': profValue,
        });
      }
    }

    final profsAdded = assignImportedFaculty(rawCourses, targetBranch);
    notifyListeners();
    return {'courses': coursesAdded, 'professors': profsAdded};
  }

  static int _colLetterToIndex(String ref) {
    final letters = ref.replaceAll(RegExp(r'[^A-Z]'), '');
    int index = 0;
    for (int i = 0; i < letters.length; i++) {
      index = index * 26 + (letters.codeUnitAt(i) - 64);
    }
    return index - 1;
  }

  static List<List<String>> extractRowsFromBytes(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Check for sharedStrings
      final sharedStrings = <String>[];
      final sstFile = archive.findFile('xl/sharedStrings.xml');
      if (sstFile != null) {
        final sstXml = XmlDocument.parse(utf8.decode(sstFile.content as List<int>));
        for (final si in sstXml.findAllElements('si')) {
          sharedStrings.add(si.findAllElements('t').map((e) => e.innerText).join());
        }
      }

      // 2. Find sheet
      ArchiveFile? sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
      if (sheetFile == null) {
        for (final f in archive) {
          if (f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml')) {
            sheetFile = f;
            break;
          }
        }
      }

      if (sheetFile != null) {
        final sheetXml = XmlDocument.parse(utf8.decode(sheetFile.content as List<int>));
        final rowsList = <List<String>>[];

        for (final rowElem in sheetXml.findAllElements('row')) {
          final Map<int, String> colMap = {};
          int maxCol = -1;

          for (final c in rowElem.findElements('c')) {
            final ref = c.getAttribute('r') ?? '';
            final colIdx = _colLetterToIndex(ref);
            if (colIdx < 0) continue;
            if (colIdx > maxCol) maxCol = colIdx;

            final type = c.getAttribute('t');
            String value = '';

            final isElem = c.findElements('is').firstOrNull;
            if (isElem != null) {
              value = isElem.findElements('t').firstOrNull?.innerText ?? '';
            } else {
              final vElem = c.findElements('v').firstOrNull;
              if (vElem != null) {
                final rawVal = vElem.innerText.trim();
                if (type == 's') {
                  final idx = int.tryParse(rawVal) ?? -1;
                  if (idx >= 0 && idx < sharedStrings.length) {
                    value = sharedStrings[idx];
                  }
                } else {
                  value = rawVal;
                }
              }
            }
            colMap[colIdx] = value.trim();
          }

          if (maxCol >= 0) {
            rowsList.add(List<String>.generate(maxCol + 1, (i) => colMap[i] ?? ''));
          }
        }

        if (rowsList.isNotEmpty) return rowsList;
      }
    } catch (_) {
      // Fallback below
    }

    // Fallback: standard package:excel
    try {
      final excel = Excel.decodeBytes(bytes);
      final fallbackRows = <List<String>>[];
      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null) continue;
        for (final row in sheet.rows) {
          fallbackRows.add(row.map((cell) => cell?.value?.toString().trim() ?? '').toList());
        }
      }
      return fallbackRows;
    } catch (_) {
      return [];
    }
  }

  Map<String, int> importExcelBytes(List<int> bytes, {String? defaultBranch, String? fileName}) {
    final rows = extractRowsFromBytes(bytes);
    if (rows.isEmpty) return {'courses': 0, 'professors': 0};

    int coursesAdded = 0;

    int headerIdx = -1;
    List<String> headers = [];
    for (int r = 0; r < rows.length && r < 10; r++) {
      final line = rows[r].map((c) => c.toLowerCase()).toList();
      if (line.length >= 3 && line.any((c) => c.contains('code') || (c.contains('course') && line.any((c2) => c2.contains('name') || c2.contains('coord'))))) {
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
    int slIdx = -1;

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (slIdx == -1 && (h.contains('sl') || h.contains('s.no') || h.contains('sr') || h == '#')) {
        slIdx = i;
      } else if (codeIdx == -1 && (h.contains('code') || h.contains('sub code') || h.contains('course_code'))) {
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

    final rawCourses = <Map<String, String>>[];
    String currentSemester = 'VI Sem';

    final detectedFileBranch = detectBranchFromLines(rows.take(15).map((r) => r.join(' ')));
    String targetBranch = (defaultBranch != null && defaultBranch.trim().isNotEmpty && defaultBranch != 'Auto-detect')
        ? defaultBranch.trim().toUpperCase()
        : (detectedFileBranch.isNotEmpty ? detectedFileBranch : '');

    if (targetBranch.isEmpty && fileName != null) {
      final fLower = fileName.toLowerCase();
      if (fLower.contains('eee') || fLower.contains('electrical')) {
        targetBranch = 'EEE';
      } else if (fLower.contains('ece') || fLower.contains('electronics')) {
        targetBranch = 'ECE';
      } else if (fLower.contains('cse') || fLower.contains('computer')) {
        targetBranch = 'CSE';
      } else if (fLower.contains('mechanical') || fLower.contains('mce') || fLower.contains('me')) {
        targetBranch = 'MCE';
      } else if (fLower.contains('civil') || fLower.contains('cve') || fLower.contains('ce')) {
        targetBranch = 'CVE';
      }
    }
    if (targetBranch.isEmpty) {
      targetBranch = 'ECE';
    }

    for (int r = headerIdx + 1; r < rows.length; r++) {
      final cells = rows[r];

      // Check if any non-name/non-code cell in this row indicates a semester change (e.g. "BTech, VI Sem")
      for (int c = 0; c < cells.length; c++) {
        if (c == nameIdx || c == codeIdx || c == profIdx || c == slIdx) continue;
        final detected = detectSemesterFromText(cells[c]);
        if (detected != null) {
          currentSemester = detected;
          break;
        }
      }

      if (codeIdx != -1 && codeIdx < cells.length) {
        final code = cells[codeIdx].toUpperCase();
        if (code.isEmpty ||
            code.toLowerCase() == 'code' ||
            code.toLowerCase() == 'course code' ||
            code.toLowerCase().contains('sl') ||
            code == 'SL. NO' ||
            code.contains('BTECH') ||
            code.contains('MTECH')) {
          continue;
        }

        final name = (nameIdx != -1 && nameIdx < cells.length && cells[nameIdx].isNotEmpty)
            ? cells[nameIdx]
            : 'Course $code';

        final cellBranch = (branchIdx != -1 && branchIdx < cells.length && cells[branchIdx].isNotEmpty && !cells[branchIdx].toLowerCase().contains('sem'))
            ? cells[branchIdx]
            : null;
        final branch = resolveCourseBranch(code, cellBranch: cellBranch, fallbackBranch: targetBranch);

        final sem = (semIdx != -1 && semIdx < cells.length && cells[semIdx].isNotEmpty && detectSemesterFromText(cells[semIdx]) != null)
            ? detectSemesterFromText(cells[semIdx])!
            : currentSemester;

        final type = (typeIdx != -1 && typeIdx < cells.length && cells[typeIdx].isNotEmpty)
            ? cells[typeIdx]
            : 'Theory';

        addCourse(name, code, branch: branch, semester: sem, type: type);
        coursesAdded++;

        final profValue = (profIdx != -1 && profIdx < cells.length) ? cells[profIdx].trim() : '';
        rawCourses.add({
          'code': code,
          'name': name,
          'branch': branch,
          'semester': sem,
          'type': type,
          'coordinator': profValue,
        });
      }
    }

    final profsAdded = assignImportedFaculty(rawCourses, targetBranch);
    notifyListeners();
    return {'courses': coursesAdded, 'professors': profsAdded};
  }

  // ═══════════════════════════════════════════════════════════
  // 8. LOCAL JSON PERSISTENCE (Survives Restarts Until DB Connected)
  // ═══════════════════════════════════════════════════════════
  bool get isLoadingFromStorage => _isLoadingFromStorage;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_isLoadingFromStorage && !_isSeeding) {
      _persist();
    }
  }

  void _persist() {
    LocalStorageService.saveState(toJson());
  }

  Map<String, dynamic> toJson() {
    return {
      'courses': _courses,
      'professors': _professors,
      'crs': _crs,
      'mappings': _mappings,
      'students': _students,
      'attendanceSessions': _attendanceSessions.map((s) {
        return {
          ...s,
          'timestamp': (s['timestamp'] is DateTime)
              ? (s['timestamp'] as DateTime).toIso8601String()
              : s['timestamp']?.toString(),
          'presentRolls': List<String>.from(s['presentRolls'] as Iterable? ?? []),
          'absentRolls': List<String>.from(s['absentRolls'] as Iterable? ?? []),
        };
      }).toList(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    if (json['courses'] is List) {
      _courses.clear();
      for (final c in json['courses'] as List) {
        if (c is Map) {
          _courses.add(Map<String, String>.from(c.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))));
        }
      }
    }

    if (json['professors'] is List) {
      _professors.clear();
      for (final p in json['professors'] as List) {
        if (p is Map) {
          _professors.add(Map<String, String>.from(p.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))));
        }
      }
    }

    if (json['crs'] is List) {
      _crs.clear();
      for (final cr in json['crs'] as List) {
        if (cr is Map) {
          _crs.add(Map<String, String>.from(cr.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))));
        }
      }
    }

    if (json['mappings'] is Map) {
      _mappings.clear();
      for (final entry in (json['mappings'] as Map).entries) {
        _mappings[entry.key.toString().toUpperCase()] = entry.value?.toString() ?? '';
      }
    }

    if (json['students'] is List) {
      _students.clear();
      for (final st in json['students'] as List) {
        if (st is Map) {
          _students.add(Map<String, String>.from(st.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))));
        }
      }
    }

    if (json['attendanceSessions'] is List) {
      _attendanceSessions.clear();
      for (final s in json['attendanceSessions'] as List) {
        if (s is Map) {
          final present = List<String>.from(s['presentRolls'] as Iterable? ?? []);
          final absent = List<String>.from(s['absentRolls'] as Iterable? ?? []);
          final tsStr = s['timestamp']?.toString();
          final ts = tsStr != null ? DateTime.tryParse(tsStr) ?? DateTime.now() : DateTime.now();

          _attendanceSessions.add({
            'id': s['id']?.toString() ?? '',
            'courseCode': s['courseCode']?.toString() ?? '',
            'date': s['date']?.toString() ?? '',
            'lectureNumber': int.tryParse(s['lectureNumber']?.toString() ?? '1') ?? 1,
            'markedBy': s['markedBy']?.toString() ?? '',
            'markedByName': s['markedByName']?.toString() ?? '',
            'presentRolls': present,
            'absentRolls': absent,
            'totalStudents': int.tryParse(s['totalStudents']?.toString() ?? '${present.length + absent.length}') ?? (present.length + absent.length),
            'timestamp': ts,
          });
        }
      }
    }
  }

  Future<void> loadFromStorage() async {
    if (_loadFuture != null) {
      await _loadFuture;
      return;
    }
    _loadFuture = _performLoadFromStorage();
    await _loadFuture;
  }

  Future<void> _performLoadFromStorage() async {
    _isLoadingFromStorage = true;
    try {
      final savedData = await LocalStorageService.loadState();
      if (savedData != null && (savedData['courses'] is List && (savedData['courses'] as List).isNotEmpty)) {
        fromJson(savedData);
        super.notifyListeners();
      } else {
        // Persist initial state
        await LocalStorageService.saveState(toJson());
      }
    } catch (e) {
      debugPrint('Error loading saved attendance state: $e');
    } finally {
      _isLoadingFromStorage = false;
      _loadFuture = null;
    }
  }

  Future<void> saveToStorage() async {
    await LocalStorageService.saveState(toJson());
  }

  Future<void> restoreDefaults() async {
    await LocalStorageService.clearStorage();
    _isSeeding = true;
    seedDefaultData();
    _isSeeding = false;
    await LocalStorageService.saveState(toJson());
    super.notifyListeners();
  }

  String exportJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  Future<bool> importJsonString(String jsonContent) async {
    try {
      final decoded = jsonDecode(jsonContent);
      if (decoded is Map<String, dynamic>) {
        fromJson(decoded);
        _persist();
        super.notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
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

    // ── 1. ECE COURSES (Semester-wise) ──
    // BTech IV Semester
    _courses.addAll([
      {'code': 'EC250', 'name': 'Numerical Methods for ECE', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EC251', 'name': 'Analog Electronics', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EC252', 'name': 'Principle of Communication Systems', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EC253', 'name': 'Sensor Technologies', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EC254', 'name': 'Semiconductor Devices', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'IE250', 'name': 'Innovation & Entrepreneurship', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'EC255', 'name': 'Analog Electronics Laboratory', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Practical'},
      {'code': 'EC256', 'name': 'Communication Systems Laboratory', 'branch': 'ECE', 'semester': 'IV Sem', 'type': 'Practical'},
    ]);

    // BTech VI Semester (Official NIT Goa Timetable)
    _courses.addAll([
      {'code': 'HS350', 'name': 'Industrial Economics', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'ES300', 'name': 'Environmental Studies', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'MLC'},
      {'code': 'EC350', 'name': 'Digital Communication', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'EC351', 'name': 'Principles of Antenna and Measurements', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'EC352', 'name': 'VLSI Circuit Design', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'EC520', 'name': 'Digital System Design Using FPGA (Elective)', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'CS901', 'name': 'Object Oriented Programming (Open Elective)', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'OE'},
      {'code': 'EC350M', 'name': 'Fundamentals of Communication System (Minor)', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'EC353', 'name': 'Digital Communication Laboratory', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Practical'},
      {'code': 'EC354', 'name': 'High Frequency Laboratory', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Practical'},
      {'code': 'EC355', 'name': 'VLSI Circuit Design Laboratory', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Practical'},
      {'code': 'EC356', 'name': 'Seminar', 'branch': 'ECE', 'semester': 'VI Sem', 'type': 'Seminar'},
    ]);

    // BTech VIII Semester
    _courses.addAll([
      {'code': 'HU401', 'name': 'Professional Communication-II and Language Lab', 'branch': 'ECE', 'semester': 'VIII Sem', 'type': 'Theory'},
      {'code': 'EC405', 'name': 'Digital System Design', 'branch': 'ECE', 'semester': 'VIII Sem', 'type': 'Theory'},
      {'code': 'EC424', 'name': 'Low-Power VLSI Circuit Design', 'branch': 'ECE', 'semester': 'VIII Sem', 'type': 'Theory'},
      {'code': 'EC404', 'name': 'Electronic Instrumentation', 'branch': 'ECE', 'semester': 'VIII Sem', 'type': 'Theory'},
      {'code': 'CS522', 'name': 'Artificial Intelligence', 'branch': 'ECE', 'semester': 'VIII Sem', 'type': 'Theory'},
      {'code': 'EC499', 'name': 'Major Project', 'branch': 'ECE', 'semester': 'VIII Sem', 'type': 'Project'},
      {'code': 'EC450M', 'name': 'Practical Applications of Microcontrollers (Minor)', 'branch': 'ECE', 'semester': 'VIII Sem', 'type': 'Theory'},
    ]);

    // M.Tech II Semester (ECE)
    _courses.addAll([
      {'code': 'EC650', 'name': 'VLSI Testing and Testability', 'branch': 'ECE', 'semester': 'M.Tech', 'type': 'Theory'},
      {'code': 'EC651', 'name': 'VLSI Technology', 'branch': 'ECE', 'semester': 'M.Tech', 'type': 'Theory'},
      {'code': 'EC802', 'name': 'Digital Design using FPGA', 'branch': 'ECE', 'semester': 'M.Tech', 'type': 'Theory'},
      {'code': 'EC810', 'name': 'Low Power VLSI Design', 'branch': 'ECE', 'semester': 'M.Tech', 'type': 'Theory'},
      {'code': 'EC804', 'name': 'Mixed Signal Design', 'branch': 'ECE', 'semester': 'M.Tech', 'type': 'Theory'},
      {'code': 'EC652', 'name': 'System Design Laboratory', 'branch': 'ECE', 'semester': 'M.Tech', 'type': 'Practical'},
      {'code': 'EC653', 'name': 'VIVA-VOCE', 'branch': 'ECE', 'semester': 'M.Tech', 'type': 'Practical'},
      {'code': 'HU650', 'name': 'Communication Skills and Technical Writing', 'branch': 'ECE', 'semester': 'M.Tech', 'type': 'Theory'},
    ]);

    // M.Tech IV Semester
    _courses.add({'code': 'EC750', 'name': 'Major Project - II', 'branch': 'ECE', 'semester': 'M.Tech', 'type': 'Project'});

    // Open Elective
    _courses.add({'code': 'EC903', 'name': 'Introduction to Signal Processing', 'branch': 'ECE', 'semester': 'Open Elective', 'type': 'Open Elective'});

    // ── 2. CSE COURSES (Semester-wise) ──
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

    // ── 4. MCE COURSES (Mechanical) ──
    _courses.addAll([
      {'code': 'ME250', 'name': 'Fluid Mechanics & Machinery', 'branch': 'MCE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'ME251', 'name': 'Kinematics of Machinery', 'branch': 'MCE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'ME252', 'name': 'Manufacturing Technology', 'branch': 'MCE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'ME253', 'name': 'Fluid Mechanics Lab', 'branch': 'MCE', 'semester': 'IV Sem', 'type': 'Practical'},
      {'code': 'ME350', 'name': 'Heat & Mass Transfer', 'branch': 'MCE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'ME351', 'name': 'Design of Machine Elements', 'branch': 'MCE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'ME401', 'name': 'Automobile Engineering', 'branch': 'MCE', 'semester': 'VIII Sem', 'type': 'Theory'},
    ]);

    // ── 5. CVE COURSES (Civil) ──
    _courses.addAll([
      {'code': 'CE250', 'name': 'Structural Analysis-I', 'branch': 'CVE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'CE251', 'name': 'Geotechnical Engineering', 'branch': 'CVE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'CE252', 'name': 'Surveying & Geomatics', 'branch': 'CVE', 'semester': 'IV Sem', 'type': 'Theory'},
      {'code': 'CE253', 'name': 'Geotechnical Engineering Lab', 'branch': 'CVE', 'semester': 'IV Sem', 'type': 'Practical'},
      {'code': 'CE350', 'name': 'Design of Concrete Structures', 'branch': 'CVE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'CE351', 'name': 'Transportation Engineering', 'branch': 'CVE', 'semester': 'VI Sem', 'type': 'Theory'},
      {'code': 'CE401', 'name': 'Environmental Engineering', 'branch': 'CVE', 'semester': 'VIII Sem', 'type': 'Theory'},
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

      // MCE Faculty
      {'email': 'shiba.sundar@nitgoa.ac.in', 'name': 'Dr. Shiba Sundar Mahapatra', 'department': 'MCE'},
      {'email': 'ravi.raghav@nitgoa.ac.in', 'name': 'Dr. Ravi Raghav', 'department': 'MCE'},
      {'email': 'prashant.kumar@nitgoa.ac.in', 'name': 'Dr. Prashant Kumar', 'department': 'MCE'},

      // CVE Faculty
      {'email': 'sarath.babu@nitgoa.ac.in', 'name': 'Dr. Sarath Babu', 'department': 'CVE'},
      {'email': 'rajesh.prabhu@nitgoa.ac.in', 'name': 'Dr. Rajesh Prabhu Gaonkar', 'department': 'CVE'},

      // General / Humanities
      {'email': 'sunil.kumar@nitgoa.ac.in', 'name': 'Dr. Sunil Kumar A', 'department': 'Humanities'},
      {'email': 'velavan.k@nitgoa.ac.in', 'name': 'Dr. Velavan K', 'department': 'Humanities'},
      {'email': 'sarani.ghosal@nitgoa.ac.in', 'name': 'Dr. Sarani Ghosal Mondal', 'department': 'Humanities'},
      {'email': 'rinu.koshy@nitgoa.ac.in', 'name': 'Dr. Rinu Koshy', 'department': 'Humanities'},
      {'email': 'spatidar@nitgoa.ac.in', 'name': 'Dr. Shivnarayan Patidar', 'department': 'ECE'},
      {'email': 'prashanth.gr@nitgoa.ac.in', 'name': 'Dr. Prashanth G.R', 'department': 'ECE'},
    ]);

    // ── SEED CLASS REPRESENTATIVES FOR ALL BRANCHES & SEMESTERS ──
    _crs.addAll([
      {'email': 'cr.ece3@nitgoa.ac.in', 'name': 'Rahul Patil (ECE CR)', 'branch': 'ECE', 'semester': 'VI Sem'},
      {'email': 'cr.ece6@nitgoa.ac.in', 'name': 'Rahul Patil (ECE CR)', 'branch': 'ECE', 'semester': 'VI Sem'},
      {'email': 'cr.ece4@nitgoa.ac.in', 'name': 'Rahul Patil (ECE CR)', 'branch': 'ECE', 'semester': 'IV Sem'},
      {'email': 'cr.cse4@nitgoa.ac.in', 'name': 'Aarav Sharma (CSE CR)', 'branch': 'CSE', 'semester': 'IV Sem'},
      {'email': 'cr.eee4@nitgoa.ac.in', 'name': 'Aditya Verma (EEE CR)', 'branch': 'EEE', 'semester': 'IV Sem'},
      {'email': 'cr.mce4@nitgoa.ac.in', 'name': 'Rohan Kulkarni (MCE CR)', 'branch': 'MCE', 'semester': 'IV Sem'},
      {'email': 'cr.cve4@nitgoa.ac.in', 'name': 'Siddharth Pai (CVE CR)', 'branch': 'CVE', 'semester': 'IV Sem'},
    ]);

    // ── SEED COURSE ↔ PROFESSOR MAPPINGS (Name Only) ──
    // ECE IV Sem Mappings
    _mappings['EC250'] = 'Dr. Najiya V K';
    _mappings['EC251'] = 'Dr. Lokesh Kumar B';
    _mappings['EC252'] = 'Dr. Pragati Patel';
    _mappings['EC253'] = 'Dr. E. Mallikarjun';
    _mappings['EC254'] = 'Dr. Lalat Indu Giri';
    _mappings['IE250'] = 'Dr. Sunil Kumar A';
    _mappings['EC255'] = 'Dr. Lokesh Kumar B';
    _mappings['EC256'] = 'Dr. Pragati Patel';

    // ECE VI Sem Mappings (All 12 courses matching timetable)
    _mappings['HS350'] = 'Dr. Sunil Kumar A';
    _mappings['ES300'] = 'Dr. Velavan K';
    _mappings['EC350'] = 'Dr. Trilochan Panigrahi';
    _mappings['EC351'] = 'Dr. Anirban Chatterjee';
    _mappings['EC352'] = 'Dr. Nithin Kumar Y.B.';
    _mappings['EC520'] = 'Dr. T. Veerakumar';
    _mappings['CS901'] = 'Dr. Damodar Reddy';
    _mappings['EC350M'] = 'Dr. Anirban Chatterjee';
    _mappings['EC353'] = 'Dr. Trilochan Panigrahi';
    _mappings['EC354'] = 'Dr. Shivnarayan Patidar';
    _mappings['EC355'] = 'Dr. Nithin Kumar Y.B.';
    _mappings['EC356'] = 'Dr. Lalat Indu Giri';

    // ECE VIII Sem Mappings
    _mappings['HU401'] = 'Dr. Sarani Ghosal Mondal';
    _mappings['EC405'] = 'Dr. Vasantha M.H';
    _mappings['EC424'] = 'Ishaan Bhate';
    _mappings['EC404'] = 'Dr. E. Mallikarjun';
    _mappings['CS522'] = 'Dr. Shivnarayan Patidar';
    _mappings['EC499'] = 'Dr. Prashanth G.R';
    _mappings['EC450M'] = 'Dr. Prashanth G.R';

    // ECE M.Tech Mappings
    _mappings['EC650'] = 'Dr. Pravati Swain';
    _mappings['EC651'] = 'Dr. Lalat Indu Giri';
    _mappings['EC802'] = 'Dr. T. Veerakumar';
    _mappings['EC810'] = 'Dr. Vasantha M.H';
    _mappings['EC804'] = 'Dr. Pravati Swain';
    _mappings['EC652'] = 'Ishaan Bhate';
    _mappings['EC653'] = 'Dr. Rinu Koshy';
    _mappings['HU650'] = 'Dr. Rinu Koshy';
    _mappings['EC750'] = 'Dr. B. R. Chandavarkar';
    _mappings['EC903'] = 'Dr. Venkat Subba Reddy';

    // CSE Mappings
    _mappings['CS250'] = 'Dr. Pravati Swain';
    _mappings['CS251'] = 'Dr. Damodar Reddy';
    _mappings['CS252'] = 'Dr. Venkat Subba Reddy';
    _mappings['CS253'] = 'Dr. B. R. Chandavarkar';
    _mappings['CS254'] = 'Dr. Venkat Subba Reddy';
    _mappings['CS350'] = 'Dr. Damodar Reddy';
    _mappings['CS351'] = 'Dr. Pravati Swain';
    _mappings['CS352'] = 'Dr. B. R. Chandavarkar';

    // EEE Mappings
    _mappings['EE250'] = 'Dr. Sreeraj E.S.';
    _mappings['EE251'] = 'Dr. Amresh Kumar';
    _mappings['EE252'] = 'Dr. C. Vyjayanthi';
    _mappings['EE253'] = 'Dr. Amresh Kumar';
    _mappings['EE350'] = 'Dr. C. Vyjayanthi';
    _mappings['EE351'] = 'Dr. Sreeraj E.S.';
    _mappings['EE401'] = 'Dr. Amresh Kumar';

    // ME Mappings
    _mappings['ME250'] = 'Dr. Shiba Sundar Mahapatra';
    _mappings['ME251'] = 'Dr. Ravi Raghav';
    _mappings['ME252'] = 'Dr. Prashant Kumar';
    _mappings['ME253'] = 'Dr. Shiba Sundar Mahapatra';
    _mappings['ME350'] = 'Dr. Ravi Raghav';
    _mappings['ME351'] = 'Dr. Prashant Kumar';

    // CE Mappings
    _mappings['CE250'] = 'Dr. Sarath Babu';
    _mappings['CE251'] = 'Dr. Rajesh Prabhu Gaonkar';
    _mappings['CE252'] = 'Dr. Sarath Babu';
    _mappings['CE253'] = 'Dr. Rajesh Prabhu Gaonkar';
    _mappings['CE350'] = 'Dr. Sarath Babu';

    // ── SEED REALISTIC STUDENTS FOR BOTH VI SEM AND IV SEM ──
    _students.addAll([
      {'roll': '22ECE001', 'name': 'Rahul Patil', 'branch': 'ECE', 'semester': 'VI Sem', 'email': 'rahul.patil@nitgoa.ac.in'},
      {'roll': '22ECE045', 'name': 'Arjun Desai', 'branch': 'ECE', 'semester': 'VI Sem', 'email': 'arjun.desai@nitgoa.ac.in'},
      {'roll': '22ECE032', 'name': 'Sneha Iyer', 'branch': 'ECE', 'semester': 'VI Sem', 'email': 'sneha.iyer@nitgoa.ac.in'},
      {'roll': '22ECE018', 'name': 'Karan Mehta', 'branch': 'ECE', 'semester': 'VI Sem', 'email': 'karan.mehta@nitgoa.ac.in'},
      {'roll': '22ECE050', 'name': 'Neha Kulkarni', 'branch': 'ECE', 'semester': 'VI Sem', 'email': 'neha.kulkarni@nitgoa.ac.in'},
      {'roll': '22CSE010', 'name': 'Aarav Sharma', 'branch': 'CSE', 'semester': 'VI Sem', 'email': 'aarav.sharma@nitgoa.ac.in'},
      {'roll': '22EEE005', 'name': 'Aditya Verma', 'branch': 'EEE', 'semester': 'VI Sem', 'email': 'aditya.verma@nitgoa.ac.in'},
      {'roll': '22MCE007', 'name': 'Rohan Kulkarni', 'branch': 'MCE', 'semester': 'VI Sem', 'email': 'rohan.kulkarni@nitgoa.ac.in'},
      {'roll': '22CVE003', 'name': 'Siddharth Pai', 'branch': 'CVE', 'semester': 'VI Sem', 'email': 'siddharth.pai@nitgoa.ac.in'},
    ]);

    final branchCodes = ['ECE', 'CSE', 'EEE', 'MCE', 'CVE'];
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

    // ── SEED INITIAL ATTENDANCE SESSIONS (VI Sem and IV Sem) ──
    _attendanceSessions.addAll([
      {
        'id': 'att_EC350_2026-03-24_1',
        'courseCode': 'EC350',
        'date': '2026-03-24',
        'lectureNumber': 1,
        'markedBy': 'trilochan.panigrahi@nitgoa.ac.in',
        'markedByName': 'Dr. Trilochan Panigrahi',
        'presentRolls': <String>['22ECE001', '22ECE045', '22ECE032', '22ECE050'],
        'absentRolls': <String>['22ECE018'],
        'totalStudents': 5,
        'timestamp': DateTime.now().subtract(const Duration(days: 3)),
      },
      {
        'id': 'att_HS350_2026-03-25_1',
        'courseCode': 'HS350',
        'date': '2026-03-25',
        'lectureNumber': 1,
        'markedBy': 'sunil.kumar@nitgoa.ac.in',
        'markedByName': 'Dr. Sunil Kumar A',
        'presentRolls': <String>['22ECE001', '22ECE045', '22ECE032', '22ECE018', '22ECE050'],
        'absentRolls': <String>[],
        'totalStudents': 5,
        'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      },
      {
        'id': 'att_EC250_2026-03-24_1',
        'courseCode': 'EC250',
        'date': '2026-03-24',
        'lectureNumber': 1,
        'markedBy': 'najiya.vk@nitgoa.ac.in',
        'markedByName': 'Dr. Najiya V K',
        'presentRolls': <String>['24ECE001', '24ECE002', '24ECE003', '24ECE004', '24ECE005', '24ECE006', '24ECE007'],
        'absentRolls': <String>['24ECE008'],
        'totalStudents': 8,
        'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      },
    ]);

    notifyListeners();
  }
}
