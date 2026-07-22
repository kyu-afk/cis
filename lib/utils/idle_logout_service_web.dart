import 'dart:async';
import 'dart:html' as html;

// ignore: avoid_web_libraries_in_flutter

const String _apiKey =
    String.fromEnvironment('MIDDLEWARE_CIS_API_KEY', defaultValue: 'rahasia');

VoidCallback? _registeredCallback;
Timer? _backgroundTimer;
String? _logoutUrl;
String? _authToken;

/// Durasi background sebelum auto-logout (3 menit).
const Duration kBackgroundTimeout = Duration(minutes: 3);

/// Daftarkan listener beforeunload + visibilitychange agar:
///   1. Logout saat tab di-close / refresh (beforeunload + pagehide).
///   2. Logout jika tab di-background / hidden selama [kBackgroundTimeout].
void registerBeforeUnload(
  VoidCallback onLogout, {
  String? logoutUrl,
  String? authToken,
}) {
  unregisterBeforeUnload();

  _registeredCallback = onLogout;
  _logoutUrl = logoutUrl;
  _authToken = authToken;

  html.window.addEventListener('beforeunload', _handleBeforeUnload);
  html.window.addEventListener('pagehide', _handlePageHide);
  html.document.addEventListener('visibilitychange', _handleVisibilityChange);

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
  _logoutUrl = null;
  _authToken = null;
}

/// Kirim POST logout dengan fetch keepalive — request tetap terkirim saat
/// tab ditutup/refresh (browser tidak membatalkan keepalive request).
void fireLogoutKeepalive(String url, String token) {
  if (url.isEmpty || token.isEmpty) return;

  try {
    html.window.fetch(
      url,
      {
        'method': 'POST',
        'keepalive': true,
        'headers': {
          'Authorization': 'Bearer $token',
          'X-API-Key': _apiKey,
          'Content-Type': 'application/json',
        },
      },
    );
  } catch (_) {
    // Best-effort saat tab unload — abaikan error.
  }
}

String? _resolveAuthToken() {
  if (_authToken != null && _authToken!.isNotEmpty) {
    return _authToken;
  }
  final fromStorage = html.window.localStorage['flutter.auth_token'];
  if (fromStorage != null && fromStorage.isNotEmpty) {
    return fromStorage;
  }
  return null;
}

void _fireKeepaliveLogoutIfPossible() {
  final url = _logoutUrl;
  final token = _resolveAuthToken();
  if (url != null && url.isNotEmpty && token != null && token.isNotEmpty) {
    fireLogoutKeepalive(url, token);
  }
}

// ── Handlers ────────────────────────────────────────────────────────────────

void _handleBeforeUnload(html.Event event) {
  _fireKeepaliveLogoutIfPossible();
  _registeredCallback?.call();
}

void _handlePageHide(html.Event event) {
  _fireKeepaliveLogoutIfPossible();
  _registeredCallback?.call();
}

void _handleVisibilityChange(html.Event event) {
  if (html.document.visibilityState == 'hidden') {
    _startBackgroundTimer();
  } else {
    _cancelBackgroundTimer();
  }
}

// ── Background timer helpers ─────────────────────────────────────────────────

void _startBackgroundTimer() {
  _cancelBackgroundTimer();
  _backgroundTimer = Timer(kBackgroundTimeout, _onBackgroundTimeout);
}

void _cancelBackgroundTimer() {
  _backgroundTimer?.cancel();
  _backgroundTimer = null;
}

void _onBackgroundTimeout() {
  _registeredCallback?.call();
}

typedef VoidCallback = void Function();
