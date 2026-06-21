import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/index.dart';
import '../../repository/pengisian_modal_repository.dart';
import '../../repository/collector_repository.dart';
import '../../pref/pref.dart';
import '../../utils/user_level.dart';
import '../data_petugas/data_petugas_notifier.dart';
import '../data_petugas/data_petugas_stsrec.dart';
import '../../utils/colors.dart';
import 'package:flutter/foundation.dart';

class PengisianModalNotifier extends ChangeNotifier {
  final BuildContext context;

  PengisianModalNotifier({required this.context}) {
    _loadData();
  }

  List<DataPetugasModel> _listPetugas = [];
  List<DataPetugasModel> get listPetugas => _listPetugas;

  List<Map<String, dynamic>> _listRiwayat = [];
  List<Map<String, dynamic>> get listRiwayat => _listRiwayat;

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
  String _bprId = '';
  String _userLogin = '';
  UsersModel? _sessionUser; // untuk filter level user

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController namaPetugasCtrl = TextEditingController();
  final TextEditingController noHpCtrl = TextEditingController();
  final TextEditingController nominalCtrl = TextEditingController();

  String? selectedPetugasId;
  String? selectedPetugasNoHp;
  bool showDropdown = false;
  
  // Untuk menyimpan data setelah simpan
  Map<String, dynamic>? _lastSavedData;

  final NumberFormat rupiahFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat rupiahFormatNoSymbol = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  Future<void> _loadData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final users = await Pref().getUsers();
      _bprId = users.bprId;
      _userLogin = users.namaUsers;
      _sessionUser = users;

