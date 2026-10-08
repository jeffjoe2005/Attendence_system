/// Represents a user in the system
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String rollNumber;
  final String branch;
  final int year;
  final int semester;
  final String? section; // Only for Year 1 students
  final String role;     // moderator, admin, professor, cr, student
  final bool profileCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.rollNumber,
    required this.branch,
    required this.year,
    required this.semester,
    this.section,
    required this.role,
    required this.profileCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from a Map (for Firestore later)
  factory UserModel.fromMap(Map<String, dynamic> data, String docId) {
    return UserModel(
      uid: docId,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      rollNumber: data['rollNumber'] ?? '',
      branch: data['branch'] ?? '',
      year: data['year'] ?? 1,
      semester: data['semester'] ?? 1,
      section: data['section'],
      role: data['role'] ?? 'student',
      profileCompleted: data['profileCompleted'] ?? false,
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'rollNumber': rollNumber,
      'branch': branch,
      'year': year,
      'semester': semester,
      'section': section,
      'role': role,
      'profileCompleted': profileCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with modifications
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? rollNumber,
    String? branch,
    int? year,
    int? semester,
    String? section,
    String? role,
    bool? profileCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      rollNumber: rollNumber ?? this.rollNumber,
      branch: branch ?? this.branch,
      year: year ?? this.year,
      semester: semester ?? this.semester,
      section: section ?? this.section,
      role: role ?? this.role,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Empty user for initial registration
  factory UserModel.empty(String uid, String email) {
    return UserModel(
      uid: uid,
      email: email,
      name: '',
      rollNumber: '',
      branch: '',
      year: 1,
      semester: 1,
      role: 'student',
      profileCompleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ─── Role Helpers ─────────────────────────────────────────
  bool get isModerator => role == 'moderator';
  bool get isAdmin => role == 'admin';
  bool get isProfessor => role == 'professor';
  bool get isCR => role == 'cr';
  bool get isStudent => role == 'student';
  bool get isFirstYear => year == 1;
}
