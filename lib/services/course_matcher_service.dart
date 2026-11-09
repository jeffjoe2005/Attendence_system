/// Service to resolve course-to-professor assignments with strict capacity constraints:
/// 1. Maximum 2-3 courses per professor.
/// 2. Exactly 1 professor per course (no unparsed shared strings like "Prof A & Prof B").
/// 3. Preserves natural Theory + Lab pairings and original coordinators wherever possible.
/// 4. Reassigns overflow or unassigned courses to department faculty by domain affinity (CSE -> CSE, ECE -> ECE, etc.).
class CourseMatcherService {
  CourseMatcherService._();

  static const int maxCoursesPerProf = 3;

  /// Known NIT Goa faculty email directory across all branches
  static final Map<String, String> facultyEmails = {
    // ── ECE Faculty ──
    'Dr. Najiya V K': 'najiya.vk@nitgoa.ac.in',
    'Dr. Lokesh Kumar B': 'lokesh.kumar@nitgoa.ac.in',
    'Dr. Pragati Patel': 'pragati.patel@nitgoa.ac.in',
    'Dr. E. Mallikarjun': 'e.mallikarjun@nitgoa.ac.in',
    'Dr. Lalat Indu Giri': 'lalat.indu@nitgoa.ac.in',
    'Dr. Trilochan Panigrahi': 'trilochan.panigrahi@nitgoa.ac.in',
    'Dr. Anirban Chatterjee': 'anirban.chatterjee@nitgoa.ac.in',
    'Dr. Nithin Kumar Y.B.': 'nithin.kumar@nitgoa.ac.in',
    'Dr. T. Veerakumar': 't.veerakumar@nitgoa.ac.in',
    'Dr. Vasantha M.H': 'vasantha.mh@nitgoa.ac.in',
    'Dr. Shivnarayan Patidar': 'spatidar@nitgoa.ac.in',
    'Ishaan Bhate': 'ishaan.bhate@nitgoa.ac.in',
    'Dr. Prashanth G.R': 'prashanth.gr@nitgoa.ac.in',

    // ── CSE Faculty ──
    'Dr. Pravati Swain': 'pravati.swain@nitgoa.ac.in',
    'Dr. Damodar Reddy': 'damodar.reddy@nitgoa.ac.in',
    'Dr. Keshavamurthy B N': 'keshavamurthy@nitgoa.ac.in',
    'Dr. B. R. Chandavarkar': 'keshavamurthy@nitgoa.ac.in',
    'Dr. Venkat Subba Reddy': 'venkat.subba@nitgoa.ac.in',
    'Dr. Chirag N Modi': 'dr.chirag.n.modi@nitgoa.ac.in',
    'Dr. Veena Thenkanidiyoor': 'dr.veena.thenkanidiyoor@nitgoa.ac.in',
    'Dr. Meenakshi Panda': 'dr.meenakshi.panda@nitgoa.ac.in',
    'Dr. Venkatnareshbabu Kuppili': 'dr.venkatnareshbabu.kuppili@nitgoa.ac.in',
    'Mrs Sreedivya': 'mrs.sreedivya@nitgoa.ac.in',
    'Contract Faculty 2': 'contract.faculty.2@nitgoa.ac.in',
    'Contract Faculty 4': 'contract.faculty.4@nitgoa.ac.in',

    // ── EEE Faculty ──
    'Dr. Suresh Mikkili': 'suresh.mikkili@nitgoa.ac.in',
    'Dr. Soumitra Das': 'soumitra.das@nitgoa.ac.in',
    'Dr. Amol D. Rahulkar': 'amol.rahulkar@nitgoa.ac.in',
    'Dr. Sandeep Chawrasia': 'sandeep.chawrasia@nitgoa.ac.in',
    'Dr. Amritansh Sagar': 'amritansh.sagar@nitgoa.ac.in',
    'Dr. Shiva Kumar Reddy': 'shiva.reddy@nitgoa.ac.in',
    'Dr. Mahi Teja Talluri': 'mahiteja.talluri@nitgoa.ac.in',
    'Dr. Anudevi Samuel': 'anudevi.samuel@nitgoa.ac.in',
    'Ms. Shefali Painuli': 'shefali.painuli@nitgoa.ac.in',
    'Dr. Ankeshwarapu Sunil': 'ankeshwarapu.sunil@nitgoa.ac.in',
    'Dr. C. Vyjayanthi': 'vyjayanthi@nitgoa.ac.in',
    'Dr. Sreeraj E.S.': 'sreeraj@nitgoa.ac.in',
    'Dr. Sreeraj E. S.': 'sreeraj@nitgoa.ac.in',
    'Dr. Amresh Kumar': 'amresh.kumar@nitgoa.ac.in',
    'Dr. Mini S.': 'mini@nitgoa.ac.in',

    // ── ME / MCE Faculty ──
    'Dr. Shiba Sundar Mahapatra': 'shiba.sundar@nitgoa.ac.in',
    'Dr. Ravi Raghav': 'ravi.raghav@nitgoa.ac.in',
    'Dr. Prashant Kumar': 'prashant.kumar@nitgoa.ac.in',

    // ── CE / CVE Faculty ──
    'Dr. Sarath Babu': 'sarath.babu@nitgoa.ac.in',
    'Dr. Rajesh Prabhu Gaonkar': 'rajesh.prabhu@nitgoa.ac.in',

    // ── Humanities & Applied Sciences ──
    'Dr. Sunil Kumar A': 'sunil.kumar@nitgoa.ac.in',
    'Dr. Velavan K': 'velavan.k@nitgoa.ac.in',
    'Dr. Sarani Ghosal Mondal': 'sarani.ghosal@nitgoa.ac.in',
    'Dr. Rinu Koshy': 'rinu.koshy@nitgoa.ac.in',
  };

