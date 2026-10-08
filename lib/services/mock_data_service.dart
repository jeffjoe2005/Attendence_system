import '../models/user_model.dart';
import '../models/branch_model.dart';
import '../models/course_model.dart';
import '../models/enrollment_model.dart';
import '../models/attendance_model.dart';

/// In-memory mock backend for testing the UI without Firebase.
///
/// Data lives in static lists, so changes (join requests, approvals,
/// attendance submissions) persist for the lifetime of the app session.
/// Each public method mirrors a query we'll later run against Firestore.
class MockDataService {
  MockDataService._();

  // ═══════════════════════════════════════════════════════════
  // IN-MEMORY STORE
  // ═══════════════════════════════════════════════════════════
  static final List<BranchModel> _branches = _seedBranches();
  static final List<UserModel> _users = _seedUsers();
  static final List<CourseModel> _courses = _seedCourses();
  static final List<EnrollmentModel> _enrollments = _seedEnrollments();
  static final List<EnrollmentRequestModel> _requests = _seedRequests();
  static final List<AttendanceSessionModel> _sessions = _seedSessions();

  // ═══════════════════════════════════════════════════════════
  // BASIC GETTERS
  // ═══════════════════════════════════════════════════════════
  static List<BranchModel> get branches => List.unmodifiable(_branches);
  static List<CourseModel> get courses => List.unmodifiable(_courses);
  static List<EnrollmentModel> get enrollments => List.unmodifiable(_enrollments);

  static List<BranchModel> getBranches() => branches;
  static List<UserModel> getUsers() => List.unmodifiable(_users);
  static List<UserModel> getAllUsers() => getUsers();
  static List<CourseModel> getCourses() => courses;
  static List<EnrollmentRequestModel> getEnrollmentRequests() => List.unmodifiable(_requests);
  static List<AttendanceSessionModel> getAttendanceSessions() => List.unmodifiable(_sessions);

  static List<UserModel> getProfessors() =>
      _users.where((u) => u.isProfessor).toList();

  static List<UserModel> getStudentsByBranchYear(String branch, int year) {
    return _users
        .where((u) => (u.isStudent || u.isCR) && u.branch == branch && u.year == year)
        .toList();
  }

  static List<AttendanceRecordModel> getAttendanceRecords(String sessionId) {
    final session = _sessions.where((s) => s.id == sessionId);
    return session.isEmpty ? [] : session.first.records;
  }

  // ═══════════════════════════════════════════════════════════
  // ATTENDANCE MATH (single source of truth = session records)
  // ═══════════════════════════════════════════════════════════
  /// Returns the enrollment with total/attended counts computed from sessions
  static EnrollmentModel _withCounts(EnrollmentModel e) {
    int total = 0;
    int attended = 0;
    for (final s in _sessions.where((s) => s.courseId == e.courseId)) {
      for (final r in s.records) {
        if (r.studentUid == e.userUid) {
          total++;
          if (r.isPresent) attended++;
        }
      }
    }
    return e.copyWith(totalClasses: total, attendedClasses: attended);
  }

  /// Overall attendance across all enrolled courses (100 if no lectures yet)
  static double getStudentOverallAttendance(String userUid) {
    int total = 0;
    int attended = 0;
    for (final e in getStudentEnrollments(userUid)) {
      total += e.totalClasses;
      attended += e.attendedClasses;
    }
    return total == 0 ? 100 : (attended / total) * 100;
  }

  // ═══════════════════════════════════════════════════════════
  // STUDENT / CR
  // ═══════════════════════════════════════════════════════════
  static List<EnrollmentModel> getStudentEnrollments(String userUid) {
    return _enrollments.where((e) => e.userUid == userUid).map(_withCounts).toList();
  }

  static List<CourseModel> getStudentCourses(String userUid) {
    final ids = _enrollments.where((e) => e.userUid == userUid).map((e) => e.courseId).toSet();
    return _courses.where((c) => ids.contains(c.id)).toList();
  }

  /// Pending join requests made by this student
  static List<EnrollmentRequestModel> getStudentPendingRequests(String userUid) {
    return _requests.where((r) => r.userUid == userUid && r.isPending).toList();
  }

