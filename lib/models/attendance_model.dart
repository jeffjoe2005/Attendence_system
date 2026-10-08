/// Represents a single attendance session (one lecture)
class AttendanceSessionModel {
  final String id;
  final String courseId;
  final String courseName;
  final String date;         // YYYY-MM-DD
  final int lectureNumber;   // auto-incremented per course per day
  final String markedBy;
  final String markedByName;
  final String markedByRole; // professor or cr
  final DateTime createdAt;
  final DateTime updatedAt;
  final int totalPresent;
  final int totalAbsent;
  final int totalStudents;

  /// Per-student records. Held in memory only — in Firestore these live
  /// in the `records` subcollection, so they are not part of toMap().
  final List<AttendanceRecordModel> records;

  AttendanceSessionModel({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.date,
    required this.lectureNumber,
    required this.markedBy,
    required this.markedByName,
    required this.markedByRole,
    required this.createdAt,
    required this.updatedAt,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalStudents,
    this.records = const [],
  });

  factory AttendanceSessionModel.fromMap(Map<String, dynamic> data, String docId) {
    return AttendanceSessionModel(
      id: docId,
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? '',
      date: data['date'] ?? '',
      lectureNumber: data['lectureNumber'] ?? 1,
      markedBy: data['markedBy'] ?? '',
      markedByName: data['markedByName'] ?? '',
      markedByRole: data['markedByRole'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
      totalPresent: data['totalPresent'] ?? 0,
      totalAbsent: data['totalAbsent'] ?? 0,
      totalStudents: data['totalStudents'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'date': date,
      'lectureNumber': lectureNumber,
      'markedBy': markedBy,
      'markedByName': markedByName,
      'markedByRole': markedByRole,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'totalPresent': totalPresent,
      'totalAbsent': totalAbsent,
      'totalStudents': totalStudents,
    };
  }

  double get attendancePercentage =>
      totalStudents > 0 ? (totalPresent / totalStudents) * 100 : 0;
}

/// Represents a single student's attendance record within a session
class AttendanceRecordModel {
  final String studentUid;
  final String studentName;
  final String rollNumber;
  final String status;       // present or absent
  final DateTime markedAt;
  final DateTime? editedAt;
  final String? editedBy;
  final String date;         // copied from session (YYYY-MM-DD)
  final int lectureNumber;   // copied from session

  AttendanceRecordModel({
    required this.studentUid,
    required this.studentName,
    required this.rollNumber,
    required this.status,
    required this.markedAt,
    this.editedAt,
    this.editedBy,
    this.date = '',
    this.lectureNumber = 0,
  });

  factory AttendanceRecordModel.fromMap(Map<String, dynamic> data) {
    return AttendanceRecordModel(
      studentUid: data['studentUid'] ?? '',
      studentName: data['studentName'] ?? '',
      rollNumber: data['rollNumber'] ?? '',
      status: data['status'] ?? 'absent',
      markedAt: DateTime.tryParse(data['markedAt'] ?? '') ?? DateTime.now(),
      editedAt: data['editedAt'] != null
          ? DateTime.tryParse(data['editedAt'])
          : null,
      editedBy: data['editedBy'],
      date: data['date'] ?? '',
      lectureNumber: data['lectureNumber'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentUid': studentUid,
      'studentName': studentName,
      'rollNumber': rollNumber,
      'status': status,
      'markedAt': markedAt.toIso8601String(),
      'editedAt': editedAt?.toIso8601String(),
      'editedBy': editedBy,
      'date': date,
      'lectureNumber': lectureNumber,
    };
  }

  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';
  bool get wasEdited => editedAt != null;
}
