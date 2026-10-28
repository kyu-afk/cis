// lib/utils/file_download_stub.dart
// Fallback untuk platform non-web (CIS dipakai sebagai web app).

Future<void> downloadFileBytes({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('Download file hanya didukung di versi web CIS.');
}
