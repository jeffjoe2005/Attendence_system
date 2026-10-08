/// Represents a course in the system
class CourseModel {
  final String id;
  final String courseCode;    // e.g., "ECE301"
  final String courseName;    // e.g., "Digital Signal Processing"
  final String branch;
  final int year;
  final int semester;
  final String? section;      // null = branch-wide; "A" = section-specific (Year 1)
  final String? professorUid;
  final String? professorName;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  CourseModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.branch,
    required this.year,
    required this.semester,
    this.section,
    this.professorUid,
    this.professorName,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CourseModel.fromMap(Map<String, dynamic> data, String docId) {
    return CourseModel(
      id: docId,
      courseCode: data['courseCode'] ?? '',
      courseName: data['courseName'] ?? '',
      branch: data['branch'] ?? '',
      year: data['year'] ?? 1,
      semester: data['semester'] ?? 1,
      section: data['section'],
      professorUid: data['professorUid'],
      professorName: data['professorName'],
      createdBy: data['createdBy'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'branch': branch,
      'year': year,
      'semester': semester,
      'section': section,
      'professorUid': professorUid,
      'professorName': professorName,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get hasProfessor => professorUid != null && professorUid!.isNotEmpty;
  bool get isSectionSpecific => section != null && section!.isNotEmpty;

  CourseModel copyWith({
    String? professorUid,
    String? professorName,
    DateTime? updatedAt,
  }) {
    return CourseModel(
      id: id,
      courseCode: courseCode,
      courseName: courseName,
      branch: branch,
      year: year,
      semester: semester,
      section: section,
      professorUid: professorUid ?? this.professorUid,
      professorName: professorName ?? this.professorName,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
