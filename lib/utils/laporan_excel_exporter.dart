// lib/utils/laporan_excel_exporter.dart
//
// Export "Laporan Transaksi Kolektor" (harian) dan "Histori Transaksi
// Kolektor" (keseluruhan) ke file Excel (.xlsx).
//
// Nama file:
//   Harian      -> Laporan_Harian_Kolektor_<NAMA>_<yyyyMMdd>_<HHmmss>.xlsx
//   Keseluruhan -> Laporan_Kolektor_<NAMA>_<yyyyMMdd>_<HHmmss>.xlsx
// (tanggal + jam saat file di-download, angka semua)

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/transaksi_model.dart';
import 'file_download.dart';

class LaporanExcelExporter {
  static const _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Bersihkan nama untuk dipakai di nama file.
  static String _safeName(String s) {
    final cleaned = s
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'Kolektor' : cleaned;
  }

  static String buildFileName({
    required bool harian,
    required String namaKolektor,
    DateTime? now,
  }) {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(now ?? DateTime.now());
    final prefix = harian ? 'Laporan_Harian_Kolektor' : 'Laporan_Kolektor';
    return '${prefix}_${_safeName(namaKolektor)}_$stamp.xlsx';
  }

  /// [harian] true  -> Laporan harian, [tanggal] = tanggal hari itu.
  /// [harian] false -> Laporan keseluruhan, [tanggal] = filter tanggal
  ///                   (null = semua tanggal).
  /// Return: nama file yang di-download.
  static Future<String> export({
    required bool harian,
    required String namaKolektor,
    required List<TransaksiModel> data,
    required String Function(TransaksiModel) labelTransaksi,
    required String Function(String?) labelStatus,
    DateTime? tanggal,
    String statusFilter = 'SEMUA',
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Laporan';
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
    final sheet = excel[sheetName];

    final now = DateTime.now();
    final judul = harian
        ? 'LAPORAN HARIAN TRANSAKSI KOLEKTOR'
        : 'LAPORAN TRANSAKSI KOLEKTOR';
    final tanggalLabel = harian
        ? DateFormat('dd/MM/yyyy').format(tanggal ?? now)
        : (tanggal != null
            ? DateFormat('dd/MM/yyyy').format(tanggal)
            : 'Semua tanggal');

    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final labelStyle = CellStyle(bold: true);
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#D9E2F3'),
      horizontalAlign: HorizontalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    void put(int col, int row, CellValue v, [CellStyle? style]) {
      final c = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      c.value = v;
      if (style != null) c.cellStyle = style;
    }

    // ── Kepala laporan ──
    put(0, 0, TextCellValue(judul), titleStyle);
    put(0, 1, TextCellValue('Kolektor'), labelStyle);
    put(1, 1, TextCellValue(': $namaKolektor'));
    put(0, 2, TextCellValue('Tanggal'), labelStyle);
    put(1, 2, TextCellValue(': $tanggalLabel'));
    put(0, 3, TextCellValue('Status'), labelStyle);
    put(1, 3, TextCellValue(': $statusFilter'));
    put(0, 4, TextCellValue('Dicetak'), labelStyle);
    put(1, 4,
        TextCellValue(': ${DateFormat('dd/MM/yyyy HH:mm:ss').format(now)}'));

    // ── Header tabel ──
    const headers = [
      'No',
      'Tanggal Transaksi',
      'Transaksi',
      'Status',
      'Nama',
      'No Rekening',
      'Nilai',
    ];
    const headerRow = 6;
    for (var i = 0; i < headers.length; i++) {
      put(i, headerRow, TextCellValue(headers[i]), headerStyle);
    }

    // ── Isi ──
    final rupiahStyle = CellStyle(
      numberFormat: NumFormat.custom(formatCode: '#,##0'),
      horizontalAlign: HorizontalAlign.Right,
    );
    double total = 0;
    for (var i = 0; i < data.length; i++) {
      final t = data[i];
      final r = headerRow + 1 + i;
      final nilai = double.tryParse(t.jumlah ?? '');
      if (nilai != null) total += nilai;

      put(0, r, IntCellValue(i + 1));
      put(1, r, TextCellValue(t.tglTrans ?? '-'));
      put(2, r, TextCellValue(labelTransaksi(t)));
      put(3, r, TextCellValue(labelStatus(t.status)));
      put(
          4,
          r,
          TextCellValue(
              (t.namaNasabah != null && t.namaNasabah!.isNotEmpty)
                  ? t.namaNasabah!
                  : '-'));
      // No rekening disimpan sebagai teks supaya tidak jadi notasi ilmiah.
      put(5, r, TextCellValue(t.norekening ?? '-'));
      if (nilai != null) {
        put(6, r, DoubleCellValue(nilai), rupiahStyle);
      } else {
        put(6, r, TextCellValue(t.jumlah ?? '-'));
      }
    }

    // ── Baris total ──
    final totalRow = headerRow + 1 + data.length;
    put(5, totalRow, TextCellValue('TOTAL'), labelStyle);
    put(
        6,
        totalRow,
        DoubleCellValue(total),
        CellStyle(
            bold: true,
            numberFormat: NumFormat.custom(formatCode: '#,##0'),
            horizontalAlign: HorizontalAlign.Right));

    // ── Lebar kolom ──
    const widths = [6.0, 20.0, 22.0, 16.0, 30.0, 22.0, 16.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Gagal membuat file Excel.');
    }

    final fileName =
        buildFileName(harian: harian, namaKolektor: namaKolektor, now: now);
    await downloadFileBytes(
        bytes: bytes, fileName: fileName, mimeType: _xlsxMime);
    return fileName;
  }
}
