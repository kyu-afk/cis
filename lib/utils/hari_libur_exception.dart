// lib/utils/hari_libur_exception.dart
//
// Daftar bpr_id yang DIKECUALIKAN dari blokir hari libur. BPR yang ada di
// sini tetap bisa login walaupun hari ini hari libur (libur_nasional,
// cuti_bersama, libur_khusus, atau hari libur mingguan dari jam kerja).
//
// Dipakai bersama oleh flow cek hari libur saat login.

const List<String> hariLiburExceptionBprIds = [
  '609999',
];

bool isHariLiburExempt(String bprId) {
  return hariLiburExceptionBprIds.contains(bprId.trim());
}
