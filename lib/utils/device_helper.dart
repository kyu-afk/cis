// lib/utils/device_helper.dart
//
// Helper buat fitur "1 akun login CIS = 1 device": device_id (UUID acak yang
// dibikin sekali lalu disimpan permanen di penyimpanan lokal browser/device)
// & device_name (format "OS / Browser" utk web, atau "OS / Desktop App" /
// "OS / Mobile App" utk desktop/mobile — sama polanya dengan login_device_name
// kolektor/teller). Dikirim saat login supaya backend bisa mengunci device.

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_helper_stub.dart'
    if (dart.library.io) 'device_helper_io.dart'
    if (dart.library.html) 'device_helper_web.dart';

class DeviceHelper {
  static const _prefKeyDeviceId = 'cis_device_id';

  /// device_id: dibuat sekali per instalasi/browser, lalu disimpan permanen
  /// di SharedPreferences (untuk web: per-browser, karena localStorage-nya
  /// SharedPreferences plugin memang scoped ke origin browser tsb).
  static Future<String> getDeviceId() async {
    final pref = await SharedPreferences.getInstance();
    var id = pref.getString(_prefKeyDeviceId);
    if (id == null || id.isEmpty) {
      id = 'web-${_randomHex(32)}';
      await pref.setString(_prefKeyDeviceId, id);
    }
    return id;
  }

  /// device_name: "Windows / Chrome", "macOS / Desktop App", dst.
  static Future<String> getDeviceName() => platformDeviceName();

  static String _randomHex(int length) {
    const chars = '0123456789abcdef';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
