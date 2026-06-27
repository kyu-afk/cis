import 'package:flutter/material.dart';
import 'package:cis_menu/repository/setup_transaksi_repository.dart';
import 'package:cis_menu/utils/colors.dart';

class SetupTransaksiNotifier extends ChangeNotifier {
  final BuildContext context;

  SetupTransaksiNotifier({required this.context}) {
    loadData();
  }

  // ==================== LOADING STATES ====================
  bool isLoading = true;
  bool isSaving = false;
  bool isVerifying = false;
  bool showDetail = false;
  bool isEditMode = true;
  String? selectedTcode;
  String _selectedKeterangan = '';

  // ==================== FORM KEY ====================
  final GlobalKey<FormState> keyForm = GlobalKey<FormState>();

  // ==================== DATA TCODE ====================
  List<Map<String, dynamic>> tcodeList = [];

  // Data lama dari inquiry (untuk perbandingan di dialog konfirmasi)
  Map<String, dynamic>? _oldData;

  // ==================== DROPDOWN JENIS ====================
  static const Map<String, String> jenisOptions = {
    '1': 'GL',
    '2': 'Tabungan',
    '3': 'Deposito',
    '4': 'Kredit',
    '5': 'Collector',
    '6': 'Teller',
  };

  // Hanya GL (jenis='1') yang wajib & boleh isi no rekening
  static bool isNoRekRequired(String? jenis) => jenis == '1';
  static bool isNoRekDisabled(String? jenis) =>
      jenis != null && jenis.isNotEmpty && jenis != '1';

  String? selectedJenisDebit;
  String? selectedJenisKredit;

  // ==================== FORM CONTROLLERS ====================
  final TextEditingController selectedTcodeController = TextEditingController();
  final TextEditingController ketTcode    = TextEditingController();
  final TextEditingController noDebit     = TextEditingController();
  final TextEditingController namaDebit   = TextEditingController();
  final TextEditingController noKredit    = TextEditingController();
  final TextEditingController namaKredit  = TextEditingController();

  // Cek apakah item hasil inquiry benar-benar punya konfigurasi (jenis debit/kredit terisi),
  // bukan cuma row kosong/null hasil dari "Tutup".
  static bool _isItemConfigured(dynamic item) {
    if (item is! Map) return false;
    final jnsDr = (item['jns_acc_dr'] ?? '').toString().trim();
    final jnsCr = (item['jns_acc_cr'] ?? '').toString().trim();
    return jnsDr.isNotEmpty || jnsCr.isNotEmpty;
  }

  // ==================== LOAD DATA (TCODE LIST) ====================
  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    final result = await SetupTransaksiRepository.listTcode();

    if (result['value'] == 1) {
      final List<dynamic> raw = result['data'] ?? [];
      tcodeList = raw.map((e) => {
        'tcode'        : (e['tcode'] ?? '').toString(),
        'keterangan'   : (e['keterangan'] ?? '').toString(),
        'is_configured': false,
      }).toList();

      // Cek tiap tcode apakah sudah punya konfigurasi
      for (int i = 0; i < tcodeList.length; i++) {
        final checkResult = await SetupTransaksiRepository.inquirySetupTransaksi(
          trxCode: tcodeList[i]['tcode'],
        );
        if (checkResult['value'] == 1 && checkResult['data'] != null) {
          final data = checkResult['data'];
          final List<dynamic> items = data is List ? data : (data['items'] ?? data['data'] ?? []);
          if (items.isNotEmpty && _isItemConfigured(items.first)) {
            tcodeList[i]['is_configured'] = true;
          }
        }
        notifyListeners(); // update UI tiap item selesai dicek
      }
    } else {
      tcodeList = [];
      _showResultDialog(isSuccess: false, message: result['message'] ?? 'Gagal memuat data TCode');
    }

