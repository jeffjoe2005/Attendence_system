import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Local JSON persistence service for the Attendance System.
/// Stores courses, faculty mappings, students, CRs, and attendance records
/// directly on disk so all changes survive restarts until a backend database is linked.
class LocalStorageService {
  LocalStorageService._();

  static const String _fileName = 'nit_goa_attendance_data.json';

  /// Resolves the storage file location across platforms (Documents folder or AppData).
  static Future<File> getStorageFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final appDir = Directory('${dir.path}/NITGoa_Attendance');
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      return File('${appDir.path}/$_fileName');
    } catch (_) {
      // Fallback for headless environments or unit test execution
      final appData = Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'];
      if (appData != null && appData.isNotEmpty) {
        final folder = Directory('$appData/NITGoa_Attendance');
        if (!folder.existsSync()) folder.createSync(recursive: true);
        return File('${folder.path}/$_fileName');
      }
      return File(_fileName);
    }
  }

  /// Saves the complete system state to disk as formatted JSON.
  static Future<bool> saveState(Map<String, dynamic> state) async {
    try {
      final file = await getStorageFile();
      final jsonString = const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'lastSaved': DateTime.now().toIso8601String(),
        ...state,
      });
      await file.writeAsString(jsonString, flush: true);
      return true;
    } catch (e) {
      debugPrint('Error saving attendance state to disk: $e');
      return false;
    }
  }

  /// Loads the saved system state from disk, or returns null if not found.
  static Future<Map<String, dynamic>?> loadState() async {
    try {
      final file = await getStorageFile();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final dynamic decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading attendance state from disk: $e');
      return null;
    }
  }

  /// Removes the local storage file from disk (e.g. for full database reset).
  static Future<bool> clearStorage() async {
    try {
      final file = await getStorageFile();
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
