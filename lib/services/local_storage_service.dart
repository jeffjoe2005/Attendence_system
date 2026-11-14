import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local JSON persistence service for the Attendance System.
/// Stores courses, faculty mappings, students, CRs, and attendance records
/// directly on disk so all changes survive restarts until a backend database is linked.
class LocalStorageService {
  LocalStorageService._();

  static const String _fileName = 'nit_goa_attendance_data.json';
  static const _webStorage = FlutterSecureStorage();
  static Future<bool> _pendingSave = Future.value(true);

  /// Resolves the storage file location across platforms (Documents folder or AppData).
  static Future<File> getStorageFile() async {
    try {
      final override = Platform.environment['ATTENDANCE_STORAGE_DIR'];
      if (override != null && override.isNotEmpty) {
        final folder = Directory(override);
        await folder.create(recursive: true);
        return File('${folder.path}/$_fileName');
      }
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
  static Future<bool> saveState(Map<String, dynamic> state) {
    final encoded = const JsonEncoder.withIndent('  ').convert({
      'version': 1, 'lastSaved': DateTime.now().toIso8601String(), ...state,
    });
    _pendingSave = _pendingSave.then((_) => _writeState(encoded));
    return _pendingSave;
  }

  static Future<bool> _writeState(String jsonString) async {
    try {
      if (kIsWeb) {
        await _webStorage.write(key: _fileName, value: jsonString);
        return true;
      }
      final file = await getStorageFile();
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
      await _pendingSave;
      if (kIsWeb) {
        final raw = await _webStorage.read(key: _fileName);
        return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw));
      }
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
      await _pendingSave;
      if (kIsWeb) { await _webStorage.delete(key: _fileName); return true; }
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
