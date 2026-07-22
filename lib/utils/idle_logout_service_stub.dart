// Stub untuk platform non-web (Android, iOS, desktop).
// Tidak ada beforeunload di luar browser, jadi semua no-op.

typedef VoidCallback = void Function();

void registerBeforeUnload(
  VoidCallback onLogout, {
  String? logoutUrl,
  String? authToken,
}) {}

void unregisterBeforeUnload() {}

void fireLogoutKeepalive(String url, String token) {}
