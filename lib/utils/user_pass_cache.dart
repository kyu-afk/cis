import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache pass terenkripsi per userid (inquiry tidak mengembalikan pass).
class UserPassCache {
  static const _storageKey = 'medfo_user_pass_cache';

  static String _normUserId(String userid) => userid.trim().toUpperCase();

  static Future<Map<String, String>> _readAll() async {
    final pref = await SharedPreferences.getInstance();
    final raw = pref.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(String userid, String encryptedPass) async {
    final pass = encryptedPass.trim();
    if (userid.trim().isEmpty || pass.isEmpty) return;

    final all = await _readAll();
    all[_normUserId(userid)] = pass;

    final pref = await SharedPreferences.getInstance();
    await pref.setString(_storageKey, jsonEncode(all));
  }

  static Future<String?> get(String userid) async {
    if (userid.trim().isEmpty) return null;
    final all = await _readAll();
    return all[_normUserId(userid)];
  }
}