      await _loadPetugas();
      await _loadRiwayat();
    } catch (e) {
      errorMessage = 'Terjadi kesalahan: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPetugas() async {
    try {
      final result = await CollectorRepository.inquiryCollector(limit: 200);
      if (result['value'] == 1) {
        final List<dynamic> data = result['data'] ?? [];
        final allPetugas = data
            .map((e) => DataPetugasModel.fromJson(e as Map<String, dynamic>))
            .where((p) => DataPetugasStsrec.isAktif(p))
            .toList();
        // Filter per kode kantor untuk user biasa (lvl1)
        _listPetugas = UserLevelHelper.applyKantorFilter(
          list: allPetugas,
          users: _sessionUser,
          getKdKantor: (p) => p.kdKantor,
        );
      } else {
        errorMessage = result['message'] ?? 'Gagal memuat data petugas';
      }
    } catch (e) {
      errorMessage = 'Terjadi kesalahan saat load petugas: $e';
    }
  }

  Future<void> _loadRiwayat() async {
    try {
      final result = await PengisianModalRepository.inquiryPengisianModal(
        bprId: _bprId,
        page: 1,
        size: 100,
      );

      if (kDebugMode) {
        print('=== LOAD RIWAYAT ===');
        print('Response value: ${result['value']}');
        print('Data length: ${result['data']?.length}');
      }

      if (result['value'] == 1) {
        final List<dynamic> data = result['data'] ?? [];
        
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        _listRiwayat = data
            // 🔥 FILTER KETAT: HANYA TAMPILKAN DATA YANG BELUM DIHAPUS
            .where((item) {
              // Cek berbagai kemungkinan indikasi data sudah dihapus
              final deletedAt = item['deleted_at'];
              final deletedBy = item['deleted_by']?.toString().trim() ?? '';
              final deletedTerm = item['deleted_term']?.toString().trim() ?? '';
              
              // Jika salah satu dari ini terisi, berarti data sudah dihapus
              final isDeleted = deletedAt != null || 
                                deletedBy.isNotEmpty || 
                                deletedTerm.isNotEmpty;
              
              // Filter tanggal hari ini
              final tglTrans = (item['tgl_trans'] ?? '').toString();
              final tglDate = tglTrans.split(' ')[0];
              final isToday = tglDate == today;
              
              if (kDebugMode) {
                print('Item id: ${item['id']}, deleted_at: $deletedAt, deleted_by: $deletedBy, isDeleted: $isDeleted, isToday: $isToday');
              }
              
              // Hanya tampilkan jika belum dihapus DAN tanggal hari ini
              return !isDeleted && isToday;
            })
            .map((item) {
              final amount = (item['amount'] ?? 0).toDouble();
              return {
                'id': item['id']?.toString() ?? '',
                'no': 0,
                'namaPetugas': _getNamaPetugasByNoHp(item['nohp'] ?? ''),
                'noHp': item['nohp'] ?? '-',
                'nominal': rupiahFormat.format(amount),
                'waktu': _formatWaktu(item['tgl_trans'] ?? ''),
                'status': item['status'] ?? 'pending',
                'noreff': item['noreff'] ?? '-',
                'amount': amount,
                // Simpan juga data mentah untuk debug jika perlu
                '_raw_deleted_at': item['deleted_at'],
                '_raw_deleted_by': item['deleted_by'],
              };
            })
            .toList();
            
        if (kDebugMode) {
          print('Filtered list length: ${_listRiwayat.length}');
          // Print detail data yang tampil
          for (var item in _listRiwayat) {
            print('Displayed: id=${item['id']}, nama=${item['namaPetugas']}');
          }
        }
      } else {
        _listRiwayat = [];
      }
    } catch (e) {
      if (kDebugMode) print('Error load riwayat: $e');
      _listRiwayat = [];
    }
  }

  String _getNamaPetugasByNoHp(String noHp) {
    final found = _listPetugas.firstWhere(
      (p) => p.noHp == noHp,
      orElse: () => DataPetugasModel(),
    );
    return found.nama ?? '-';
  }

  String _formatWaktu(String tglTrans) {
    if (tglTrans.isEmpty) return '-';
    try {
      final date = DateTime.parse(tglTrans.replaceAll(' ', 'T'));
      return DateFormat('HH:mm:ss').format(date);
    } catch (_) {
      return tglTrans;
    }
  }

  List<String> getSuggestions(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _listPetugas
        .where((p) => 
            p.nama?.toLowerCase().contains(lowerQuery) == true &&
            p.transaksiKolektor == true)
        .map((p) => p.nama!)
        .toList();
  }

  void onPetugasSelected(String selectedName) {
    final found = _listPetugas.firstWhere(
      (p) => p.nama == selectedName,
      orElse: () => DataPetugasModel(),
    );
    if (found.nama != null && found.nama!.isNotEmpty) {
      selectedPetugasId = found.id;
      selectedPetugasNoHp = found.noHp;
      noHpCtrl.text = found.noHp ?? '';
    }
    showDropdown = false;
    notifyListeners();
  }

  void toggleDropdown(bool value) {
    showDropdown = value;
    notifyListeners();
  }

  void resetForm() {
    namaPetugasCtrl.clear();
    noHpCtrl.clear();
    nominalCtrl.clear();
    selectedPetugasId = null;
    selectedPetugasNoHp = null;
    showDropdown = false;
    _lastSavedData = null;
    formKey.currentState?.reset();
    notifyListeners();
  }

  String? validateNamaPetugas(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Nama Petugas wajib diisi';
    final exists = _listPetugas.any(
      (p) => p.nama == text && DataPetugasStsrec.isAktif(p),
    );
    if (!exists) return 'Pilih petugas dari dropdown yang tersedia';
    return null;
  }

  // PERUBAHAN 1: Validasi nominal harus kelipatan 100 (ratusan)
  String? validateNominal(String? v) {
    final text = (v ?? '').replaceAll(RegExp(r'[^\d]'), '').trim();
    if (text.isEmpty) return 'Nominal wajib diisi';
    final nominal = int.tryParse(text);
    if (nominal == null || nominal < 10000) return 'Minimal Rp 10.000';
    if (nominal % 100 != 0) return 'Nominal harus kelipatan 100 (contoh: 10.000, 10.500, 11.000)';
    return null;
  }

  void onNominalChanged(String value) {
    final raw = value.replaceAll(RegExp(r'[^\d]'), '');
    if (raw.isEmpty) {
      nominalCtrl.text = '';
      return;
    }
    final number = int.tryParse(raw) ?? 0;
    final formatted = rupiahFormatNoSymbol.format(number);
    nominalCtrl.text = formatted;
    nominalCtrl.selection = TextSelection.collapsed(offset: nominalCtrl.text.length);
  }

  // PERUBAHAN 2: Pop up konfirmasi dengan tombol Cetak (wajib cetak)
  Future<void> _showConfirmAndPrintDialog() async {
    final nominalRaw = nominalCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final nominal = int.tryParse(nominalRaw) ?? 0;
    final formattedNominal = rupiahFormat.format(nominal);
    final now = DateTime.now();
    final nodokumen = now.microsecondsSinceEpoch.toString();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: colorPrimary,
                child: Row(
                  children: [
                    const Icon(Icons.payment, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Konfirmasi Pengisian Modal',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 2),
                        Text('Petugas', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Periksa kembali data pengisian modal berikut:',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xffF8FAF9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffDCE3DF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow('Nama Petugas', namaPetugasCtrl.text.trim()),
                          const SizedBox(height: 8),
                          _infoRow('No HP', noHpCtrl.text.trim()),
                          const SizedBox(height: 8),
                          _infoRow('Nominal', formattedNominal),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorPrimary,
                            foregroundColor: colortextwhite,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            Navigator.pop(_);
                            await _saveAndPrint(nodokumen);
                          },
                          child: const Text('Cetak & Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndPrint(String nodokumen) async {
    if (selectedPetugasNoHp == null) {
      _showErrorDialog('Silakan pilih petugas terlebih dahulu');
      return;
    }

    isSaving = true;
    notifyListeners();

    final nominalRaw = nominalCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final nominal = double.tryParse(nominalRaw) ?? 0;

    final result = await PengisianModalRepository.addPengisianModal(
      noHp: selectedPetugasNoHp!,
      amount: nominal,
      noReff: nodokumen,
    );

    isSaving = false;
    notifyListeners();

    if (!context.mounted) return;

    if (result['value'] == 1) {
      // Simpan data untuk keperluan cetak ulang
      _lastSavedData = {
        'nama': namaPetugasCtrl.text.trim(),
        'noHp': noHpCtrl.text.trim(),
        'nominal': nominal,
        'nodokumen': nodokumen,
      };
      
      await _loadRiwayat();
      
      // Cetak struk setelah berhasil simpan
      await _printStruk(
        nama: namaPetugasCtrl.text.trim(),
        noHp: noHpCtrl.text.trim(),
        nominal: nominal.toInt(),
        nodokumen: nodokumen,
      );
      
      _showSuccessDialog('Pengisian modal berhasil!');
      resetForm();
    } else {
      _showErrorDialog(result['message'] ?? 'Gagal melakukan pengisian modal');
    }
  }

  // Method untuk cetak struk (bisa dipanggil dari mana saja)
  Future<void> _printStruk({
    required String nama,
    required String noHp,
    required int nominal,
    required String nodokumen,
  }) async {
    final tglCetak = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    final formattedNominal = rupiahFormat.format(nominal);

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
                child: pw.Column(
                  children: [
                    pw.Text(
                      'STRUK PENGISIAN MODAL',
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

              _buildInfoRow('No. Dokumen', nodokumen),
              pw.SizedBox(height: 12),
              _buildInfoRow('Nama Petugas', nama),
              pw.SizedBox(height: 12),
              _buildInfoRow('No HP', noHp),
              pw.SizedBox(height: 12),
              _buildInfoRow('Nominal', formattedNominal),
              pw.SizedBox(height: 12),
              _buildInfoRow('Tanggal', tglCetak),

              pw.SizedBox(height: 20),

              // Tanda Tangan
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.grey300
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Pejabat', style: pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 70),
                      pw.Text('$_userLogin', style: pw.TextStyle(fontSize: 8)),
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
      name: 'Struk_Pengisian_Modal_${nama.replaceAll(' ', '_')}.pdf',
    );
  }

  // Method untuk cetak ulang (print ulang)
  Future<void> printUlang(Map<String, dynamic> data) async {
    final nama = data['namaPetugas'] ?? '-';
    final noHp = data['noHp'] ?? '-';
    final nominalRaw = data['nominal']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '0';
    final nominal = int.tryParse(nominalRaw) ?? 0;
    final noreff = data['noreff'] ?? DateTime.now().microsecondsSinceEpoch.toString();

    await _printStruk(
      nama: nama,
      noHp: noHp,
      nominal: nominal,
      nodokumen: noreff,
    );
  }

  // PERUBAHAN 3: Delete data pengisian modal (menggunakan id int)
  Future<void> deleteRiwayat(Map<String, dynamic> data) async {
    final idStr = data['id']?.toString() ?? '';
    if (idStr.isEmpty) {
      _showErrorDialog('Data tidak valid untuk dihapus');
      return;
    }

    final id = int.tryParse(idStr);
    if (id == null) {
      _showErrorDialog('ID data tidak valid');
      return;
    }

    // STEP 1: Pop up input alasan hapus
    final alasan = await _showAlasanHapusDialog(data);
    if (alasan == null) return; // user batal

    // STEP 2: Pop up konfirmasi hapus
    final confirmed = await _showKonfirmasiHapusDialog(data);
    if (confirmed != true) return;

    isSaving = true;
    notifyListeners();

    final result = await PengisianModalRepository.deletePengisianModal(
      id: id,
      alasan: alasan,
    );

    isSaving = false;
    notifyListeners();

    if (!context.mounted) return;

    // STEP 3: Pop up sukses / gagal
    if (result['value'] == 1) {
      await _loadRiwayat();
      _showSuccessDialog('Data berhasil dihapus!');
    } else {
      _showErrorDialog(result['message'] ?? 'Gagal menghapus data');
    }
  }

  /// Pop up Step 1: Input alasan hapus
  Future<String?> _showAlasanHapusDialog(Map<String, dynamic> data) async {
    final alasanCtrl = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  color: colorPrimary,
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hapus Data',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pengisian Modal',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Masukkan alasan menghapus data pengisian modal untuk:',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['namaPetugas'] ?? '-',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: alasanCtrl,
                        maxLines: 3,
                        onChanged: (_) {
                          if (errorText != null) {
                            setState(() => errorText = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Tulis alasan hapus...',
                          errorText: errorText,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: colorError, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorError,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.pop(ctx, null),
                              child: const Text(
                                'Batal',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
                                final val = alasanCtrl.text.trim();
                                if (val.isEmpty) {
                                  setState(() => errorText = 'Field ini wajib diisi');
                                  return;
                                }
                                Navigator.pop(ctx, val);
                              },
                              child: const Text(
                                'Lanjutkan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pop up Step 2: Konfirmasi hapus
  Future<bool?> _showKonfirmasiHapusDialog(Map<String, dynamic> data) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: colorPrimary,
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Konfirmasi Hapus',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tindakan ini tidak dapat dibatalkan',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apakah Anda yakin ingin menghapus data pengisian modal untuk:',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['namaPetugas'] ?? '-',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorError,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Hapus',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> simpan() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedPetugasNoHp == null) {
      _showErrorDialog('Silakan pilih petugas terlebih dahulu');
      return;
    }

    // PERUBAHAN 2: Tampilkan dialog dengan tombol cetak (wajib cetak)
    await _showConfirmAndPrintDialog();
  }

  // Method untuk aksi dari drawer (print ulang atau delete)
  void openActionDrawer(Map<String, dynamic> data, GlobalKey<ScaffoldState> scaffoldKey) {
    _selectedRiwayat = data;
    scaffoldKey.currentState?.openEndDrawer();
    notifyListeners();
  }

  Map<String, dynamic>? _selectedRiwayat;
  Map<String, dynamic>? get selectedRiwayat => _selectedRiwayat;
  String? actionMode;

  void closeActionDrawer(GlobalKey<ScaffoldState> scaffoldKey) {
    actionMode = null;
    _selectedRiwayat = null;
    scaffoldKey.currentState?.closeEndDrawer();
    notifyListeners();
  }

  void pilihAksi(String? mode) {
    actionMode = mode;
    notifyListeners();
  }

  Future<void> executeAction(GlobalKey<ScaffoldState> scaffoldKey) async {
    if (_selectedRiwayat == null) return;

    if (actionMode == 'print') {
      await printUlang(_selectedRiwayat!);
      closeActionDrawer(scaffoldKey);
    } else if (actionMode == 'delete') {
      await deleteRiwayat(_selectedRiwayat!);
      closeActionDrawer(scaffoldKey);
    }
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

  void _showSuccessDialog(String message) {
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
                decoration: const BoxDecoration(color: Color(0xFFEAF3DE), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline, color: Color(0xFF3B6D11), size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Berhasil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3B6D11))),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B6D11),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  void _showErrorDialog(String message) {
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
                decoration: const BoxDecoration(color: Color(0xFFFCEBEB), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline, color: Color(0xFFA32D2D), size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Gagal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFA32D2D))),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA32D2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Future<void> refreshData() async {
    await _loadData();
  }

  int get totalNominalHariIni {
    int total = 0;
    for (var row in _listRiwayat) {
      final nominalStr = row['nominal']?.toString() ?? '0';
      final raw = nominalStr.replaceAll(RegExp(r'[^\d]'), '');
      total += int.tryParse(raw) ?? 0;
    }
    return total;
  }

  @override
  void dispose() {
    namaPetugasCtrl.dispose();
    noHpCtrl.dispose();
    nominalCtrl.dispose();
    super.dispose();
  }
}