    isLoading = false;
    notifyListeners();
  }

  // ==================== PILIH TCODE ====================
  Future<void> openTcode(Map<String, dynamic> row) async {
    selectedTcode        = row['tcode'];
    _selectedKeterangan  = row['keterangan'];
    selectedTcodeController.text = row['tcode'];
    ketTcode.text        = row['keterangan'];
    showDetail           = false;
    isEditMode           = true;
    _resetForm();
    notifyListeners();

    // Inquiry data yang sudah ada
    final result = await SetupTransaksiRepository.inquirySetupTransaksi(
      trxCode: row['tcode'],
    );

    if (result['value'] == 1 && result['data'] != null) {
      final data = result['data'];
      // data bisa List atau Map tergantung respons middleware
      final List<dynamic> items = data is List ? data : (data['items'] ?? data['data'] ?? []);
      if (items.isNotEmpty && _isItemConfigured(items.first)) {
        _fillFromInquiry(items.first);
        _oldData = Map<String, dynamic>.from(items.first as Map);
        isEditMode = false; // sudah ada data → readonly dulu
        // tandai configured di list
        final idx = tcodeList.indexWhere((e) => e['tcode'] == row['tcode']);
        if (idx != -1) tcodeList[idx]['is_configured'] = true;
      } else {
        // Row ada tapi semua field null (hasil Tutup) → anggap belum dikonfigurasi
        final idx = tcodeList.indexWhere((e) => e['tcode'] == row['tcode']);
        if (idx != -1) tcodeList[idx]['is_configured'] = false;
      }
    }

    showDetail = true;
    notifyListeners();
  }

  void _fillFromInquiry(dynamic item) {
    final jnsDr = (item['jns_acc_dr'] ?? '').toString();
    final jnsCr = (item['jns_acc_cr'] ?? '').toString();
    selectedJenisDebit  = jenisOptions.containsKey(jnsDr) ? jnsDr : null;
    selectedJenisKredit = jenisOptions.containsKey(jnsCr) ? jnsCr : null;
    noDebit.text    = (item['noacc_dr']    ?? '').toString();
    namaDebit.text  = (item['nama_acc_dr'] ?? '').toString();
    noKredit.text   = (item['noacc_cr']    ?? '').toString();
    namaKredit.text = (item['nama_acc_cr'] ?? '').toString();
  }

  void enableEdit() {
    isEditMode = true;
    notifyListeners();
  }

  // ==================== TUTUP (kosongkan data & set status Y -> N) ====================
  Future<void> closeTcode() async {
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context           : context,
      barrierDismissible: false,
      builder           : (_) => _SetupTransaksiCloseConfirmDialog(
        tcode      : selectedTcode ?? '',
        keterangan : _selectedKeterangan,
      ),
    );
    if (confirmed != true) return;

    isSaving = true;
    notifyListeners();

    final result = await SetupTransaksiRepository.saveSetupTransaksi(
      trxCode    : selectedTcode ?? '',
      keterangan : _selectedKeterangan,
      data: [
        {
          'bpr_id'      : '',
          'jns_trx'     : 0,
          'noacc_dr'    : null,
          'nama_acc_dr' : null,
          'jns_acc_dr'  : null,
          'noacc_cr'    : null,
          'nama_acc_cr' : null,
          'jns_acc_cr'  : null,
        }
      ],
    );

    isSaving = false;

    if (result['value'] == 1) {
      // Kosongkan form Debet & Kredit
      _resetForm();
      isEditMode = true;

      // Set status TCODE ini kembali menjadi N (belum dikonfigurasi)
      final idx = tcodeList.indexWhere((e) => e['tcode'] == selectedTcode);
      if (idx != -1) tcodeList[idx]['is_configured'] = false;
    }

    notifyListeners();
    _showResultDialog(
      isSuccess: result['value'] == 1,
      message  : result['value'] == 1
          ? 'Konfigurasi berhasil ditutup'
          : result['message'] ?? 'Gagal menutup konfigurasi',
    );
  }

  void _resetForm() {
    selectedJenisDebit  = null;
    selectedJenisKredit = null;
    noDebit.clear();
    namaDebit.clear();
    noKredit.clear();
    namaKredit.clear();
    _oldData = null;
  }

  // ==================== VERIFIKASI ====================
  Future<void> verifyDebit() async {
    final noRek = noDebit.text.trim();
    if (noRek.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor rekening debit terlebih dahulu')),
      );
      return;
    }
    isVerifying = true;
    namaDebit.clear();
    notifyListeners();

    final result = await SetupTransaksiRepository.inquiryAccount(
      noRek : noRek,
      glJns : '1',
    );

    isVerifying = false;
    notifyListeners();

    if (!context.mounted) return;

    if (result['value'] == 1) {
      final data = result['data'];
      final nama = (data?['nama'] ?? data?['nama_rek'] ?? data?['namaRek'] ?? '').toString().trim();
      if (nama.isNotEmpty) {
        namaDebit.text = nama;
        notifyListeners();
        _showResultDialog(isSuccess: true, message: 'Rekening ditemukan:\n$nama');
      } else {
        namaDebit.clear();
        notifyListeners();
        _showResultDialog(isSuccess: false, message: 'Rekening ditemukan namun nama tidak tersedia.');
      }
    } else {
      namaDebit.clear();
      notifyListeners();
      _showResultDialog(isSuccess: false, message: result['message'] ?? 'Rekening debit tidak ditemukan');
    }
  }

  void onJenisDebitChanged(String? val) {
    selectedJenisDebit = val;
    // Jika bukan GL, kosongkan no & nama rekening
    if (isNoRekDisabled(val)) {
      noDebit.clear();
      namaDebit.clear();
    }
    notifyListeners();
  }

  void onJenisKreditChanged(String? val) {
    selectedJenisKredit = val;
    if (isNoRekDisabled(val)) {
      noKredit.clear();
      namaKredit.clear();
    }
    notifyListeners();
  }

  Future<void> verifyKredit() async {
    final noRek = noKredit.text.trim();
    if (noRek.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor rekening kredit terlebih dahulu')),
      );
      return;
    }
    isVerifying = true;
    namaKredit.clear();
    notifyListeners();

    final result = await SetupTransaksiRepository.inquiryAccount(
      noRek : noRek,
      glJns : '1',
    );

    isVerifying = false;
    notifyListeners();

    if (!context.mounted) return;

    if (result['value'] == 1) {
      final data = result['data'];
      final nama = (data?['nama'] ?? data?['nama_rek'] ?? data?['namaRek'] ?? '').toString().trim();
      if (nama.isNotEmpty) {
        namaKredit.text = nama;
        notifyListeners();
        _showResultDialog(isSuccess: true, message: 'Rekening ditemukan:\n$nama');
      } else {
        namaKredit.clear();
        notifyListeners();
        _showResultDialog(isSuccess: false, message: 'Rekening ditemukan namun nama tidak tersedia.');
      }
    } else {
      namaKredit.clear();
      notifyListeners();
      _showResultDialog(isSuccess: false, message: result['message'] ?? 'Rekening kredit tidak ditemukan');
    }
  }

  // ==================== VALIDASI ====================
  String? validateJenisDebit(String? _) {
    if (isEditMode && (selectedJenisDebit == null || selectedJenisDebit!.isEmpty)) {
      return 'Jenis Debit wajib dipilih';
    }
    return null;
  }

  String? validateNoDebit(String? value) {
    if (!isEditMode) return null;
    if (isNoRekRequired(selectedJenisDebit) && (value == null || value.trim().isEmpty)) {
      return 'No Rekening Debit wajib diisi untuk jenis GL';
    }
    return null;
  }

  String? validateJenisKredit(String? _) {
    if (isEditMode && (selectedJenisKredit == null || selectedJenisKredit!.isEmpty)) {
      return 'Jenis Kredit wajib dipilih';
    }
    return null;
  }

  String? validateNoKredit(String? value) {
    if (!isEditMode) return null;
    if (isNoRekRequired(selectedJenisKredit) && (value == null || value.trim().isEmpty)) {
      return 'No Rekening Kredit wajib diisi untuk jenis GL';
    }
    return null;
  }

  bool validateForm() {
    // Validasi manual untuk dropdown (tidak masuk Form validator)
    if (isEditMode) {
      if (selectedJenisDebit == null || selectedJenisDebit!.isEmpty) return false;
      if (selectedJenisKredit == null || selectedJenisKredit!.isEmpty) return false;

      // Jika jenis GL, nama rekening wajib sudah terisi (hasil inquiry)
      if (isNoRekRequired(selectedJenisDebit) && namaDebit.text.trim().isEmpty) {
        if (context.mounted) {
          _showResultDialog(
            isSuccess: false,
            message: 'Nama rekening Debit belum terisi.\nTekan tombol "Cari" untuk verifikasi nomor rekening terlebih dahulu.',
          );
        }
        return false;
      }
      if (isNoRekRequired(selectedJenisKredit) && namaKredit.text.trim().isEmpty) {
        if (context.mounted) {
          _showResultDialog(
            isSuccess: false,
            message: 'Nama rekening Kredit belum terisi.\nTekan tombol "Cari" untuk verifikasi nomor rekening terlebih dahulu.',
          );
        }
        return false;
      }
    }
    return keyForm.currentState?.validate() ?? false;
  }

  // ==================== CANCEL ====================
  void cancel() {
    showDetail     = false;
    selectedTcode  = null;
    _selectedKeterangan = '';
    selectedTcodeController.clear();
    ketTcode.clear();
    _resetForm();
    isEditMode = true;
    notifyListeners();
  }

  // ==================== SUBMIT ====================
  // Getter snapshot data baru (untuk dialog konfirmasi)
  Map<String, dynamic> get newDataSnapshot => {
    'jns_acc_dr'  : selectedJenisDebit ?? '',
    'noacc_dr'    : isNoRekRequired(selectedJenisDebit) ? noDebit.text.trim() : '',
    'nama_acc_dr' : isNoRekRequired(selectedJenisDebit) ? namaDebit.text.trim() : '',
    'jns_acc_cr'  : selectedJenisKredit ?? '',
    'noacc_cr'    : isNoRekRequired(selectedJenisKredit) ? noKredit.text.trim() : '',
    'nama_acc_cr' : isNoRekRequired(selectedJenisKredit) ? namaKredit.text.trim() : '',
  };

  Map<String, dynamic>? get oldData => _oldData;

  Future<void> submit() async {
    if (!validateForm()) return;

    // Tampilkan dialog konfirmasi dulu
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context           : context,
      barrierDismissible: false,
      builder           : (_) => _SetupTransaksiConfirmDialog(
        tcode      : selectedTcode ?? '',
        keterangan : _selectedKeterangan,
        oldData    : _oldData,
        newData    : newDataSnapshot,
      ),
    );
    if (confirmed != true) return;

    isSaving = true;
    notifyListeners();

    final dataItems = [
      {
        'bpr_id'      : '',          // diisi backend dari session
        'jns_trx'     : 0,
        'noacc_dr'    : isNoRekRequired(selectedJenisDebit) ? noDebit.text.trim() : null,
        'nama_acc_dr' : isNoRekRequired(selectedJenisDebit) ? namaDebit.text.trim() : null,
        'jns_acc_dr'  : selectedJenisDebit ?? '',
        'noacc_cr'    : isNoRekRequired(selectedJenisKredit) ? noKredit.text.trim() : null,
        'nama_acc_cr' : isNoRekRequired(selectedJenisKredit) ? namaKredit.text.trim() : null,
        'jns_acc_cr'  : selectedJenisKredit ?? '',
      }
    ];

    final result = await SetupTransaksiRepository.saveSetupTransaksi(
      trxCode    : selectedTcode ?? '',
      keterangan : _selectedKeterangan,
      data       : dataItems,
    );

    isSaving = false;

    if (result['value'] == 1) {
      // tandai configured di list
      final idx = tcodeList.indexWhere((e) => e['tcode'] == selectedTcode);
      if (idx != -1) tcodeList[idx]['is_configured'] = true;

      // reset state
      showDetail    = false;
      selectedTcode = null;
      _selectedKeterangan = '';
      selectedTcodeController.clear();
      ketTcode.clear();
      _resetForm();
      isEditMode = true;
    }

    notifyListeners();
    _showResultDialog(
      isSuccess: result['value'] == 1,
      message  : result['value'] == 1
          ? 'Setup transaksi berhasil disimpan!'
          : result['message'] ?? 'Gagal menyimpan setup transaksi',
    );
  }

  // ==================== DIALOG ====================
  void _showResultDialog({required bool isSuccess, required String message}) {
    if (!context.mounted) return;
    showDialog(
      context           : context,
      barrierDismissible: false,
      builder           : (_) => _SetupTransaksiResultDialog(isSuccess: isSuccess, message: message),
    );
  }

  // ==================== DISPOSE ====================
  @override
  void dispose() {
    selectedTcodeController.dispose();
    ketTcode.dispose();
    noDebit.dispose();
    namaDebit.dispose();
    noKredit.dispose();
    namaKredit.dispose();
    super.dispose();
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Confirm Dialog
// ──────────────────────────────────────────────────────────────────────────────
class _SetupTransaksiConfirmDialog extends StatelessWidget {
  final String tcode;
  final String keterangan;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic> newData;

  const _SetupTransaksiConfirmDialog({
    required this.tcode,
    required this.keterangan,
    required this.oldData,
    required this.newData,
  });

  static const Map<String, String> _jenisLabel = {
    '1': 'GL', '2': 'Tabungan', '3': 'Deposito',
    '4': 'Kredit', '5': 'Collector', '6': 'Teller',
  };

  String _jLabel(String? key) => _jenisLabel[key ?? ''] ?? (key ?? '—');
  bool   _isGL(String? key)   => key == '1';

  @override
  Widget build(BuildContext context) {
    final isNew  = oldData == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width  : 420,
        padding: const EdgeInsets.all(28),
        child  : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header strip — pakai colorPrimary seperti header page
            Container(
              width : double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color       : colorPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: colortextwhite, size: 20),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Konfirmasi Simpan',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colortextwhite)),
                  Text('TCODE $tcode — $keterangan',
                      style: const TextStyle(fontSize: 12, color: colortextwhite)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            // DEBET
            _SectionBlock(
              title  : 'Debet',
              color  : colorPrimary,
              isNew  : isNew,
              oldJenis: isNew ? null : (oldData!['jns_acc_dr'] ?? '').toString(),
              newJenis: newData['jns_acc_dr'].toString(),
              oldNoRek: isNew ? null : (oldData!['noacc_dr'] ?? '').toString(),
              newNoRek: newData['noacc_dr'].toString(),
              oldNama : isNew ? null : (oldData!['nama_acc_dr'] ?? '').toString(),
              newNama : newData['nama_acc_dr'].toString(),
              jenisLabel: _jLabel,
              isGL   : _isGL,
            ),
            const SizedBox(height: 14),

            // KREDIT
            _SectionBlock(
              title  : 'Kredit',
              color  : colorPrimary,
              isNew  : isNew,
              oldJenis: isNew ? null : (oldData!['jns_acc_cr'] ?? '').toString(),
              newJenis: newData['jns_acc_cr'].toString(),
              oldNoRek: isNew ? null : (oldData!['noacc_cr'] ?? '').toString(),
              newNoRek: newData['noacc_cr'].toString(),
              oldNama : isNew ? null : (oldData!['nama_acc_cr'] ?? '').toString(),
              newNama : newData['nama_acc_cr'].toString(),
              jenisLabel: _jLabel,
              isGL   : _isGL,
            ),

            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorcancel,
                    foregroundColor: colortextwhite,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorPrimary,
                    foregroundColor: colortextwhite,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Close (Tutup) Confirm Dialog — style box sama dengan dialog konfirmasi lain
// ──────────────────────────────────────────────────────────────────────────────
class _SetupTransaksiCloseConfirmDialog extends StatelessWidget {
  final String tcode;
  final String keterangan;

  const _SetupTransaksiCloseConfirmDialog({
    required this.tcode,
    required this.keterangan,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width  : 420,
        padding: const EdgeInsets.all(28),
        child  : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header strip — pakai colorcancel karena ini aksi destruktif
            Container(
              width : double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color       : colorcancel,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.lock_outline, color: colortextwhite, size: 20),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Konfirmasi Tutup Konfigurasi',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colortextwhite)),
                  Text('TCODE $tcode — $keterangan',
                      style: const TextStyle(fontSize: 12, color: colortextwhite)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            Container(
              padding   : const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color       : const Color(0xFFF8FAF9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDCE3DF), width: 0.5),
              ),
              child: const Text(
                'Data Debet & Kredit untuk TCODE ini akan dikosongkan dan statusnya '
                'akan berubah menjadi belum dikonfigurasi (N).\n\n'
                'Tindakan ini langsung tersimpan ke server dan tidak dapat dibatalkan. Lanjutkan?',
                style: TextStyle(fontSize: 13, color: Color(0xFF2C2C2A)),
              ),
            ),

            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2C2C2A),
                    side: const BorderSide(color: Color(0xFFDCE3DF)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorcancel,
                    foregroundColor: colortextwhite,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Section block (Debet / Kredit) dalam dialog konfirmasi
// ──────────────────────────────────────────────────────────────────────────────
class _SectionBlock extends StatelessWidget {
  final String   title;
  final Color    color;
  final bool     isNew;
  final String?  oldJenis;
  final String   newJenis;
  final String?  oldNoRek;
  final String   newNoRek;
  final String?  oldNama;
  final String   newNama;
  final String Function(String?) jenisLabel;
  final bool   Function(String?) isGL;

  const _SectionBlock({
    required this.title,
    required this.color,
    required this.isNew,
    required this.oldJenis,
    required this.newJenis,
    required this.oldNoRek,
    required this.newNoRek,
    required this.oldNama,
    required this.newNama,
    required this.jenisLabel,
    required this.isGL,
  });

  @override
  Widget build(BuildContext context) {
    final bool showNoRekOld = isGL(oldJenis);
    final bool showNoRekNew = isGL(newJenis);
    final bool showNoRekRow = showNoRekOld || showNoRekNew;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
          if (isNew) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3DE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Baru', style: TextStyle(fontSize: 10, color: Color(0xFF3B6D11), fontWeight: FontWeight.w500)),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Container(
          padding   : const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color       : const Color(0xFFF8FAF9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDCE3DF), width: 0.5),
          ),
          child: Column(
            children: [
              // Jenis
              _CompareRow(
                label  : 'Jenis',
                oldVal : isNew ? null : jenisLabel(oldJenis),
                newVal : jenisLabel(newJenis),
                isNew  : isNew,
              ),
              // No Rek (hanya tampil kalau salah satu sisi GL)
              if (showNoRekRow) ...[
                const SizedBox(height: 6),
                _CompareRow(
                  label  : 'No rek',
                  oldVal : isNew ? null : (showNoRekOld ? oldNoRek : ''),
                  newVal : showNoRekNew ? newNoRek : '',
                  isNew  : isNew,
                  emptyDash: true,
                ),
                const SizedBox(height: 6),
                _CompareRow(
                  label  : 'Nama rek',
                  oldVal : isNew ? null : (showNoRekOld ? oldNama : ''),
                  newVal : showNoRekNew ? newNama : '',
                  isNew  : isNew,
                  emptyDash: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Single compare row: [label] [old] → [new]
// ──────────────────────────────────────────────────────────────────────────────
class _CompareRow extends StatelessWidget {
  final String  label;
  final String? oldVal;   // null berarti isNew mode
  final String  newVal;
  final bool    isNew;
  final bool    emptyDash;

  const _CompareRow({
    required this.label,
    required this.oldVal,
    required this.newVal,
    required this.isNew,
    this.emptyDash = false,
  });

  bool get _changed => !isNew && (oldVal ?? '') != newVal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
        ),
        // Nilai lama (skip kalau mode baru)
        if (!isNew) ...[
          Expanded(child: _ValBox(text: oldVal ?? '', empty: emptyDash && (oldVal ?? '').isEmpty)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('→', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ),
        ],
        // Nilai baru
        Expanded(
          child: _ValBox(
            text     : newVal,
            changed  : _changed,
            isNew    : isNew,
            empty    : emptyDash && newVal.isEmpty,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Single value box
// ──────────────────────────────────────────────────────────────────────────────
class _ValBox extends StatelessWidget {
  final String text;
  final bool   changed;
  final bool   isNew;
  final bool   empty;

  const _ValBox({
    required this.text,
    this.changed = false,
    this.isNew   = false,
    this.empty   = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg     = (changed || isNew) ? const Color(0xFFEAF3DE) : const Color(0xFFFFFFFF);
    final Color border = (changed || isNew) ? const Color(0xFF97C459)  : const Color(0xFFDCE3DF);
    final Color fg     = empty
        ? const Color(0xFFB4B2A9)
        : (changed || isNew) ? const Color(0xFF27500A) : const Color(0xFF2C2C2A);

    return Container(
      padding   : const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color       : bg,
        borderRadius: BorderRadius.circular(6),
        border      : Border.all(color: border, width: 0.5),
      ),
      child: Text(
        empty ? '—' : text,
        style   : TextStyle(fontSize: 13, color: fg, fontStyle: empty ? FontStyle.italic : FontStyle.normal),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
class _SetupTransaksiResultDialog extends StatelessWidget {
  final bool isSuccess;
  final String message;

  const _SetupTransaksiResultDialog({required this.isSuccess, required this.message});

  @override
  Widget build(BuildContext context) {
    final color   = isSuccess ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D);
    final bgColor = isSuccess ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB);
    final icon    = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    final title   = isSuccess ? 'Berhasil' : 'Gagal';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 420,
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
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}