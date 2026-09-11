// lib/utils/device_helper_stub.dart
//
// Fallback default — dipakai kalau platform bukan dart:io maupun dart:html
// (seharusnya tidak pernah kepakai di build normal, cuma jaga-jaga).

Future<String> platformDeviceName() async => 'Unknown Device';
