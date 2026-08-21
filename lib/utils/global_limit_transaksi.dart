import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../repository/setup_limit_repository.dart';

/// Kategori limit universal yang dikonfigurasi di halaman "Limit Transaksi"
/// (lib/module/setup/limit_transaksi). Semua jenis transaksi turunan
/// (di Data Teller, Data Petugas/Kolektor, dst) dipetakan ke salah satu
/// kategori ini lewat keyword matching pada labelnya, biar tetap cocok
/// walau daftar tcode-nya dinamis (bisa nambah/berkurang kapan saja).
enum KategoriLimitGlobal { tarikTunai, setor, transfer, ppob, kredit }

class _RangeLimit {
  final double min;
  final double max;
  const _RangeLimit(this.min, this.max);
}

class GlobalLimitTransaksi {
  final Map<KategoriLimitGlobal, _RangeLimit> _ranges;

  const GlobalLimitTransaksi._(this._ranges);

  static final NumberFormat _rupiahFmt = NumberFormat('#,###', 'id_ID');


  static KategoriLimitGlobal? matchKategori(String label) {
    final l = label.toLowerCase();

    if (l.contains('tarik')) return KategoriLimitGlobal.tarikTunai;
    if (l.contains('setor')) return KategoriLimitGlobal.setor;
    // "Pindah Buku" dianggap bagian dari Transfer (sama seperti mapping
    // middleware lama tcode 2300 -> limit_transfer_trx_*).
    if (l.contains('transfer') || l.contains('pindah buku') || l.contains('pindah_buku')) {
      return KategoriLimitGlobal.transfer;
    }
    if (l.contains('ppob')) return KategoriLimitGlobal.ppob;
    if (l.contains('kredit') || l.contains('pinjaman') || l.contains('loan')) {
      return KategoriLimitGlobal.kredit;
    }
    return null;
  }

  static double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }


  static Future<GlobalLimitTransaksi?> fetch() async {
    try {
      final result = await SetupLimitRepository.inquirySetupLimit();
      if (result['value'] != 1) return null;

      final data = result['data'];
      if (data is! List || data.isEmpty) return null;

      final row = data.first;
      if (row is! Map) return null;

      final ranges = <KategoriLimitGlobal, _RangeLimit>{
        KategoriLimitGlobal.tarikTunai: _RangeLimit(
          _parseNum(row['limit_tarik_tunai_trx_min']),
          _parseNum(row['limit_tarik_tunai_trx_max']),
        ),
        KategoriLimitGlobal.setor: _RangeLimit(
          _parseNum(row['limit_setor_tunai_trx_min']),
          _parseNum(row['limit_setor_tunai_trx_max']),
        ),
        KategoriLimitGlobal.transfer: _RangeLimit(
          _parseNum(row['limit_transfer_trx_min']),
          _parseNum(row['limit_transfer_trx_max']),
        ),
        KategoriLimitGlobal.ppob: _RangeLimit(
          _parseNum(row['limit_ppob_trx_min']),
          _parseNum(row['limit_ppob_trx_max']),
        ),
        KategoriLimitGlobal.kredit: _RangeLimit(
          _parseNum(row['limit_byrloan_trx_min']),
          _parseNum(row['limit_byrloan_trx_max']),
        ),
      };

      return GlobalLimitTransaksi._(ranges);
    } catch (e) {
      if (kDebugMode) print('ERROR FETCH GLOBAL LIMIT TRANSAKSI: $e');
      return null;
    }
  }

  static String _formatRupiah(double v) => 'Rp ${_rupiahFmt.format(v.toInt())}';

  String? validate({
    required String label,
    required double nilaiMin,
    required double nilaiMax,
  }) {
    final kategori = matchKategori(label);
    if (kategori == null) return null;

    final range = _ranges[kategori];
    if (range == null) return null;


    if (range.min > 0 && nilaiMin > 0 && nilaiMin < range.min) {
      return 'Min tidak boleh di bawah limit transaksi yang ditentukan (${_formatRupiah(range.min)})';
    }

    if (range.max > 0 && nilaiMax > 0 && nilaiMax > range.max) {
      return 'Max tidak boleh melebihi limit transaksi yang ditentukan (${_formatRupiah(range.max)})';
    }

    return null;
  }
}