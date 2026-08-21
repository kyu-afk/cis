// lib/utils/limit_universal_validator.dart
//
// Validasi silang: limit min/max per Teller/Kolektor TIDAK BOLEH melebihi
// rentang yang ditetapkan di "Limit Transaksi" (batas universal, 1 baris per
// BPR — lihat module/setup/limit_transaksi). Aturan bisnis:
//   - Min Teller/Kolektor >= Min universal (gak boleh di bawah batas bawah)
//   - Max Teller/Kolektor <= Max universal (gak boleh di atas batas atas)
//   - Limit "pending" TIDAK divalidasi (dikecualikan secara eksplisit)
//
// PENCOCOKAN KATEGORI: nama field/label transaksi di form Teller/Kolektor
// TIDAK selalu sama persis dengan nama kategori universal (mis. "TARIK
// TUNAI" vs "Tarik Tunai" beda kapital; Kolektor bisa punya banyak variasi
// dinamis dari master data server seperti "PPOB Bayar", "PPOB Buku",
// "Transfer In", "Transfer Out"). Sesuai arahan: cocokkan berdasarkan APAKAH
// label MENGANDUNG kata kunci kategori universal (substring, case-
// insensitive) — bukan pencocokan string persis. "Setor Tunai" & "Tarik
// Tunai" dicek lebih dulu / spesifik supaya "Setor Tunai" gak salah ke-match
// sebagai kandidat lain yang juga mengandung kata "Tunai".
import 'package:flutter/foundation.dart';
import '../repository/setup_limit_repository.dart';

/// Kategori limit universal yang tersedia di module/setup/limit_transaksi.
/// key harus sama persis dengan field `kategori` di LimitData sana.
enum KategoriLimitUniversal { tarikTunai, setorTunai, transfer, ppob, kredit }

class _KategoriInfo {
  final KategoriLimitUniversal kategori;
  final String label; // buat pesan error
  final List<String> keywords; // dicek sbg substring, case-insensitive
  final String minKey; // field key di response inquirySetupLimit
  final String maxKey;

  const _KategoriInfo({
    required this.kategori,
    required this.label,
    required this.keywords,
    required this.minKey,
    required this.maxKey,
  });
}

// Urutan PENTING: kategori dgn keyword lebih spesifik dicek duluan, supaya
// label yg mengandung beberapa kata kunci sekaligus (jarang terjadi, tapi
// jaga-jaga) match ke kategori yg paling tepat. "Setor Tunai"/"Tarik Tunai"
// duluan sebelum kategori lain.
const List<_KategoriInfo> _kategoriList = [
  _KategoriInfo(
    kategori: KategoriLimitUniversal.setorTunai,
    label: 'Setor Tunai',
    keywords: ['setor'],
    minKey: 'limit_setor_tunai_trx_min',
    maxKey: 'limit_setor_tunai_trx_max',
  ),
  _KategoriInfo(
    kategori: KategoriLimitUniversal.tarikTunai,
    label: 'Tarik Tunai',
    keywords: ['tarik'],
    minKey: 'limit_tarik_tunai_trx_min',
    maxKey: 'limit_tarik_tunai_trx_max',
  ),
  _KategoriInfo(
    kategori: KategoriLimitUniversal.transfer,
    label: 'Transfer',
    keywords: ['transfer'],
    minKey: 'limit_transfer_trx_min',
    maxKey: 'limit_transfer_trx_max',
  ),
  _KategoriInfo(
    kategori: KategoriLimitUniversal.ppob,
    label: 'PPOB',
    keywords: ['ppob'],
    minKey: 'limit_ppob_trx_min',
    maxKey: 'limit_ppob_trx_max',
  ),
  _KategoriInfo(
    kategori: KategoriLimitUniversal.kredit,
    label: 'Kredit',
    keywords: ['kredit'],
    minKey: 'limit_byrloan_trx_min',
    maxKey: 'limit_byrloan_trx_max',
  ),
];

/// Cari kategori universal yang cocok dengan `label` (nama field/akses di
/// form Teller/Kolektor, mis. "Tarik Tunai", "TRANSFER OUT", "PPOB Bayar").
/// Return null kalau tidak ada kategori universal yang cocok (mis. "Pindah
/// Buku", "QRIS MTD" — sengaja TIDAK divalidasi, gak ada padanannya).
_KategoriInfo? _matchKategori(String label) {
  final lower = label.toLowerCase();
  for (final k in _kategoriList) {
    for (final kw in k.keywords) {
      if (lower.contains(kw)) return k;
    }
  }
  return null;
}

class LimitUniversalRange {
  final double min;
  final double max;
  const LimitUniversalRange({required this.min, required this.max});
}

class LimitUniversalValidator {
  /// Ambil batas min/max universal per kategori dari server. Dipanggil
  /// SEKALI sebelum validasi (bukan per-field), hasilnya dipakai buat semua
  /// pengecekan kategori dalam satu form. Return map kosong kalau gagal
  /// fetch (mis. offline) — pemanggil harus treat itu sebagai "gak bisa
  /// divalidasi sekarang", BUKAN "semua batas 0" (supaya gak salah tolak
  /// isian valid gara-gara gagal jaringan).
  static Future<Map<KategoriLimitUniversal, LimitUniversalRange>?> fetchRanges() async {
    try {
      final result = await SetupLimitRepository.inquirySetupLimit();
      if (result['value'] != 1) return null;
      final List<dynamic> data = result['data'] ?? [];
      if (data.isEmpty) return null;
      final row = Map<String, dynamic>.from(data.first as Map);

      double _num(dynamic v) {
        if (v is double) return v;
        if (v is int) return v.toDouble();
        if (v == null) return 0;
        return double.tryParse(v.toString()) ?? 0;
      }

      final ranges = <KategoriLimitUniversal, LimitUniversalRange>{};
      for (final k in _kategoriList) {
        ranges[k.kategori] = LimitUniversalRange(
          min: _num(row[k.minKey]),
          max: _num(row[k.maxKey]),
        );
      }
      return ranges;
    } catch (e) {
      if (kDebugMode) print('ERROR LimitUniversalValidator.fetchRanges: $e');
      return null;
    }
  }

  /// Validasi satu field limit (label + nilai min + nilai max) terhadap
  /// rentang universal yang sudah di-fetch. Return pesan error (String) kalau
  /// melanggar, atau null kalau valid / kategori-nya gak ada padanan
  /// universal / batas universal-nya 0 (berarti belum diset, gak dibatasi).
  ///
  /// `minVal`/`maxVal` boleh null (field itu gak dipakai / kosong) — gak
  /// divalidasi, konsisten dengan _validateMinMaxLimit yang sudah ada.
  static String? validateField({
    required Map<KategoriLimitUniversal, LimitUniversalRange> ranges,
    required String label,
    double? minVal,
    double? maxVal,
  }) {
    final kategori = _matchKategori(label);
    if (kategori == null) return null; // gak ada padanan universal, skip

    final range = ranges[kategori.kategori];
    if (range == null) return null;

    // Batas universal 0 berarti belum pernah diset admin -> jangan
    // membatasi (0 bukan "maksimal Rp0", itu "belum ada aturan").
    if (minVal != null && range.min > 0 && minVal < range.min) {
      return '$label: Min tidak boleh di bawah batas universal (Rp${range.min.toInt()})';
    }
    if (maxVal != null && range.max > 0 && maxVal > range.max) {
      return '$label: Max tidak boleh di atas batas universal (Rp${range.max.toInt()})';
    }
    return null;
  }
}
