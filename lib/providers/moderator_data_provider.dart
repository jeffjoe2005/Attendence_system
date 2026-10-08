import 'package:flutter/material.dart';

/// Shared data store for Moderator-created data.
/// Both Moderator and Admin portals read/write through this provider.
class ModeratorDataProvider extends ChangeNotifier {
  // ── Courses ──
  final List<Map<String, String>> _courses = [];
  List<Map<String, String>> get courses => List.unmodifiable(_courses);

  void addCourse(String name, String code) {
    _courses.add({'name': name, 'code': code});
    notifyListeners();
  }

  void removeCourse(int index) {
    final course = _courses[index];
    // Also remove any mapping for this course
    _mappings.remove(course['code']);
    _courses.removeAt(index);
    notifyListeners();
  }

  // ── Professor Emails ──
  final List<String> _professorEmails = [];
  List<String> get professorEmails => List.unmodifiable(_professorEmails);

  void addProfessorEmail(String email) {
    _professorEmails.add(email);
    notifyListeners();
  }

  void removeProfessorEmail(int index) {
    final email = _professorEmails[index];
    // Also remove any mapping that references this professor
    _mappings.removeWhere((_, profEmail) => profEmail == email);
    _professorEmails.removeAt(index);
    notifyListeners();
  }

  // ── CR Emails ──
  final List<String> _crEmails = [];
  List<String> get crEmails => List.unmodifiable(_crEmails);

  void addCREmail(String email) {
    _crEmails.add(email);
    notifyListeners();
  }

  void removeCREmail(int index) {
    _crEmails.removeAt(index);
    notifyListeners();
  }

  // ── Professor ↔ Course Mappings (courseCode → professorEmail) ──
  final Map<String, String> _mappings = {};
  Map<String, String> get mappings => Map.unmodifiable(_mappings);

  void assignProfessor(String courseCode, String professorEmail) {
    _mappings[courseCode] = professorEmail;
    notifyListeners();
  }

  void removeAssignment(String courseCode) {
    _mappings.remove(courseCode);
    notifyListeners();
  }

  String? getProfessorForCourse(String courseCode) => _mappings[courseCode];

  /// Courses that have no professor assigned yet
  List<Map<String, String>> get unassignedCourses =>
      _courses.where((c) => !_mappings.containsKey(c['code'])).toList();

  /// Courses that have a professor assigned
  List<Map<String, String>> get assignedCourses =>
      _courses.where((c) => _mappings.containsKey(c['code'])).toList();

  // ── Reset everything ──
  void resetSemester() {
    _courses.clear();
    _professorEmails.clear();
    _crEmails.clear();
    _mappings.clear();
    notifyListeners();
  }
}
