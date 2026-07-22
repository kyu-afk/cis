import 'package:cis_menu/repository/collector_repository.dart';
import 'package:cis_menu/repository/modal_kolektor_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../pref/pref.dart';

class ModalKolektorNotifier extends ChangeNotifier {
  final BuildContext context;
  ModalKolektorNotifier({required this.context}) {
    _load();
  }

  bool isLoading = true;
  bool isSaving = false;
  String? errorMsg;

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> _allPetugas = [];

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();
  final searchCtrl = TextEditingController();
  final noHpCtrl = TextEditingController();
  final nominalCtrl = TextEditingController();
  final keteranganCtrl = TextEditingController();

  String? selectedPetugasHp;
  String? selectedPetugasNama;
  bool showDropdown = false;

  // Untuk action drawer
  Map<String, dynamic>? selectedItem;

  final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  Future<void> _load() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      final resPetugas = await CollectorRepository.inquiryCollector(limit: 200);
      if (resPetugas['value'] == 1) {
        _allPetugas = List<Map<String, dynamic>>.from(resPetugas['data'] ?? []);
      }

      final resModal = await ModalKolektorRepository.inquiry();
      if (resModal['value'] == 1) {
        items = List<Map<String, dynamic>>.from(resModal['data'] ?? []);
      } else {
        errorMsg = resModal['message'];
      }
    } catch (e) {
      errorMsg = 'Gagal memuat data: $e';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => _load();

  // ── TypeAhead ──────────────────────────────────────────────────────────────
  List<String> getSuggestions(String q) {
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    return _allPetugas
        .where((p) {
          final nama = (p['nama'] ?? '').toString().toLowerCase();
          final hp = (p['nohp'] ?? '').toString();
          return nama.contains(lower) || hp.contains(lower);
        })
        .map((p) => '${p['nama']} (${p['nohp']})')
        .take(8)
        .toList();
  }

  void onPetugasSelected(String suggestion) {
    final match = _allPetugas.firstWhere(
      (p) => '${p['nama']} (${p['nohp']})' == suggestion,
      orElse: () => {},
    );
    if (match.isNotEmpty) {
      selectedPetugasHp = match['nohp']?.toString() ?? '';
      selectedPetugasNama = match['nama']?.toString() ?? '';
      noHpCtrl.text = selectedPetugasHp ?? '';
      searchCtrl.text = suggestion;
    }
    showDropdown = false;
    notifyListeners();
  }

  void toggleDropdown(bool val) {
    showDropdown = val;
    notifyListeners();
  }

  void onNominalChanged(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) { nominalCtrl.clear(); notifyListeners(); return; }
    final number = int.tryParse(digits) ?? 0;
    final formatted = NumberFormat('#,###', 'id_ID').format(number);
    nominalCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    notifyListeners();
  }

  double get nominalValue {
    final digits = nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(digits) ?? 0;
  }

  // ── Form ──────────────────────────────────────────────────────────────────
  void openAdd() {
    _resetForm();
    scaffoldKey.currentState?.openEndDrawer();
  }

  void _resetForm() {
    selectedPetugasHp = null;
    selectedPetugasNama = null;
    searchCtrl.clear();
    noHpCtrl.clear();
    nominalCtrl.clear();
    keteranganCtrl.clear();
    showDropdown = false;
  }

  void closeDrawer() {
    _resetForm();
    selectedItem = null;
    scaffoldKey.currentState?.closeEndDrawer();
    notifyListeners();
  }

  Future<void> simpan() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedPetugasHp == null) {
      _snack('Pilih kolektor terlebih dahulu', isError: true);
      return;
    }
    if (nominalValue <= 0) {
      _snack('Nominal harus lebih dari 0', isError: true);
      return;
    }
    isSaving = true;
    notifyListeners();
    try {
      // PATCH: tangkap nilai form ke variabel lokal SEBELUM closeDrawer() dipanggil,
      // karena closeDrawer() -> _resetForm() mengosongkan selectedPetugasNama/
      // selectedPetugasHp/nominalCtrl. Sebelumnya struk pertama selalu tercetak
      // kosong karena _printStruk() membaca nilai yang sudah direset.
      final cetakNama = selectedPetugasNama ?? '';
      final cetakNoHp = selectedPetugasHp ?? '';
      final cetakNominal = nominalValue;
      final cetakKeterangan = keteranganCtrl.text.trim();

      final res = await ModalKolektorRepository.add(
        petugasHp: selectedPetugasHp!,
        petugasNama: selectedPetugasNama ?? '',
        nominal: nominalValue,
        keterangan: keteranganCtrl.text.trim(),
      );
      if (res['value'] == 1) {
        closeDrawer();
        await _load();
        _snack('Modal berhasil ditambahkan', isError: false);
        await _printStruk(
          nama: cetakNama,
          noHp: cetakNoHp,
          nominal: cetakNominal,
          keterangan: cetakKeterangan,
          nodokumen: DateTime.now().microsecondsSinceEpoch.toString(),
        );
      } else {
        _snack(res['message'] ?? 'Gagal menyimpan', isError: true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
    isSaving = false;
    notifyListeners();
  }

  // ── Action drawer (hapus) ─────────────────────────────────────────────────
  void openActionDrawer(Map<String, dynamic> item) {
    selectedItem = item;
    scaffoldKey.currentState?.openEndDrawer();
    notifyListeners();
  }

  Future<void> hapus() async {
    if (selectedItem == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Modal'),
        content: Text('Hapus modal untuk ${selectedItem!['petugas_nama']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await ModalKolektorRepository.delete(id: selectedItem!['id'] as int);
    if (res['value'] == 1) {
      closeDrawer();
      await _load();
      _snack('Data berhasil dihapus', isError: false);
    } else {
      _snack(res['message'] ?? 'Gagal menghapus', isError: true);
    }
  }

  String fmtNominal(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    return fmt.format(n);
  }

  String fmtStatus(String? s) => s == 'DIBERIKAN' ? 'Diberikan' : 'Menunggu';

  // ── Cetak Struk ──────────────────────────────────────────────────────────
  Future<void> _printStruk({
    required String nama,
    required String noHp,
    required double nominal,
    required String keterangan,
    required String nodokumen,
  }) async {
    final tglCetak = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    final formattedNominal = fmt.format(nominal);
    final session = await Pref().getUsers();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'STRUK MODAL KOLEKTOR',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Divider(height: 1, color: PdfColors.black),
              pw.SizedBox(height: 24),
              _buildInfoRow('No. Dokumen', nodokumen),
              pw.SizedBox(height: 12),
              _buildInfoRow('Nama Kolektor', nama),
              pw.SizedBox(height: 12),
              _buildInfoRow('No HP', noHp),
              pw.SizedBox(height: 12),
              _buildInfoRow('Nominal', formattedNominal),
              if (keterangan.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                _buildInfoRow('Keterangan', keterangan),
              ],
              pw.SizedBox(height: 12),
              _buildInfoRow('Tanggal', tglCetak),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 200, height: 1, color: PdfColors.grey300),
                      pw.SizedBox(height: 8),
                      pw.Text('Disetujui oleh', style: pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 70),
                      pw.Text(session.namaUsers, style: pw.TextStyle(fontSize: 8)),
                      pw.Text('_____________________', style: pw.TextStyle(fontSize: 10)),
                    ],
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
      name: 'Struk_Modal_Kolektor_${nama.replaceAll(' ', '_')}.pdf',
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(fontSize: 12, color: PdfColors.black))),
        pw.Text(': ', style: pw.TextStyle(fontSize: 12, color: PdfColors.black)),
        pw.Text(value.isEmpty ? '-' : value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  /// Cetak ulang struk dari item yang sudah ada di daftar
  Future<void> printUlang(Map<String, dynamic> item) async {
    await _printStruk(
      nama: item['petugas_nama'] ?? '-',
      noHp: item['petugas_hp'] ?? '-',
      nominal: item['nominal'] is num ? (item['nominal'] as num).toDouble() : double.tryParse(item['nominal']?.toString() ?? '') ?? 0,
      keterangan: item['keterangan'] ?? '',
      nodokumen: item['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
    );
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }
}