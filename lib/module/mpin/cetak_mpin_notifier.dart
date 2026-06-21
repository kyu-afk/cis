import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../repository/collector_repository.dart';
import '../../module/data_petugas/data_petugas_notifier.dart';  // TAMBAHKAN IMPORT
import '/utils/colors.dart';

class CetakMpinNotifier extends ChangeNotifier {
  final BuildContext context;

  CetakMpinNotifier({required this.context});

  // ==================== LOADING STATES ====================
  bool isSearching = false;
  bool isPrinting = false;
  bool showResult = false;
  int refreshKey = 0;

  // ==================== FORM KEY ====================
  final GlobalKey<FormState> keyForm = GlobalKey<FormState>();

  // ==================== FORM CONTROLLERS (INPUT) ====================
  final TextEditingController namaPetugasInput = TextEditingController();

  // ==================== FORM CONTROLLERS (RESULT) ====================
  final TextEditingController namaPetugasResult = TextEditingController();
  final TextEditingController noHpResult = TextEditingController();
  final TextEditingController nipResult = TextEditingController();
  final TextEditingController noSbbPetugasResult = TextEditingController();
  final TextEditingController namaSbbResult = TextEditingController();

  // Data petugas yang dipilih
  String _collectorId = '';
  String _noSbb = '';
  String _kdKantor = '';
  bool _alreadyPrinted = false;

  // MPIN yang akan dicetak
  String _decryptedMpin = '';
  String _namaPetugas = '';
  String _tanggalCetak = '';

  /// ID petugas yang sudah berhasil dicetak MPIN-nya.
  /// Digunakan untuk menyembunyikan petugas tersebut dari hasil pencarian
  /// sehingga tidak bisa dipilih dan dicetak ulang.
  final Set<String> excludedCollectorIds = {};

  // ==================== KONVERSI ANGKA KE KATA ====================
  String _angkaKeKata(String angka) {
    final Map<String, String> kata = {
      '0': 'nol',
      '1': 'satu',
      '2': 'dua',
      '3': 'tiga',
      '4': 'empat',
      '5': 'lima',
      '6': 'enam',
      '7': 'tujuh',
      '8': 'delapan',
      '9': 'sembilan',
    };
    
    final List<String> result = [];
    for (int i = 0; i < angka.length; i++) {
      result.add(kata[angka[i]] ?? angka[i]);
    }
    return result.join(' ');
  }

  // ==================== DECRYPT MPIN ====================
  String decryptMpin(String encrypted) {
    final reversed = String.fromCharCodes(encrypted.runes.toList().reversed);
    final result = StringBuffer();
    for (int i = 0; i < reversed.length; i++) {
      final digit = int.parse(reversed[i]);
      final decryptedDigit = (digit + 3) % 10;
      result.write(decryptedDigit);
    }
    return result.toString();
  }

  // ==================== FORMAT TANGGAL ====================
  String _getFormattedDate() {
    final now = DateTime.now();
    final day = _padWithZero(now.day);
    final month = _padWithZero(now.month);
    final year = now.year;
    final hour = _padWithZero(now.hour);
    final minute = _padWithZero(now.minute);
    final second = _padWithZero(now.second);
    return '$day-$month-$year $hour:$minute:$second';
  }

  String _padWithZero(int value) => value.toString().padLeft(2, '0');

  // ==================== PETUGAS DIPILIH DARI DROPDOWN (TAMBAHKAN INI) ====================
  void onPetugasSelected(DataPetugasModel petugas) {
    _collectorId = petugas.id ?? '';
    _kdKantor = petugas.kdKantor ?? '';
    _noSbb = petugas.noSbb ?? '';
    
    // Cek status cetak dari mpin_cetak (perlu ditambahkan ke model)
    // Sementara default false, biar API yang menentukan
    _alreadyPrinted = false;

    namaPetugasResult.text = petugas.nama ?? '';
    noHpResult.text = petugas.noHp ?? '';
    nipResult.text = petugas.nip ?? '';
    noSbbPetugasResult.text = petugas.noSbb ?? '';
    namaSbbResult.text = petugas.namaSbb ?? '';
    
    showResult = true;
    notifyListeners();
  }

