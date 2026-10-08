/// Represents a student's enrollment in a course
class EnrollmentModel {
  final String id;          // courseId_userUid
  final String courseId;
  final String courseName;
  final String userUid;
  final String studentName;
  final String rollNumber;
  final DateTime enrolledAt;
  final String approvedBy;
  final int totalClasses;    // lectures held since enrollment
  final int attendedClasses; // lectures marked present

  EnrollmentModel({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.userUid,
    required this.studentName,
    required this.rollNumber,
    required this.enrolledAt,
    this.approvedBy = '',
    this.totalClasses = 0,
    this.attendedClasses = 0,
  });

  factory EnrollmentModel.fromMap(Map<String, dynamic> data, String docId) {
    return EnrollmentModel(
      id: docId,
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? '',
      userUid: data['userUid'] ?? '',
      studentName: data['studentName'] ?? '',
      rollNumber: data['rollNumber'] ?? '',
      enrolledAt: DateTime.tryParse(data['enrolledAt'] ?? '') ?? DateTime.now(),
      approvedBy: data['approvedBy'] ?? '',
      totalClasses: data['totalClasses'] ?? 0,
      attendedClasses: data['attendedClasses'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'userUid': userUid,
      'studentName': studentName,
      'rollNumber': rollNumber,
      'enrolledAt': enrolledAt.toIso8601String(),
      'approvedBy': approvedBy,
      'totalClasses': totalClasses,
      'attendedClasses': attendedClasses,
    };
  }

  /// Attendance % for this course. 100% when no lectures held yet.
  double get attendancePercentage =>
      totalClasses > 0 ? (attendedClasses / totalClasses) * 100 : 100;

  EnrollmentModel copyWith({int? totalClasses, int? attendedClasses}) {
    return EnrollmentModel(
      id: id,
      courseId: courseId,
      courseName: courseName,
      userUid: userUid,
      studentName: studentName,
      rollNumber: rollNumber,
      enrolledAt: enrolledAt,
      approvedBy: approvedBy,
      totalClasses: totalClasses ?? this.totalClasses,
      attendedClasses: attendedClasses ?? this.attendedClasses,
    );
  }
}

/// Represents a student's request to join a course
class EnrollmentRequestModel {
  final String id;          // courseId_userUid
  final String courseId;
  final String courseName;
  final String courseCode;
  final String userUid;
  final String studentName;
  final String rollNumber;
  final String branch;
  final int year;
  final int semester;
  final String status;      // pending, approved, rejected
  final DateTime requestedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  EnrollmentRequestModel({
    required this.id,
    required this.courseId,
    required this.courseName,
    this.courseCode = '',
    required this.userUid,
    required this.studentName,
    required this.rollNumber,
    required this.branch,
    required this.year,
    required this.semester,
    required this.status,
    required this.requestedAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory EnrollmentRequestModel.fromMap(Map<String, dynamic> data, String docId) {
    return EnrollmentRequestModel(
      id: docId,
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? '',
      courseCode: data['courseCode'] ?? '',
      userUid: data['userUid'] ?? '',
      studentName: data['studentName'] ?? '',
      rollNumber: data['rollNumber'] ?? '',
      branch: data['branch'] ?? '',
      year: data['year'] ?? 1,
      semester: data['semester'] ?? 1,
      status: data['status'] ?? 'pending',
      requestedAt: DateTime.tryParse(data['requestedAt'] ?? '') ?? DateTime.now(),
      reviewedBy: data['reviewedBy'],
      reviewedAt: data['reviewedAt'] != null
          ? DateTime.tryParse(data['reviewedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'courseCode': courseCode,
      'userUid': userUid,
      'studentName': studentName,
      'rollNumber': rollNumber,
      'branch': branch,
      'year': year,
      'semester': semester,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
    };
  }

  EnrollmentRequestModel copyWith({
    String? status,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) {
    return EnrollmentRequestModel(
      id: id,
      courseId: courseId,
      courseName: courseName,
      courseCode: courseCode,
      userUid: userUid,
      studentName: studentName,
      rollNumber: rollNumber,
      branch: branch,
      year: year,
      semester: semester,
      status: status ?? this.status,
      requestedAt: requestedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