  /// A student's lecture-by-lecture history in one course (newest first)
  static List<AttendanceRecordModel> getStudentAttendanceHistory(String studentUid, String courseId) {
    final history = <AttendanceRecordModel>[];
    for (final s in _sessions.where((s) => s.courseId == courseId)) {
      history.addAll(s.records.where((r) => r.studentUid == studentUid));
    }
    history.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.lectureNumber.compareTo(a.lectureNumber);
    });
    return history;
  }

  /// Result of a join request
  static JoinResult requestJoinCourse({
    required String courseCode,
    required UserModel student,
  }) {
    final matches = _courses.where(
      (c) => c.courseCode.toUpperCase() == courseCode.trim().toUpperCase(),
    );
    if (matches.isEmpty) return JoinResult.notFound;
    final course = matches.first;

    if (_enrollments.any((e) => e.courseId == course.id && e.userUid == student.uid)) {
      return JoinResult.alreadyEnrolled;
    }
    if (_requests.any((r) => r.courseId == course.id && r.userUid == student.uid && r.isPending)) {
      return JoinResult.alreadyRequested;
    }

    _requests.add(EnrollmentRequestModel(
      id: '${course.id}_${student.uid}',
      courseId: course.id,
      courseName: course.courseName,
      courseCode: course.courseCode,
      userUid: student.uid,
      studentName: student.name,
      rollNumber: student.rollNumber,
      branch: student.branch,
      year: student.year,
      semester: student.semester,
      status: 'pending',
      requestedAt: DateTime.now(),
    ));
    return JoinResult.requested;
  }

  // ═══════════════════════════════════════════════════════════
  // PROFESSOR
  // ═══════════════════════════════════════════════════════════
  static List<CourseModel> getProfessorCourses(String professorUid) {
    return _courses.where((c) => c.professorUid == professorUid).toList();
  }

  /// Enrollments in a course with computed counts, sorted by roll number
  static List<EnrollmentModel> getCourseEnrollments(String courseId) {
    final list = _enrollments.where((e) => e.courseId == courseId).map(_withCounts).toList();
    list.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
    return list;
  }

  static List<EnrollmentRequestModel> getPendingRequestsForProfessor(String professorUid) {
    final ids = getProfessorCourses(professorUid).map((c) => c.id).toSet();
    return _requests.where((r) => ids.contains(r.courseId) && r.isPending).toList();
  }

  static void approveRequest(String requestId, String reviewerUid) {
    final i = _requests.indexWhere((r) => r.id == requestId);
    if (i == -1) return;
    final req = _requests[i];
    _requests[i] = req.copyWith(status: 'approved', reviewedBy: reviewerUid, reviewedAt: DateTime.now());
    _enrollments.add(EnrollmentModel(
      id: '${req.courseId}_${req.userUid}',
      courseId: req.courseId,
      courseName: req.courseName,
      userUid: req.userUid,
      studentName: req.studentName,
      rollNumber: req.rollNumber,
      enrolledAt: DateTime.now(),
      approvedBy: reviewerUid,
    ));
  }

  static void rejectRequest(String requestId, String reviewerUid) {
    final i = _requests.indexWhere((r) => r.id == requestId);
    if (i == -1) return;
    _requests[i] = _requests[i].copyWith(status: 'rejected', reviewedBy: reviewerUid, reviewedAt: DateTime.now());
  }

  /// Sessions for a course, newest first
  static List<AttendanceSessionModel> getCourseSessions(String courseId) {
    final list = _sessions.where((s) => s.courseId == courseId).toList();
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.lectureNumber.compareTo(a.lectureNumber);
    });
    return list;
  }

  /// Next lecture number for a course on a given date (per-course, per-day)
  static int getNextLectureNumber(String courseId, String date) {
    final sameDay = _sessions.where((s) => s.courseId == courseId && s.date == date);
    if (sameDay.isEmpty) return 1;
    return sameDay.map((s) => s.lectureNumber).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Saves a session. Replaces an existing one with the same course/date/lecture.
  static void saveAttendanceSession(AttendanceSessionModel session) {
    _sessions.removeWhere((s) =>
        s.courseId == session.courseId &&
        s.date == session.date &&
        s.lectureNumber == session.lectureNumber);
    _sessions.add(session);
  }

  // ═══════════════════════════════════════════════════════════
  // ADMIN / HOD
  // ═══════════════════════════════════════════════════════════
  /// Students + CRs in a branch. Empty branch = whole college.
  static List<UserModel> getStudentsByBranch(String branch) {
    return _users
        .where((u) => (u.isStudent || u.isCR) && u.profileCompleted && (branch.isEmpty || u.branch == branch))
        .toList();
  }

  /// Courses in a branch. Empty branch = whole college.
  static List<CourseModel> getCoursesByBranch(String branch) {
    return _courses.where((c) => branch.isEmpty || c.branch == branch).toList();
  }

  /// Average attendance of a course across all enrolled students
  static double getCourseAverageAttendance(String courseId) {
    final list = getCourseEnrollments(courseId).where((e) => e.totalClasses > 0).toList();
    if (list.isEmpty) return 0;
    return list.map((e) => e.attendancePercentage).reduce((a, b) => a + b) / list.length;
  }

  // ═══════════════════════════════════════════════════════════
  // SEED DATA
  // ═══════════════════════════════════════════════════════════
  static List<BranchModel> _seedBranches() {
    final created = DateTime(2026, 1, 1);
    BranchModel b(String id, String name, String full) => BranchModel(
          id: id, name: name, fullName: full,
          years: 4, semestersPerYear: 2, sections: ['A', 'B'],
          createdBy: 'mod1', createdAt: created,
        );
    return [
      b('b1', 'ECE', 'Electronics and Communication Engineering'),
      b('b2', 'CSE', 'Computer Science and Engineering'),
      b('b3', 'EEE', 'Electrical and Electronics Engineering'),
      b('b4', 'ME', 'Mechanical Engineering'),
      b('b5', 'CE', 'Civil Engineering'),
    ];
  }

  static List<UserModel> _seedUsers() {
    final t = DateTime(2026, 1, 1);
    UserModel u(String uid, String email, String name, String roll, String branch,
            int year, int sem, String role, {bool done = true}) =>
        UserModel(
          uid: uid, email: email, name: name, rollNumber: roll,
          branch: branch, year: year, semester: sem, role: role,
          profileCompleted: done, createdAt: t, updatedAt: t,
        );
    return [
      u('mod1', 'moderator@nitgoa.ac.in', 'Dr. Rajesh Kumar', '', '', 0, 0, 'moderator'),
      u('admin1', 'admin@nitgoa.ac.in', 'Prof. Meera Sharma', '', 'ECE', 0, 0, 'admin'),
      u('prof1', 'prof.dsp@nitgoa.ac.in', 'Dr. Anil Verma', '', 'ECE', 0, 0, 'professor'),
      u('prof2', 'prof.es@nitgoa.ac.in', 'Dr. Priya Nair', '', 'ECE', 0, 0, 'professor'),
      u('cr1', 'cr.ece3@nitgoa.ac.in', 'Rahul Patil', '22ECE001', 'ECE', 3, 5, 'cr'),
      u('stu1', 'student1@nitgoa.ac.in', 'Arjun Desai', '22ECE045', 'ECE', 3, 5, 'student'),
      u('stu2', 'student2@nitgoa.ac.in', 'Sneha Iyer', '22ECE032', 'ECE', 3, 5, 'student'),
      u('stu3', 'student3@nitgoa.ac.in', 'Karan Mehta', '22ECE018', 'ECE', 3, 5, 'student'),
      u('stu4', 'student4@nitgoa.ac.in', 'Neha Kulkarni', '22ECE050', 'ECE', 3, 5, 'student'),
      u('stu_new', 'newstudent@nitgoa.ac.in', '', '', '', 1, 1, 'student', done: false),
    ];
  }

  static List<CourseModel> _seedCourses() {
    final t = DateTime(2026, 7, 1);
    CourseModel c(String id, String code, String name, String branch, int year, int sem,
            {String? profUid, String? profName, String? section}) =>
        CourseModel(
          id: id, courseCode: code, courseName: name, branch: branch,
          year: year, semester: sem, section: section,
          professorUid: profUid, professorName: profName,
          createdBy: 'mod1', createdAt: t, updatedAt: t,
        );
    return [
      c('c1', 'ECE301', 'Digital Signal Processing', 'ECE', 3, 5, profUid: 'prof1', profName: 'Dr. Anil Verma'),
      c('c2', 'ECE302', 'Embedded Systems', 'ECE', 3, 5, profUid: 'prof2', profName: 'Dr. Priya Nair'),
      c('c3', 'ECE303', 'VLSI Design', 'ECE', 3, 5, profUid: 'prof1', profName: 'Dr. Anil Verma'),
      c('c4', 'CSE301', 'Operating Systems', 'CSE', 3, 5),
      c('c5', 'GEN101', 'Engineering Mathematics I', 'ECE', 1, 1, section: 'A'),
    ];
  }

  static List<EnrollmentModel> _seedEnrollments() {
    final t = DateTime(2026, 8, 1);
    EnrollmentModel e(String courseId, String courseName, String uid, String name, String roll, String by) =>
        EnrollmentModel(
          id: '${courseId}_$uid', courseId: courseId, courseName: courseName,
          userUid: uid, studentName: name, rollNumber: roll,
          enrolledAt: t, approvedBy: by,
        );
    return [
      e('c1', 'Digital Signal Processing', 'stu1', 'Arjun Desai', '22ECE045', 'prof1'),
      e('c1', 'Digital Signal Processing', 'stu2', 'Sneha Iyer', '22ECE032', 'prof1'),
      e('c1', 'Digital Signal Processing', 'stu3', 'Karan Mehta', '22ECE018', 'cr1'),
      e('c1', 'Digital Signal Processing', 'cr1', 'Rahul Patil', '22ECE001', 'prof1'),
      e('c2', 'Embedded Systems', 'stu1', 'Arjun Desai', '22ECE045', 'prof2'),
      e('c2', 'Embedded Systems', 'cr1', 'Rahul Patil', '22ECE001', 'prof2'),
    ];
  }

  static List<EnrollmentRequestModel> _seedRequests() {
    final t = DateTime(2026, 10, 5);
    EnrollmentRequestModel r(String courseId, String code, String name, String uid, String sName, String roll) =>
        EnrollmentRequestModel(
          id: '${courseId}_$uid', courseId: courseId, courseName: name, courseCode: code,
          userUid: uid, studentName: sName, rollNumber: roll,
          branch: 'ECE', year: 3, semester: 5, status: 'pending', requestedAt: t,
        );
    return [
      r('c1', 'ECE301', 'Digital Signal Processing', 'stu4', 'Neha Kulkarni', '22ECE050'),
      r('c2', 'ECE302', 'Embedded Systems', 'stu2', 'Sneha Iyer', '22ECE032'),
      r('c2', 'ECE302', 'Embedded Systems', 'stu3', 'Karan Mehta', '22ECE018'),
    ];
  }

  /// Generates a realistic history:
  /// - DSP (c1): 12 lectures. Arjun 83%, Sneha 75%, Karan 50% (defaulter), Rahul 92%
  /// - Embedded (c2): 8 lectures. Arjun 62.5% (low in this subject), Rahul 87.5%
  static List<AttendanceSessionModel> _seedSessions() {
    final sessions = <AttendanceSessionModel>[];

    void build({
      required String courseId,
      required String courseName,
      required int lectures,
      required String markerUid,
      required String markerName,
      required List<(String uid, String name, String roll, Set<int> absentOn)> students,
    }) {
      for (int i = 1; i <= lectures; i++) {
        final day = DateTime(2026, 9, 1).add(Duration(days: (i - 1) * 2));
        final date = _fmt(day);
        // Every 4th lecture is marked by the CR to show both marker types
        final byCR = i % 4 == 0;
        final records = students.map((s) {
          return AttendanceRecordModel(
            studentUid: s.$1, studentName: s.$2, rollNumber: s.$3,
            status: s.$4.contains(i) ? 'absent' : 'present',
            markedAt: day.add(const Duration(hours: 9, minutes: 5)),
            date: date, lectureNumber: 1,
          );
        }).toList();
        final present = records.where((r) => r.isPresent).length;
        sessions.add(AttendanceSessionModel(
          id: '${courseId}_${date}_1',
          courseId: courseId, courseName: courseName,
          date: date, lectureNumber: 1,
          markedBy: byCR ? 'cr1' : markerUid,
          markedByName: byCR ? 'Rahul Patil' : markerName,
          markedByRole: byCR ? 'cr' : 'professor',
          createdAt: day.add(const Duration(hours: 9)),
          updatedAt: day.add(const Duration(hours: 9, minutes: 30)),
          totalPresent: present,
          totalAbsent: records.length - present,
          totalStudents: records.length,
          records: records,
        ));
      }
    }

    build(
      courseId: 'c1', courseName: 'Digital Signal Processing', lectures: 12,
      markerUid: 'prof1', markerName: 'Dr. Anil Verma',
      students: [
        ('stu1', 'Arjun Desai', '22ECE045', {3, 7}),
        ('stu2', 'Sneha Iyer', '22ECE032', {2, 5, 9}),
        ('stu3', 'Karan Mehta', '22ECE018', {1, 3, 4, 6, 8, 10}),
        ('cr1', 'Rahul Patil', '22ECE001', {11}),
      ],
    );
    build(
      courseId: 'c2', courseName: 'Embedded Systems', lectures: 8,
      markerUid: 'prof2', markerName: 'Dr. Priya Nair',
      students: [
        ('stu1', 'Arjun Desai', '22ECE045', {2, 5, 7}),
        ('cr1', 'Rahul Patil', '22ECE001', {6}),
      ],
    );
    return sessions;
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Outcome of a student's course join request
enum JoinResult { requested, notFound, alreadyEnrolled, alreadyRequested }
