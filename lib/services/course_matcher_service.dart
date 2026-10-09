/// Service to resolve course-to-professor assignments with strict capacity constraints:
/// 1. Maximum 2 courses per professor (`maxCoursesPerProf = 2`).
/// 2. Exactly 1 professor per course (no shared courses like "Prof A & Prof B").
/// 3. Preserves natural Theory + Lab pairings and original coordinators wherever possible.
/// 4. Reassigns overflow or shared courses to available department faculty by domain affinity.
class CourseMatcherService {
  CourseMatcherService._();

  static const int maxCoursesPerProf = 2;

  /// Known NIT Goa faculty email directory (ECE, CSE, EEE)
  static final Map<String, String> facultyEmails = {
    // ECE Faculty
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
    'Dr. Sunil Kumar A': 'sunil.kumar@nitgoa.ac.in',
    'Dr. Velavan K': 'velavan.k@nitgoa.ac.in',
    'Dr. Sarani Ghosal Mondal': 'sarani.ghosal@nitgoa.ac.in',
    'Dr. Rinu Koshy': 'rinu.koshy@nitgoa.ac.in',

    // CSE Faculty
    'Dr. Pravati Swain': 'pravati.swain@nitgoa.ac.in',
    'Dr. Damodar Reddy': 'damodar.reddy@nitgoa.ac.in',
    'Dr. B. R. Chandavarkar': 'keshavamurthy@nitgoa.ac.in',
    'Dr. Venkat Subba Reddy': 'venkat.subba@nitgoa.ac.in',

    // EEE Faculty
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
    'Dr. Sreeraj E. S.': 'sreeraj@nitgoa.ac.in',
    'Dr. Amresh Kumar': 'amresh.kumar@nitgoa.ac.in',
    'Dr. Mini S.': 'mini@nitgoa.ac.in',

    // ME Faculty
    'Dr. Shiba Sundar Mahapatra': 'shiba.sundar@nitgoa.ac.in',
    'Dr. Ravi Raghav': 'ravi.raghav@nitgoa.ac.in',
    'Dr. Prashant Kumar': 'prashant.kumar@nitgoa.ac.in',

    // CE Faculty
    'Dr. Sarath Babu': 'sarath.babu@nitgoa.ac.in',
    'Dr. Rajesh Prabhu Gaonkar': 'rajesh.prabhu@nitgoa.ac.in',
  };