  /// Department directory mapping professors to their official department
  static final Map<String, String> facultyDepartments = {
    // ECE
    'Dr. Najiya V K': 'ECE',
    'Dr. Lokesh Kumar B': 'ECE',
    'Dr. Pragati Patel': 'ECE',
    'Dr. E. Mallikarjun': 'ECE',
    'Dr. Lalat Indu Giri': 'ECE',
    'Dr. Trilochan Panigrahi': 'ECE',
    'Dr. Anirban Chatterjee': 'ECE',
    'Dr. Nithin Kumar Y.B.': 'ECE',
    'Dr. T. Veerakumar': 'ECE',
    'Dr. Vasantha M.H': 'ECE',
    'Dr. Shivnarayan Patidar': 'ECE',
    'Ishaan Bhate': 'ECE',
    'Dr. Prashanth G.R': 'ECE',

    // CSE
    'Dr. Pravati Swain': 'CSE',
    'Dr. Damodar Reddy': 'CSE',
    'Dr. Keshavamurthy B N': 'CSE',
    'Dr. B. R. Chandavarkar': 'CSE',
    'Dr. Venkat Subba Reddy': 'CSE',
    'Dr. Chirag N Modi': 'CSE',
    'Dr. Veena Thenkanidiyoor': 'CSE',
    'Dr. Meenakshi Panda': 'CSE',
    'Dr. Venkatnareshbabu Kuppili': 'CSE',
    'Mrs Sreedivya': 'CSE',
    'Contract Faculty 2': 'CSE',
    'Contract Faculty 4': 'CSE',

    // EEE
    'Dr. Suresh Mikkili': 'EEE',
    'Dr. Soumitra Das': 'EEE',
    'Dr. Amol D. Rahulkar': 'EEE',
    'Dr. Sandeep Chawrasia': 'EEE',
    'Dr. Amritansh Sagar': 'EEE',
    'Dr. Shiva Kumar Reddy': 'EEE',
    'Dr. Mahi Teja Talluri': 'EEE',
    'Dr. Anudevi Samuel': 'EEE',
    'Ms. Shefali Painuli': 'EEE',
    'Dr. Ankeshwarapu Sunil': 'EEE',
    'Dr. C. Vyjayanthi': 'EEE',
    'Dr. Sreeraj E.S.': 'EEE',
    'Dr. Sreeraj E. S.': 'EEE',
    'Dr. Amresh Kumar': 'EEE',
    'Dr. Mini S.': 'EEE',

    // MCE
    'Dr. Shiba Sundar Mahapatra': 'MCE',
    'Dr. Ravi Raghav': 'MCE',
    'Dr. Prashant Kumar': 'MCE',

    // CVE
    'Dr. Sarath Babu': 'CVE',
    'Dr. Rajesh Prabhu Gaonkar': 'CVE',

    // Humanities
    'Dr. Sunil Kumar A': 'Humanities',
    'Dr. Velavan K': 'Humanities',
    'Dr. Sarani Ghosal Mondal': 'Humanities',
    'Dr. Rinu Koshy': 'Humanities',
  };

