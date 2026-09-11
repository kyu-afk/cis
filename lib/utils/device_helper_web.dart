// lib/utils/device_helper_web.dart
//
// Implementasi platformDeviceName() untuk platform web — baca navigator
// userAgent dan urai jadi format "OS / Browser" (mis. "Windows / Chrome"),
// sama seperti yang sudah dipakai untuk login_device_name kolektor/teller.
// Dipakai lewat conditional import di device_helper.dart — jangan diimpor
// langsung dari file lain.

import 'dart:html' as html;

Future<String> platformDeviceName() async {
  try {
    final ua = html.window.navigator.userAgent;
    return _parseUserAgent(ua);
  } catch (_) {
    return 'Unknown Device';
  }
}

String _parseUserAgent(String ua) {
  String os = 'Unknown OS';
  if (ua.contains('Windows')) {
    os = 'Windows';
  } else if (ua.contains('Mac OS')) {
    os = 'Mac';
  } else if (ua.contains('Android')) {
    os = 'Android';
  } else if (ua.contains('iPhone') || ua.contains('iPad')) {
    os = 'iOS';
  } else if (ua.contains('Linux')) {
    os = 'Linux';
  }

  String browser = 'Unknown Browser';
  if (ua.contains('Edg/')) {
    browser = 'Edge';
  } else if (ua.contains('OPR/') || ua.contains('Opera')) {
    browser = 'Opera';
  } else if (ua.contains('Chrome') && !ua.contains('Edg')) {
    browser = 'Chrome';
  } else if (ua.contains('Firefox')) {
    browser = 'Firefox';
  } else if (ua.contains('Safari') && !ua.contains('Chrome')) {
    browser = 'Safari';
  }

  return '$os / $browser';
}
