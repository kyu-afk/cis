import 'dart:async';
import 'dart:html' as html;

// ignore: avoid_web_libraries_in_flutter

VoidCallback? _registeredCallback;
Timer? _backgroundTimer;

/// Durasi background sebelum auto-logout (3 menit).
const Duration kBackgroundTimeout = Duration(minutes: 3);

/// Daftarkan listener beforeunload + visibilitychange agar:
///   1. Logout saat tab di-close / refresh (beforeunload + pagehide).
///   2. Logout jika tab di-background / hidden selama [kBackgroundTimeout].
void registerBeforeUnload(VoidCallback onLogout) {
  unregisterBeforeUnload(); // lepas listener lama jika ada

  _registeredCallback = onLogout;

  // --- Tab close / refresh ---
  html.window.addEventListener('beforeunload', _handleBeforeUnload);
  html.window.addEventListener('pagehide', _handlePageHide);

  // --- Tab background / foreground ---
  html.document.addEventListener('visibilitychange', _handleVisibilityChange);

  // Jika saat service di-start tab sudah hidden (edge case), mulai timer
  // langsung.
  if (html.document.visibilityState == 'hidden') {
    _startBackgroundTimer();
  }
}

void unregisterBeforeUnload() {
  _cancelBackgroundTimer();

  html.window.removeEventListener('beforeunload', _handleBeforeUnload);
  html.window.removeEventListener('pagehide', _handlePageHide);
  html.document.removeEventListener('visibilitychange', _handleVisibilityChange);

  _registeredCallback = null;
}

// ── Handlers ────────────────────────────────────────────────────────────────

void _handleBeforeUnload(html.Event event) {
  _registeredCallback?.call();
}

void _handlePageHide(html.Event event) {
  _registeredCallback?.call();
}

void _handleVisibilityChange(html.Event event) {
  if (html.document.visibilityState == 'hidden') {
    // Tab berpindah ke background → mulai countdown 3 menit.
    _startBackgroundTimer();
  } else {
    // Tab kembali ke foreground sebelum timeout → batalkan countdown.
    _cancelBackgroundTimer();
  }
}

// ── Background timer helpers ─────────────────────────────────────────────────

void _startBackgroundTimer() {
  _cancelBackgroundTimer(); // pastikan tidak ada timer ganda
  _backgroundTimer = Timer(kBackgroundTimeout, _onBackgroundTimeout);
}

void _cancelBackgroundTimer() {
  _backgroundTimer?.cancel();
  _backgroundTimer = null;
}

void _onBackgroundTimeout() {
  // Tab sudah background selama kBackgroundTimeout → logout.
  _registeredCallback?.call();
}

// Needed for conditional import type compatibility
typedef VoidCallback = void Function();