  // ==================== CETAK MPIN ====================
  Future<void> cetakMpin() async {
    if (_alreadyPrinted) {
      _showInfoDialog(
        title: 'Informasi',
        message: 'MPIN petugas ini sudah pernah dicetak sebelumnya dan tidak dapat dicetak ulang.',
        isSuccess: false,
      );
      return;
    }

    if (_collectorId.isEmpty || _noSbb.isEmpty || _kdKantor.isEmpty) {
      _showInfoDialog(
        title: 'Peringatan',
        message: 'Data petugas belum lengkap',
        isSuccess: false,
      );
      return;
    }

    final confirmed = await _showConfirmCetakDialog();
    if (!confirmed) return;

    isPrinting = true;
    notifyListeners();

    final result = await CollectorRepository.cetakMpin(
      collectorId: _collectorId,
      noSbb: _noSbb,
      kdKantor: _kdKantor,
    );

    isPrinting = false;
    notifyListeners();

    if (!context.mounted) return;

    if (result['value'] == 1) {
      final encryptedMpin = result['mpin']?.toString() ?? '';

      if (encryptedMpin.isNotEmpty) {
        excludedCollectorIds.add(_collectorId);
        _decryptedMpin = decryptMpin(encryptedMpin);
        _namaPetugas = namaPetugasResult.text;
        _tanggalCetak = _getFormattedDate();

        await _generateAndPrintPdf();

        _showSuccessDialog();
      } else {
        _showInfoDialog(
          title: 'Gagal',
          message: 'MPIN tidak ditemukan dalam response',
          isSuccess: false,
        );
      }
    } else {
      _showInfoDialog(
        title: 'Gagal',
        message: result['message']?.toString().isNotEmpty == true
            ? result['message']
            : 'Cetak MPIN gagal, silakan coba lagi.',
        isSuccess: false,
      );
    }
  }

  // ==================== GENERATE PDF DAN PRINT ====================
  Future<void> _generateAndPrintPdf() async {
    final pdf = pw.Document();
    final mpinDalamKata = _angkaKeKata(_decryptedMpin);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'MPIN PETUGAS',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Divider(height: 1, color: PdfColors.black),
              pw.SizedBox(height: 24),

              _buildInfoRow('Nama Petugas', _namaPetugas),
              pw.SizedBox(height: 12),
              _buildInfoRow('No HP', noHpResult.text),
              pw.SizedBox(height: 12),
              _buildInfoRow('NIP', nipResult.text),
              pw.SizedBox(height: 12),
              _buildInfoRow('No SBB', noSbbPetugasResult.text),
              pw.SizedBox(height: 12),

              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Container(
                  width: 400,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: PdfColors.black),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'MPIN ANDA',
                        style: pw.TextStyle(fontSize: 12, color: PdfColors.black),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        mpinDalamKata.toLowerCase(),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.normal,
                          letterSpacing: 2,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'Segera ganti MPIN demi keamanan',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.black,
                  ),
                ),
              ),

              pw.SizedBox(height: 32),

              pw.Column(
                children: [
                  pw.Divider(height: 1),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text(
                      'Dicetak pada: $_tanggalCetak',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.black),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Cetak_MPIN_${_namaPetugas.replaceAll(' ', '_')}.pdf',
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.black),
          ),
        ),
        pw.Text(': ', style: pw.TextStyle(fontSize: 12, color: PdfColors.black)),
        pw.Text(
          value.isEmpty ? '-' : value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  void _showSuccessDialog() {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF3DE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.print,
                  color: Color(0xFF3B6D11),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cetak MPIN Berhasil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B6D11),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'MPIN berhasil dicetak untuk petugas $_namaPetugas',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B6D11),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(_);
                    reset();
                  },
                  child: const Text(
                    'Selesai',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void reset() {
    namaPetugasInput.clear();
    _clearResult();
    excludedCollectorIds.clear();
    refreshKey++;
    notifyListeners();
  }

  void _clearResult() {
    namaPetugasResult.clear();
    noHpResult.clear();
    nipResult.clear();
    noSbbPetugasResult.clear();
    namaSbbResult.clear();
    _collectorId = '';
    _noSbb = '';
    _kdKantor = '';
    _alreadyPrinted = false;
    _decryptedMpin = '';
    _namaPetugas = '';
    showResult = false;
  }

  Future<bool> _showConfirmCetakDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.print, color: colorPrimary, size: 22),
                const SizedBox(width: 10),
                const Text('Konfirmasi Cetak MPIN',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),
              const Text(
                'Apakah Anda yakin ingin mencetak MPIN untuk petugas ini?',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAF9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffDCE3DF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRowMini('Nama', namaPetugasResult.text),
                    const SizedBox(height: 6),
                    _infoRowMini('No HP', noHpResult.text),
                    const SizedBox(height: 6),
                    _infoRowMini('NIP', nipResult.text),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colortextwhite,
                      backgroundColor: colorcancel,
                      side: const BorderSide(color: Colors.transparent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorPrimary,
                      foregroundColor: colortextwhite,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Cetak'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  void _showInfoDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    if (!context.mounted) return;
    final color = isSuccess ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D);
    final bgColor = isSuccess ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB);
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(_),
                  child: const Text('OK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRowMini(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    namaPetugasInput.dispose();
    namaPetugasResult.dispose();
    noHpResult.dispose();
    nipResult.dispose();
    noSbbPetugasResult.dispose();
    namaSbbResult.dispose();
    super.dispose();
  }
}