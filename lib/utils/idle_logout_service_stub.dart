// Stub untuk platform non-web (Android, iOS, desktop).
// Tidak ada beforeunload di luar browser, jadi semua no-op.

typedef VoidCallback = void Function();

void registerBeforeUnload(VoidCallback onLogout) {}
void unregisterBeforeUnload() {}
