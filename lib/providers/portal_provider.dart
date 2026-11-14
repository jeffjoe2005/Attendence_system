import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Server snapshots are scoped to the authenticated account. No sample-data fallback.
class PortalProvider extends ChangeNotifier with WidgetsBindingObserver {
  Map<String, dynamic>? snapshot;
  String? error;
  bool loading = false;
  bool saving = false;
  bool _disposed = false;
  Timer? _timer;
  Future<void>? _refreshing;
  PortalProvider({bool start = true}) {
    WidgetsBinding.instance.addObserver(this);
    if (!start) return;
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
    refresh();
  }
  List<Map<String, dynamic>> rows(String key) =>
      List<Map<String, dynamic>>.from(snapshot?[key] ?? []);
  bool get isAdmin =>
      ['moderator', 'admin', 'developer'].contains(snapshot?['user']?['role']);
  String get role => snapshot?['user']?['role'] ?? '';
  Future<void> refresh() {
    if (saving || _disposed) return Future.value();
    return _refreshing ??= _fetch().whenComplete(() => _refreshing = null);
  }

  Future<void> _fetch() async {
    loading = true;
    if (!_disposed) notifyListeners();
    try {
      snapshot = Map<String, dynamic>.from(
          await ApiService.instance.get('/api/workspace'));
      error = null;
    } catch (e) {
      error = e.toString();
      if (e is ApiException && [401, 403, 404].contains(e.statusCode)) {
        snapshot = null;
      }
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<dynamic> mutate(String method, String path, [dynamic body]) async {
    if (saving) throw Exception('Another change is being saved');
    saving = true;
    notifyListeners();
    try {
      // Finish any older poll before writing so it cannot overwrite the result.
      await _refreshing;
      final api = ApiService.instance;
      final result = method == 'POST'
          ? await api.post('/api/workspace$path', body: body)
          : method == 'PUT'
              ? await api.put('/api/workspace$path', body: body)
              : await api.delete('/api/workspace$path');
      return result;
    } finally {
      saving = false;
      await refresh();
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