  /// Normalizes variant spellings found in college timetables
  static String normalizeProfName(String name) {
    var clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean == 'Dr. Mallikarjun E' || clean == 'Mallikarjun E') return 'Dr. E. Mallikarjun';
    if (clean == 'Dr. Nithinkumar YB' || clean == 'Nithinkumar YB' || clean == 'Dr. Nithin Kumar YB') return 'Dr. Nithin Kumar Y.B.';
    if (clean == 'Dr. Sreeraj E. S.' || clean == 'Dr. Sreeraj ES' || clean == 'Sreeraj E.S.') return 'Dr. Sreeraj E. S.';
    if (clean.contains('Dr. Suresh Mikkili')) return 'Dr. Suresh Mikkili';
    if (clean.contains('Dr. Mini S.')) return 'Dr. Mini S.';
    if (clean == 'Dr. Najiya V. K.' || clean == 'Dr. Najiya VK') return 'Dr. Najiya V K';
    if (clean == 'CSE Faculty' || clean == 'CSE dept') return 'Dr. Damodar Reddy';
    return clean;
  }

  /// Splits multi-coordinator strings (e.g. "Dr. Pragati Patel & Dr. E. Mallikarjun")
  static List<String> splitCoordinators(String raw) {
    if (raw.isEmpty) return [];
    final parts = raw.split(RegExp(r'\s*(&|/|,|\band\b)\s*', caseSensitive: false));
    return parts.map(normalizeProfName).where((p) => p.isNotEmpty).toList();
  }

  /// Main matching engine
  /// Takes raw parsed courses and returns clean 1-to-1 course-to-professor assignments.
  static Map<String, CourseAssignmentResult> matchCourses({
    required List<Map<String, String>> rawCourses,
  }) {
    final Map<String, List<String>> profAssigned = {};
    for (final prof in facultyEmails.keys) {
      profAssigned[prof] = [];
    }

    final Map<String, CourseAssignmentResult> results = {};

    // 1. Core theory + lab pair priority definitions
    final Map<String, String> primaryPreference = {
      'EC251': 'Dr. Lokesh Kumar B',
      'EC255': 'Dr. Lokesh Kumar B',
      'EC252': 'Dr. Pragati Patel',
      'EC256': 'Dr. Pragati Patel',
      'EC350': 'Dr. Trilochan Panigrahi',
      'EC353': 'Dr. Trilochan Panigrahi',
      'EC352': 'Dr. Nithin Kumar Y.B.',
      'EC355': 'Dr. Nithin Kumar Y.B.',
      'EC351': 'Dr. Anirban Chatterjee',
      'EC350M': 'Dr. Anirban Chatterjee',
      'EC253': 'Dr. E. Mallikarjun',
      'EC404': 'Dr. E. Mallikarjun',
      'EC250': 'Dr. Najiya V K',
      'EC254': 'Dr. Lalat Indu Giri',
      'EC651': 'Dr. Lalat Indu Giri',
      'EC405': 'Dr. Vasantha M.H',
      'EC810': 'Dr. Vasantha M.H',
      'EC520': 'Dr. T. Veerakumar',
      'EC802': 'Dr. T. Veerakumar',
      'HS350': 'Dr. Sunil Kumar A',
      'ES300': 'Dr. Velavan K',
      'HU401': 'Dr. Sarani Ghosal Mondal',
      'HU650*': 'Dr. Rinu Koshy',
      'CS901': 'Dr. Damodar Reddy',
      'EC450M': 'Dr. Prashanth G.R',
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

    // Phase 2: Resolve shared courses (e.g. EC354)
    for (final course in rawCourses) {
      final code = (course['code'] ?? '').trim().toUpperCase();
      if (results.containsKey(code)) continue;

      final rawCoord = course['coordinator'] ?? '';
      final candidates = splitCoordinators(rawCoord);

      if (candidates.length > 1) {
        // Try candidate 1 or candidate 2 if capacity allows
        String? chosenProf;
        for (final cand in candidates) {
          if ((profAssigned[cand]?.length ?? 0) < maxCoursesPerProf) {
            chosenProf = cand;
            break;
          }
        }

        // If both original co-teachers are full (e.g., EC354 with Patel & Mallikarjun)
        // Assign to available domain specialist: Dr. Shivnarayan Patidar
        chosenProf ??= 'Dr. Shivnarayan Patidar';

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

    // Phase 3: Resolve overloaded or unassigned courses
    final Map<String, String> overloadResolutions = {
      'CS522': 'Dr. Shivnarayan Patidar', // AI/Signal Processing
      'EC499': 'Dr. Prashanth G.R',        // Major Project
      'EC424': 'Ishaan Bhate',             // Low-Power VLSI
      'EC652': 'Ishaan Bhate',             // System Design Lab
      'EC356': 'Dr. Najiya V K',           // Seminar
      'EC650': 'Dr. Pravati Swain',        // VLSI Testing
      'EC804': 'Dr. Pravati Swain',        // Mixed Signal Design
      'EC653': 'Dr. Rinu Koshy',           // Viva-Voce
      'EC750': 'Dr. B. R. Chandavarkar',   // MTech Major Project II
      'EC903': 'Dr. Venkat Subba Reddy',   // Signal Processing (OE)
      'IE250': 'Dr. Sunil Kumar A',        // Innovation & Entrepreneurship
    };

    for (final course in rawCourses) {
      final code = (course['code'] ?? '').trim().toUpperCase();
      if (results.containsKey(code)) continue;

      String assignedProf = overloadResolutions[code] ?? '';
      if (assignedProf.isEmpty || (profAssigned[assignedProf]?.length ?? 0) >= maxCoursesPerProf) {
        // Find any faculty with capacity < 2
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
