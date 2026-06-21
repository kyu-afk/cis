import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ─── Web-only: daftarkan listener beforeunload + visibilitychange ─────────────
// Menggunakan dart:html agar tidak crash di non-web build.
// ignore: avoid_web_libraries_in_flutter
import 'idle_logout_service_web.dart'
    if (dart.library.io) 'idle_logout_service_stub.dart' as platform;

/// Durasi idle (tanpa aktivitas apapun) sebelum auto-logout.
const Duration kIdleTimeout = Duration(minutes: 5);

/// Durasi tab di-background / hidden sebelum auto-logout.
/// Didefinisikan di idle_logout_service_web.dart (kBackgroundTimeout = 3 menit).
/// Konstanta ini hanya untuk referensi di sisi Flutter.
const Duration kBackgroundTimeout = Duration(minutes: 3);

/// Callback yang dipanggil saat idle timeout, tab di-close, atau
/// tab terlalu lama di background.
typedef LogoutCallback = Future<void> Function();

/// Service untuk:
///   1. Auto-logout setelah [kIdleTimeout] tanpa aktivitas pengguna.
///   2. Auto-logout saat tab browser di-close (hanya web).
///   3. Auto-logout jika tab di-background / hidden selama [kBackgroundTimeout]
///      tanpa kembali ke foreground (hanya web).
///
/// Cara pakai:
///   - Panggil [IdleLogoutService.start] saat user masuk ke MenuPage.
///   - Panggil [IdleLogoutService.stop] saat dispose / user manual logout.
///   - Wrap widget utama dengan [IdleDetector] agar setiap interaksi
///     mereset timer idle.
class IdleLogoutService {
  IdleLogoutService._();

  static Timer? _timer;
  static LogoutCallback? _onLogout;

  /// Mulai memantau idle dan (di web) tab close + background.
  /// [onLogout] dipanggil bila salah satu kondisi terpenuhi.
  static void start(LogoutCallback onLogout) {
    _onLogout = onLogout;
    _resetTimer();

    // Web: pasang listener beforeunload + visibilitychange.
    if (kIsWeb) {
      platform.registerBeforeUnload(_triggerLogout);
    }

    if (kDebugMode) {
      print('[IdleLogout] Service started — '
          'idle: $kIdleTimeout, background: $kBackgroundTimeout');
    }
  }

  /// Stop semua timer dan hapus listener.
  static void stop() {
    _timer?.cancel();
    _timer = null;
    _onLogout = null;

    if (kIsWeb) {
      platform.unregisterBeforeUnload();
    }

    if (kDebugMode) print('[IdleLogout] Service stopped');
  }

  /// Reset countdown idle — dipanggil setiap kali ada aktivitas user.
  static void resetTimer() {
    if (_onLogout == null) return; // service belum di-start
    _resetTimer();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  static void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(kIdleTimeout, _onTimerFired);
  }

  static void _onTimerFired() {
    if (kDebugMode) print('[IdleLogout] Idle timeout — triggering logout');
    _triggerLogout();
  }

  static void _triggerLogout() {
    final cb = _onLogout;
    stop(); // stop dulu agar tidak double-fire
    cb?.call();
  }
}

/// Widget yang mendeteksi semua gesture/pointer dan mereset timer idle.
/// Bungkus konten utama yang mau dipantau (misal: Scaffold body).
class IdleDetector extends StatelessWidget {
  final Widget child;

  const IdleDetector({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown:   (_) => IdleLogoutService.resetTimer(),
      onPointerMove:   (_) => IdleLogoutService.resetTimer(),
      onPointerSignal: (_) => IdleLogoutService.resetTimer(), // scroll wheel
      child: child,
    );
  }
}