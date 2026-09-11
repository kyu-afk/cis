// lib/utils/device_helper_io.dart
//
// Implementasi platformDeviceName() untuk platform dart:io (desktop app:
// Windows/macOS/Linux, atau mobile: Android/iOS). Dipakai lewat conditional
// import di device_helper.dart — jangan diimpor langsung dari file lain.

import 'dart:io';

Future<String> platformDeviceName() async {
  try {
    if (Platform.isWindows) return 'Windows / Desktop App';
    if (Platform.isMacOS) return 'macOS / Desktop App';
    if (Platform.isLinux) return 'Linux / Desktop App';
    if (Platform.isAndroid) return 'Android / Mobile App';
    if (Platform.isIOS) return 'iOS / Mobile App';
    return '${Platform.operatingSystem} / Desktop App';
  } catch (_) {
    return 'Unknown Device';
  }
}
