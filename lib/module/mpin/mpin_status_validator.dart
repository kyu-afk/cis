import '../data_petugas/data_petugas_notifier.dart';

/// Validasi status MPIN kolektor untuk tiap menu MPIN.
///
/// Setiap fungsi mengembalikan:
///  - `null`   -> kolektor BOLEH diproses di menu tersebut
///  - `String` -> pesan error yang ditampilkan ke user (kolektor TIDAK diproses)
///
/// Status MPIN ditentukan dari dua field:
///  - `mpin`       : kosong = belum digenerate
///  - `mpinCetak`  : 'Y' = sudah dicetak, 'N' = belum dicetak
class MpinStatusValidator {
  MpinStatusValidator._();

  static bool _sudahGenerate(DataPetugasModel p) => (p.mpin ?? '').isNotEmpty;
  static bool _sudahCetak(DataPetugasModel p) =>
      (p.mpinCetak ?? 'N').toUpperCase() == 'Y';

  static const String _msgSudahDicetak =
      'MPIN sudah pernah dicetak, gunakan menu Regenerate MPIN untuk membuat MPIN baru.';
  static const String _msgBelumDicetak =
      'MPIN sudah digenerate, silakan cetak di menu Cetak MPIN.';
  static const String _msgBelumGenerate =
      'MPIN belum digenerate, silakan generate terlebih dahulu di menu Generate atau Regenerate MPIN.';

  /// Menu Generate MPIN: hanya untuk kolektor yang MPIN-nya masih kosong.
  static String? forGenerate(DataPetugasModel p) {
    if (!_sudahGenerate(p)) return null;
    return _sudahCetak(p) ? _msgSudahDicetak : _msgBelumDicetak;
  }

  /// Menu Cetak MPIN: hanya untuk kolektor yang sudah generate tapi belum cetak.
  static String? forCetak(DataPetugasModel p) {
    if (!_sudahGenerate(p)) return _msgBelumGenerate;
    if (_sudahCetak(p)) return _msgSudahDicetak;
    return null;
  }

  /// Menu Regenerate MPIN: hanya untuk kolektor yang MPIN-nya sudah dicetak.
  static String? forRegenerate(DataPetugasModel p) {
    if (!_sudahGenerate(p)) return _msgBelumGenerate;
    if (!_sudahCetak(p)) return _msgBelumDicetak;
    return null;
  }

  /// Menu Reset MPIN: hanya untuk kolektor yang MPIN-nya terkunci.
  static String? forReset(DataPetugasModel p) {
    final locked = (p.mpinLock ?? '').toUpperCase() == 'Y';
    return locked ? null : 'MPIN kolektor ini tidak dalam kondisi terkunci, tidak perlu di-reset.';
  }
}
