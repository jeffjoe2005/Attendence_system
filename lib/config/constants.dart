/// App-wide constants for the Attendance System
class AppConstants {
  // ─── College Domain ───────────────────────────────────────
  static const String collegeDomain = 'nitgoa.ac.in';
  static const String collegeEmailSuffix = '@$collegeDomain';
  static const String collegeName = 'NIT Goa';

  // ─── Roles ────────────────────────────────────────────────
  static const String roleModerator = 'moderator';
  static const String roleAdmin = 'admin';
  static const String roleProfessor = 'professor';
  static const String roleCR = 'cr';
  static const String roleStudent = 'student';

  static const List<String> allRoles = [
    roleModerator,
    roleAdmin,
    roleProfessor,
    roleCR,
    roleStudent,
  ];

  /// Roles that the Moderator can assign to users
  static const List<String> assignableRoles = [
    roleStudent,
    roleCR,
    roleProfessor,
    roleAdmin,
  ];

  // ─── Attendance Thresholds ────────────────────────────────
  static const double attendanceGoodThreshold = 80.0;
  static const double attendanceWarningThreshold = 75.0;

  /// Minimum required attendance — below this a student is a defaulter
  static const double attendanceThreshold = attendanceWarningThreshold;

  // ─── Attendance Status ────────────────────────────────────
  static const String statusPresent = 'present';
  static const String statusAbsent = 'absent';

  // ─── Enrollment Status ────────────────────────────────────
  static const String enrollmentPending = 'pending';
  static const String enrollmentApproved = 'approved';
  static const String enrollmentRejected = 'rejected';

  // ─── Firestore Collections (for later use) ────────────────
  static const String usersCollection = 'users';
  static const String branchesCollection = 'branches';
  static const String coursesCollection = 'courses';
  static const String enrollmentsCollection = 'enrollments';
  static const String enrollmentRequestsCollection = 'enrollmentRequests';
  static const String attendanceSessionsCollection = 'attendanceSessions';
  static const String attendanceRecordsSubCollection = 'records';

  // ─── Validation ───────────────────────────────────────────
  static bool isValidCollegeEmail(String email) {
    return email.toLowerCase().endsWith(collegeEmailSuffix);
  }

  static String getAttendanceStatusLabel(double percentage) {
    if (percentage >= attendanceGoodThreshold) return 'Good Standing';
    if (percentage >= attendanceWarningThreshold) return 'Warning';
    return 'Low Attendance';
  }
}
