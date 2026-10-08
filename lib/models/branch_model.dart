/// Represents an academic branch (e.g., ECE, CSE)
class BranchModel {
  final String id;
  final String name;       // e.g., "ECE"
  final String fullName;   // e.g., "Electronics and Communication Engineering"
  final int years;
  final int semestersPerYear;
  final List<String> sections; // e.g., ["A", "B"] — for first year only
  final String createdBy;
  final DateTime createdAt;

  BranchModel({
    required this.id,
    required this.name,
    required this.fullName,
    required this.years,
    required this.semestersPerYear,
    required this.sections,
    required this.createdBy,
    required this.createdAt,
  });

  factory BranchModel.fromMap(Map<String, dynamic> data, String docId) {
    return BranchModel(
      id: docId,
      name: data['name'] ?? '',
      fullName: data['fullName'] ?? '',
      years: data['years'] ?? 4,
      semestersPerYear: data['semestersPerYear'] ?? 2,
      sections: List<String>.from(data['sections'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'fullName': fullName,
      'years': years,
      'semestersPerYear': semestersPerYear,
      'sections': sections,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
