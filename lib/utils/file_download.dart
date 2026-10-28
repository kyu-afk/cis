// lib/utils/file_download.dart
//
// Download file (bytes) ke komputer user. Pola conditional import sama seperti
// device_helper.dart. Aplikasi CIS berjalan di web, jadi implementasi utamanya
// ada di file_download_web.dart.

import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart' as impl;

/// Memicu download [bytes] sebagai file bernama [fileName] di browser.
Future<void> downloadFileBytes({
  required List<int> bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) =>
    impl.downloadFileBytes(bytes: bytes, fileName: fileName, mimeType: mimeType);