  /// Returns the official department for a given professor name or email
  static String? getDepartmentForFaculty(String nameOrEmail) {
    final clean = normalizeProfName(nameOrEmail);
    if (facultyDepartments.containsKey(clean)) {
      return facultyDepartments[clean];
    }
    final lower = nameOrEmail.trim().toLowerCase();
    for (final entry in facultyEmails.entries) {
      if (entry.value.toLowerCase() == lower || entry.key.toLowerCase() == lower) {
        return facultyDepartments[entry.key];
      }
    }
    return null;
  }

  /// Returns all known faculty names for a specific department
  static List<String> getFacultyForDepartment(String department) {
    final cleanDept = department.trim().toUpperCase();
    final normDept = (cleanDept == 'ME' || cleanDept == 'MCE')
        ? 'MCE'
        : (cleanDept == 'CE' || cleanDept == 'CVE')
            ? 'CVE'
            : cleanDept;

    final list = <String>[];
    facultyDepartments.forEach((name, dept) {
      if (dept.toUpperCase() == normDept && !list.contains(name)) {
        list.add(name);
      }
    });
    return list;
  }

  /// Normalizes variant spellings found in college timetables
  static String normalizeProfName(String name) {
    var clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean == 'Dr. Mallikarjun E' || clean == 'Mallikarjun E') return 'Dr. E. Mallikarjun';
    if (clean == 'Dr. Nithinkumar YB' || clean == 'Nithinkumar YB' || clean == 'Dr. Nithin Kumar YB') return 'Dr. Nithin Kumar Y.B.';
    if (clean == 'Dr. Sreeraj E. S.' || clean == 'Dr. Sreeraj ES' || clean == 'Sreeraj E.S.' || clean == 'Sreeraj E. S.') return 'Dr. Sreeraj E.S.';
    if (clean == 'Dr. Damodar Reddy E' || clean == 'Damodar Reddy E' || clean == 'Dr.Damodar Reddy E') return 'Dr. Damodar Reddy';
    if (clean == 'Dr. Keshavamurthy B N' || clean == 'Keshavamurthy B N' || clean == 'Dr.Keshavamurthy B N') return 'Dr. Keshavamurthy B N';
    if (clean.contains('Dr. Suresh Mikkili')) return 'Dr. Suresh Mikkili';
    if (clean.contains('Dr. Mini S.')) return 'Dr. Mini S.';
    if (clean == 'Dr. Najiya V. K.' || clean == 'Dr. Najiya VK') return 'Dr. Najiya V K';
    if (clean == 'CSE Faculty' || clean == 'CSE dept') return 'Dr. Damodar Reddy';
    return clean;
  }

  /// Checks if two names refer to the same faculty member
  static bool isSameFaculty(String a, String b) {
    final normA = normalizeProfName(a).trim().toLowerCase();
    final normB = normalizeProfName(b).trim().toLowerCase();
    if (normA.isEmpty || normB.isEmpty) return false;
    if (normA == normB) return true;
    if (normA.contains(normB) || normB.contains(normA)) return true;

    // Dr. Keshavamurthy B N is Dr. B. R. Chandavarkar
    if ((normA.contains('keshavamurthy') || normA.contains('chandavarkar')) &&
        (normB.contains('keshavamurthy') || normB.contains('chandavarkar'))) {
      return true;
    }
    // Dr. Damodar Reddy
    if (normA.contains('damodar') && normB.contains('damodar')) {
      return true;
    }
    // Dr. Sreeraj
    if (normA.contains('sreeraj') && normB.contains('sreeraj')) {
      return true;
    }
    // Dr. Mallikarjun
    if (normA.contains('mallikarjun') && normB.contains('mallikarjun')) {
      return true;
    }
    return false;
  }

  /// Splits multi-coordinator strings (e.g. "Dr. Pragati Patel & Dr. E. Mallikarjun")
  static List<String> splitCoordinators(String raw) {
    if (raw.isEmpty) return [];
    final parts = raw.split(RegExp(r'\s*(&|/|,|\band\b)\s*', caseSensitive: false));
    return parts.map(normalizeProfName).where((p) => p.isNotEmpty).toList();
  }

  /// Resolves course-to-professor assignments respecting branch affinity
  static Map<String, CourseAssignmentResult> matchCourses({
    required List<Map<String, String>> rawCourses,
  }) {
    final Map<String, List<String>> profAssigned = {};
    for (final prof in facultyEmails.keys) {
      profAssigned[prof] = [];
    }

    final Map<String, CourseAssignmentResult> results = {};

    // 1. Core theory + lab pair priority definitions across all branches
    final Map<String, String> primaryPreference = {
      // ── ECE ──
      'EC250': 'Dr. Najiya V K',
      'EC251': 'Dr. Lokesh Kumar B',
      'EC255': 'Dr. Lokesh Kumar B',
      'EC252': 'Dr. Pragati Patel',
      'EC256': 'Dr. Pragati Patel',
      'EC253': 'Dr. E. Mallikarjun',
      'EC404': 'Dr. E. Mallikarjun',
      'EC254': 'Dr. Lalat Indu Giri',
      'EC651': 'Dr. Lalat Indu Giri',
      'EC750': 'Dr. Lalat Indu Giri',
      'EC350': 'Dr. Trilochan Panigrahi',
      'EC353': 'Dr. Trilochan Panigrahi',
      'EC499': 'Dr. Trilochan Panigrahi',
      'EC351': 'Dr. Anirban Chatterjee',
      'EC350M': 'Dr. Anirban Chatterjee',
      'EC352': 'Dr. Nithin Kumar Y.B.',
      'EC355': 'Dr. Nithin Kumar Y.B.',
      'EC804': 'Dr. Nithin Kumar Y.B.',
      'EC354': 'Dr. Shivnarayan Patidar',
      'EC356': 'Dr. Lalat Indu Giri',
      'EC405': 'Dr. Vasantha M.H',
      'EC424': 'Dr. Vasantha M.H',
      'EC810': 'Dr. Vasantha M.H',
      'EC652': 'Dr. Vasantha M.H',
      'EC520': 'Dr. T. Veerakumar',
      'EC802': 'Dr. T. Veerakumar',
      'EC903': 'Dr. T. Veerakumar',
      'EC650': 'Dr. Lokesh Kumar B',
      'EC653': 'Dr. E. Mallikarjun',
      'EC450M': 'Dr. Prashanth G.R',

      // ── CSE ──
      'CS250': 'Contract Faculty 4',
      'CS251': 'Contract Faculty 2',
      'CS252': 'Dr. Veena Thenkanidiyoor',
      'CS253': 'Mrs Sreedivya',
      'CS254': 'Dr. Prashanth G.R',
      'CS255': 'Contract Faculty 4',
      'CS256': 'Dr. Prashanth G.R',
      'CS250M': 'Contract Faculty 2',
      'CS350': 'Dr. Damodar Reddy',
      'CS351': 'Dr. Keshavamurthy B N',
      'CS352': 'Dr. Meenakshi Panda',
      'CS520': 'Dr. Pravati Swain',
      'CS353': 'Dr. Keshavamurthy B N',
      'CS354': 'Dr. Meenakshi Panda',
      'CS350M': 'Contract Faculty 4',
      'CS512': 'Dr. Venkatnareshbabu Kuppili',
      'CS529': 'Dr. Chirag N Modi',
      'CS513': 'Mrs Sreedivya',
      'CS532': 'Dr. Meenakshi Panda',
      'CS450M': 'Dr. Venkatnareshbabu Kuppili',
      'CS650': 'Dr. Keshavamurthy B N',
      'CS651': 'Dr. Veena Thenkanidiyoor',
      'CS652': 'Dr. Damodar Reddy',
      'CS653': 'Dr. Keshavamurthy B N',
      'CS654': 'Dr. Damodar Reddy',
      'CS655': 'Dr. Pravati Swain',
      'CS812': 'Dr. Pravati Swain',
      'CS800': 'Dr. Chirag N Modi',
      'CS 950': 'Contract Faculty 4',
      'CS901': 'Dr. Damodar Reddy',
      'CS522': 'Dr. Chirag N Modi',

      // ── EEE ──
      'EE250': 'Dr. Sreeraj E.S.',
      'EE251': 'Dr. Amresh Kumar',
      'EE252': 'Dr. C. Vyjayanthi',
      'EE253': 'Dr. Amresh Kumar',
      'EE350': 'Dr. C. Vyjayanthi',
      'EE351': 'Dr. Sreeraj E.S.',
      'EE401': 'Dr. Suresh Mikkili',

      // ── MCE ──
      'ME250': 'Dr. Shiba Sundar Mahapatra',
      'ME251': 'Dr. Ravi Raghav',
      'ME252': 'Dr. Prashant Kumar',
      'ME253': 'Dr. Shiba Sundar Mahapatra',
      'ME350': 'Dr. Ravi Raghav',
      'ME351': 'Dr. Prashant Kumar',
      'ME401': 'Dr. Shiba Sundar Mahapatra',

      // ── CVE ──
      'CE250': 'Dr. Sarath Babu',
      'CE251': 'Dr. Rajesh Prabhu Gaonkar',
      'CE252': 'Dr. Sarath Babu',
      'CE253': 'Dr. Rajesh Prabhu Gaonkar',
      'CE350': 'Dr. Sarath Babu',
      'CE351': 'Dr. Rajesh Prabhu Gaonkar',
      'CE401': 'Dr. Sarath Babu',

      // ── Humanities & Common ──
      'HS350': 'Dr. Sunil Kumar A',
      'ES300': 'Dr. Velavan K',
      'HU401': 'Dr. Sarani Ghosal Mondal',
      'HU650': 'Dr. Rinu Koshy',
      'HU650*': 'Dr. Rinu Koshy',
      'IE250': 'Dr. Sunil Kumar A',
    };

    // Phase 1: Assign core priority courses directly
    for (final course in rawCourses) {
      final code = (course['code'] ?? '').trim().toUpperCase();
      if (primaryPreference.containsKey(code)) {
        final targetProf = primaryPreference[code]!;
        if ((profAssigned[targetProf]?.length ?? 0) < maxCoursesPerProf) {
          profAssigned.putIfAbsent(targetProf, () => []).add(code);
          results[code] = CourseAssignmentResult(
            courseCode: code,
            courseName: course['name'] ?? '',
            professorName: targetProf,
            professorEmail: facultyEmails[targetProf] ?? '$targetProf@nitgoa.ac.in',
            wasShared: (course['coordinator'] ?? '').contains('&'),
            originalCoordinator: course['coordinator'] ?? '',
          );
        }
      }
    }

    // Phase 2: Resolve shared courses (e.g. EC354, CS353, CS354)
    for (final course in rawCourses) {
      final code = (course['code'] ?? '').trim().toUpperCase();
      if (results.containsKey(code)) continue;

      final rawCoord = course['coordinator'] ?? '';
      final candidates = splitCoordinators(rawCoord);

      if (candidates.length > 1) {
        String? chosenProf;
        for (final cand in candidates) {
          if ((profAssigned[cand]?.length ?? 0) < maxCoursesPerProf) {
            chosenProf = cand;
            break;
          }
        }

        // If all candidates full, pick department specialist
        final branch = course['branch'] ?? 'ECE';
        final deptFaculty = getFacultyForDepartment(branch);
        chosenProf ??= deptFaculty.firstWhere(
          (p) => (profAssigned[p]?.length ?? 0) < maxCoursesPerProf,
          orElse: () => candidates.first,
        );

        profAssigned.putIfAbsent(chosenProf, () => []).add(code);
        results[code] = CourseAssignmentResult(
          courseCode: code,
          courseName: course['name'] ?? '',
          professorName: chosenProf,
          professorEmail: facultyEmails[chosenProf] ?? '$chosenProf@nitgoa.ac.in',
          wasShared: true,
          originalCoordinator: rawCoord,
        );
      }
    }

    // Phase 3: Resolve overloaded or unassigned courses strictly by Department Affinity
    for (final course in rawCourses) {
      final code = (course['code'] ?? '').trim().toUpperCase();
      if (results.containsKey(code)) continue;

      final branch = (course['branch'] != null && course['branch']!.isNotEmpty)
          ? course['branch']!
          : (code.startsWith('CS') ? 'CSE' : code.startsWith('EE') ? 'EEE' : code.startsWith('ME') ? 'MCE' : code.startsWith('CE') ? 'CVE' : 'ECE');

      // 1. Search in the course's department first
      final deptFaculty = getFacultyForDepartment(branch);
      String? assignedProf = deptFaculty.firstWhere(
        (p) => (profAssigned[p]?.length ?? 0) < maxCoursesPerProf,
        orElse: () => '',
      );

      // 2. Fallback to least loaded in the department
      if (assignedProf.isEmpty && deptFaculty.isNotEmpty) {
        deptFaculty.sort((a, b) => (profAssigned[a]?.length ?? 0).compareTo(profAssigned[b]?.length ?? 0));
        assignedProf = deptFaculty.first;
      }

      // 3. Last fallback
      if (assignedProf.isEmpty) {
        assignedProf = facultyEmails.keys.firstWhere(
          (p) => (profAssigned[p]?.length ?? 0) < maxCoursesPerProf,
          orElse: () => 'Dr. Shivnarayan Patidar',
        );
      }

      profAssigned.putIfAbsent(assignedProf, () => []).add(code);
      results[code] = CourseAssignmentResult(
        courseCode: code,
        courseName: course['name'] ?? '',
        professorName: assignedProf,
        professorEmail: facultyEmails[assignedProf] ?? '$assignedProf@nitgoa.ac.in',
        wasShared: false,
        originalCoordinator: course['coordinator'] ?? '',
      );
    }

    return results;
  }
}

class CourseAssignmentResult {
  final String courseCode;
  final String courseName;
  final String professorName;
  final String professorEmail;
  final bool wasShared;
  final String originalCoordinator;

  CourseAssignmentResult({
    required this.courseCode,
    required this.courseName,
    required this.professorName,
    required this.professorEmail,
    required this.wasShared,
    required this.originalCoordinator,
  });

  String get displayMapping => professorName;
}

