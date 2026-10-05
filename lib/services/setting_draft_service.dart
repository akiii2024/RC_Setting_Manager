import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Serializes draft writes so a pending autosave cannot undo a deletion.
class SettingDraftService {
  SettingDraftService(this.carId, this.settingId);

  final String carId;
  final String? settingId;
  Timer? _timer;
  String? _pending;
  Future<void> _writes = Future<void>.value();

  String get key => 'setting_draft_v1:${jsonEncode([carId, settingId])}';

  Future<Map<String, dynamic>?> read() async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic> &&
          value['settings'] is Map<String, dynamic> &&
          value['name'] is String &&
          value['trackName'] is String) {
        return value;
      }
    } on FormatException {
      // Ignore invalid drafts without affecting the saved setting.
    }
    return null;
  }

  void schedule(Map<String, dynamic> draft) {
    _pending = jsonEncode(draft);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), flush);
  }

  Future<void> _enqueue(Future<void> Function(SharedPreferences) action) {
    _writes = _writes.then((_) async {
      try {
        await action(await SharedPreferences.getInstance());
      } catch (_) {
        // Autosave is best effort and must never interrupt explicit saving.
      }
    });
    return _writes;
  }

  Future<void> flush() {
    _timer?.cancel();
    final raw = _pending;
    _pending = null;
    if (raw == null) return _writes;
    return _enqueue((prefs) async {
      await prefs.setString(key, raw);
    });
  }

  Future<void> clear() {
    _timer?.cancel();
    _pending = null;
    return _enqueue((prefs) async {
      await prefs.remove(key);
    });
  }
}
