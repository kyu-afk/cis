import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../repository/setup_limit_repository.dart';
import '/utils/colors.dart';

// ==================== CURRENCY INPUT FORMATTER ====================
class CurrencyInputFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat('#,##0', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    final number = int.tryParse(raw) ?? 0;
    final formatted = _fmt.format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatValue(double v) {
    if (v == 0) return '';
    return _fmt.format(v.toInt());
  }
}

// ==================== MODEL ====================
class LimitData {
  final String key;
  final String keterangan;
  final String kategori;
  final TextEditingController ctrl;

  LimitData({
    required this.key,
    required this.keterangan,
    required this.kategori,
    double nilai = 0,
  }) : ctrl = TextEditingController(
          text: CurrencyInputFormatter.formatValue(nilai),
        );

  String get fieldType {
    if (key.contains('_min')) return 'min';
    if (key.contains('_max')) return 'max';
    return 'pending';
  }

  double get nilai {
    final text = ctrl.text.replaceAll(RegExp(r'[^\d]'), '').trim();
    if (text.isEmpty) return 0;
    return double.tryParse(text) ?? 0;
  }

  void setNilai(double v) {
    ctrl.text = CurrencyInputFormatter.formatValue(v);
  }

  void dispose() => ctrl.dispose();
}

// ==================== KONSTANTA ====================
const Map<String, String> _aksesKey = {
  'tarik_tunai': 'akses_tartun',
  'setor': 'akses_setor',
  'transfer': 'akses_transfer',
  'ppob': 'akses_ppob',
  'kredit': 'akses_kredit',
};

const Map<String, String> _kategoriLabel = {
  'tarik_tunai': 'Tarik Tunai',
  'setor': 'Setor Tunai',
  'transfer': 'Transfer',
  'ppob': 'PPOB',
  'kredit': 'Kredit',
};

// ==================== WIP STATE ====================
class _WipState {
  late Map<String, bool> aksesAktif;
  late List<LimitData> limits;
  late Map<String, double> originalValues;
  late Map<String, bool> originalAkses;

  _WipState({
    required this.aksesAktif,
    required this.limits,
    required this.originalValues,
    required this.originalAkses,
  });

  factory _WipState.fromMain(LimitTransaksiNotifier main) {
    final aksesCopy = Map<String, bool>.from(main._mainAksesAktif);
    
    final limitsCopy = main._mainAllLimits.map((l) => LimitData(
      key: l.key,
      keterangan: l.keterangan,
      kategori: l.kategori,
      nilai: l.nilai,
    )).toList();
    
    return _WipState(
      aksesAktif: aksesCopy,
      limits: limitsCopy,
      originalValues: Map<String, double>.from(main._mainOriginalValues),
      originalAkses: Map<String, bool>.from(main._mainOriginalAkses),
    );
  }

  void applyToMain(LimitTransaksiNotifier main) {
    main._mainAksesAktif = Map<String, bool>.from(aksesAktif);
    main._mainOriginalAkses = Map<String, bool>.from(originalAkses);
    
    for (final wipLimit in limits) {
      final mainLimit = main._mainAllLimits.firstWhere(
        (l) => l.key == wipLimit.key,
        orElse: () => throw Exception('Limit not found: ${wipLimit.key}'),
      );
      mainLimit.setNilai(wipLimit.nilai);
      main._mainOriginalValues[wipLimit.key] = wipLimit.nilai;
    }
    
    main.notifyListeners();
  }
}

// ==================== NOTIFIER ====================
class LimitTransaksiNotifier extends ChangeNotifier {
  final BuildContext context;

  LimitTransaksiNotifier({required this.context}) {
    _init();
  }

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();

  bool isLoading = true;
  bool isSaving = false;
  String? errorMsg;

  Map<String, bool> _mainAksesAktif = {
    'tarik_tunai': false,
    'setor': false,
    'transfer': false,
    'ppob': false,
    'kredit': false,
  };
  
  Map<String, double> _mainOriginalValues = {};
  Map<String, bool> _mainOriginalAkses = {};
  
  late final List<LimitData> _mainAllLimits = [
    // Tarik Tunai (Min → Max → Pending)
    LimitData(key: 'limit_tarik_tunai_trx_min', keterangan: 'Limit min per transaksi', kategori: 'tarik_tunai'),
    LimitData(key: 'limit_tarik_tunai_trx_max', keterangan: 'Limit max per transaksi', kategori: 'tarik_tunai'),
    LimitData(key: 'limit_pending_tarik_tunai', keterangan: 'Limit pending tarik tunai', kategori: 'tarik_tunai'),
    
    // Setor Tunai (Min → Max → Pending)
    LimitData(key: 'limit_setor_tunai_trx_min', keterangan: 'Limit min per transaksi', kategori: 'setor'),
    LimitData(key: 'limit_setor_tunai_trx_max', keterangan: 'Limit max per transaksi', kategori: 'setor'),
    LimitData(key: 'limit_pending_setor', keterangan: 'Limit pending setor', kategori: 'setor'),
    
    // Transfer (Min → Max → Pending)
    LimitData(key: 'limit_transfer_trx_min', keterangan: 'Limit min per transaksi', kategori: 'transfer'),
    LimitData(key: 'limit_transfer_trx_max', keterangan: 'Limit max per transaksi', kategori: 'transfer'),
    LimitData(key: 'limit_pending_trf', keterangan: 'Limit pending transfer', kategori: 'transfer'),
    
    // PPOB (Min → Max → Pending)
    LimitData(key: 'limit_ppob_trx_min', keterangan: 'Limit min per transaksi', kategori: 'ppob'),
    LimitData(key: 'limit_ppob_trx_max', keterangan: 'Limit max per transaksi', kategori: 'ppob'),
    LimitData(key: 'limit_pending_ppob', keterangan: 'Limit pending PPOB', kategori: 'ppob'),
    
    // Kredit (Min → Max → Pending)
    LimitData(key: 'limit_byrloan_trx_min', keterangan: 'Limit min per transaksi', kategori: 'kredit'),
    LimitData(key: 'limit_byrloan_trx_max', keterangan: 'Limit max per transaksi', kategori: 'kredit'),
    LimitData(key: 'limit_pending_kredit', keterangan: 'Limit pending kredit', kategori: 'kredit'),
  ];

  List<LimitData> get allLimits => _mainAllLimits;
  Map<String, bool> get aksesAktif => _mainAksesAktif;
  
  List<LimitData> getByKategori(String kategori) =>
      _mainAllLimits.where((l) => l.kategori == kategori).toList();

  List<String> get kategoriList => _aksesKey.keys.toList();

  String getKategoriLabel(String kategori) => _kategoriLabel[kategori] ?? kategori;

  List<String> get aktifKategoriList =>
      kategoriList.where((k) => _mainAksesAktif[k] == true).toList();

  List<String> get nonaktifKategoriList =>
      kategoriList.where((k) => _mainAksesAktif[k] != true).toList();

  bool isKategoriAktif(String kategori) => _mainAksesAktif[kategori] ?? false;

  _WipState? _wipState;
  bool get isEditing => _wipState != null;
  
  Map<String, bool> get wipAksesAktif => _wipState?.aksesAktif ?? {};
  List<LimitData> get wipAllLimits => _wipState?.limits ?? [];
  
  List<LimitData> getWipByKategori(String kategori) =>
      wipAllLimits.where((l) => l.kategori == kategori).toList();
  
  bool isWipKategoriAktif(String kategori) => wipAksesAktif[kategori] ?? false;

  Future<void> _init() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    isLoading = true;
    errorMsg = null;
    _mainOriginalValues.clear();
    notifyListeners();

    final result = await SetupLimitRepository.inquirySetupLimit();

    if (result['value'] == 1) {
      final List<dynamic> data = result['data'] ?? [];
      if (data.isNotEmpty) {
        _applyRow(Map<String, dynamic>.from(data.first as Map));
      }
    } else {
      errorMsg = result['message'];
    }

    isLoading = false;
    notifyListeners();
  }

  void _applyRow(Map<String, dynamic> row) {
    for (final l in _mainAllLimits) {
      final v = row[l.key];
      double val = 0;
      if (v is double) val = v;
      else if (v is int) val = v.toDouble();
      else if (v != null) val = double.tryParse(v.toString()) ?? 0;
      l.setNilai(val);
      _mainOriginalValues[l.key] = val;
    }

    for (final entry in _aksesKey.entries) {
      final raw = (row[entry.value] ?? 'N').toString().toUpperCase();
      _mainAksesAktif[entry.key] = raw == 'Y';
    }
    _mainOriginalAkses = Map<String, bool>.from(_mainAksesAktif);
    
    notifyListeners();
  }

  Future<void> refreshList() async {
    await _loadData();
  }

  void openDrawer() {
    _wipState = _WipState.fromMain(this);
    scaffoldKey.currentState?.openEndDrawer();
    notifyListeners();
  }

  void toggleAkses(String kategori, bool value) {
    if (_wipState == null) return;
    
    _wipState!.aksesAktif[kategori] = value;
    
    if (!value) {
      final limits = getWipByKategori(kategori);
      for (final l in limits) {
        l.setNilai(0);
      }
    }
    
    notifyListeners();
  }

  void closeDrawer() {
    _wipState = null;
    scaffoldKey.currentState?.closeEndDrawer();
    notifyListeners();
  }

  Map<String, Map<String, double>> _getWipLimitChanges() {
    if (_wipState == null) return {};
    
    final changes = <String, Map<String, double>>{};

    for (final wipLimit in _wipState!.limits) {
      final oldValue = _wipState!.originalValues[wipLimit.key] ?? 0;
      final newValue = wipLimit.nilai;

      if (oldValue != newValue) {
        changes[wipLimit.key] = {
          'old': oldValue,
          'new': newValue,
        };
      }
    }

    return changes;
  }

  Map<String, bool> _getWipAksesChanges() {
    if (_wipState == null) return {};
    
    final changes = <String, bool>{};
    for (final entry in _aksesKey.entries) {
      final oldValue = _wipState!.originalAkses[entry.key] ?? false;
      final newValue = _wipState!.aksesAktif[entry.key] ?? false;
      if (oldValue != newValue) {
        changes[entry.key] = newValue;
      }
    }
    return changes;
  }

  String getKeteranganByKey(String key) {
    final found = _mainAllLimits.firstWhere(
      (l) => l.key == key,
      orElse: () => LimitData(key: key, keterangan: '', kategori: ''),
    );
    return found.keterangan;
  }

  String getKategoriByKey(String key) {
    final found = _mainAllLimits.firstWhere(
      (l) => l.key == key,
      orElse: () => LimitData(key: key, keterangan: '', kategori: ''),
    );
    return found.kategori;
  }

  String formatRupiah(double value) {
    if (value == 0) return 'Rp.0';
    final angka = NumberFormat('#,##0', 'id_ID').format(value.toInt());
    return 'Rp.$angka';
  }

  Future<bool> _showConfirmDialog() async {
    if (_wipState == null) return false;
    
    final limitChanges = _getWipLimitChanges();
    final aksesChanges = _getWipAksesChanges();

    if (limitChanges.isEmpty && aksesChanges.isEmpty) {
      if (context.mounted) {
        _showInfoDialog('Informasi', 'Tidak ada perubahan yang disimpan.');
      }
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 550),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.preview, color: colorPrimary, size: 22),
                const SizedBox(width: 10),
                const Text('Konfirmasi Perubahan',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),
              const Text('Periksa kembali perubahan limit transaksi berikut:',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (aksesChanges.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xffEAF3DE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xffC0DD97)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Perubahan Status Akses',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B6D11))),
                              const SizedBox(height: 8),
                              ...aksesChanges.entries.map((entry) {
                                final kategori = entry.key;
                                final isAktif = entry.value;
                                final label = getKategoriLabel(kategori);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(children: [
                                    Icon(isAktif ? Icons.check_circle : Icons.cancel,
                                        size: 14, color: isAktif ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D)),
                                    const SizedBox(width: 6),
                                    Text('$label: ${isAktif ? "AKTIF" : "NONAKTIF"}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isAktif ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D),
                                        )),
                                  ]),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                      ...limitChanges.entries.map((entry) {
                        final key = entry.key;
                        final oldVal = entry.value['old'] ?? 0;
                        final newVal = entry.value['new'] ?? 0;
                        final keterangan = getKeteranganByKey(key);
                        final kategori = getKategoriByKey(key);
                        final kategoriLabel = getKategoriLabel(kategori);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xffF8FAF9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xffDCE3DF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(kategoriLabel,
                                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(keterangan,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Sebelum', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      Text(formatRupiah(oldVal),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Sesudah', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      Text(formatRupiah(newVal),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorPrimary)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Simpan'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    return confirmed ?? false;
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 400,
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
                    const Icon(Icons.info_outline, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('Informasi', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                    Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorPrimary,
                          foregroundColor: colortextwhite,
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showResultDialog({required bool isSuccess, required String message}) {
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
                decoration: BoxDecoration(
                  color: isSuccess ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                  color: isSuccess ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSuccess ? 'Berhasil' : 'Gagal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSuccess ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D),
                ),
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
                    backgroundColor: isSuccess ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D),
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

  Future<void> saveAll() async {
    if (_wipState == null) return;

    // Validasi manual dulu (menangkap field yang tidak terlihat di viewport)
    final List<String> errors = [];
    for (final kategori in kategoriList) {
      if (!isWipKategoriAktif(kategori)) continue;
      final limits = getWipByKategori(kategori);
      for (final l in limits) {
        if (l.fieldType == 'pending') continue;
        final raw = l.ctrl.text.replaceAll(RegExp(r'[^\d]'), '').trim();
        final val = double.tryParse(raw) ?? 0;
        if (raw.isEmpty || val <= 0) {
          errors.add('${getKategoriLabel(kategori)} — ${l.keterangan} tidak boleh nol');
        }
      }
      // Cek min < max
      final minData = limits.firstWhere((x) => x.fieldType == 'min', orElse: () => limits.first);
      final maxData = limits.firstWhere((x) => x.fieldType == 'max', orElse: () => limits.last);
      if (minData.fieldType == 'min' && maxData.fieldType == 'max') {
        final minVal = double.tryParse(minData.ctrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final maxVal = double.tryParse(maxData.ctrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        if (maxVal > 0 && minVal > 0 && maxVal < minVal) {
          errors.add('${getKategoriLabel(kategori)} — ${maxData.keterangan} tidak boleh lebih kecil dari Min');
        }
      }
    }

    if (errors.isNotEmpty) {
      if (context.mounted) {
        _showInfoDialog('Validasi Gagal', errors.join('\n'));
      }
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) return;

    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    isSaving = true;
    notifyListeners();

    double _get(String key) {
      final found = _wipState!.limits.firstWhere(
        (l) => l.key == key,
        orElse: () => LimitData(key: key, keterangan: '', kategori: ''),
      );
      return found.nilai;
    }

    final result = await SetupLimitRepository.editSetupLimit(
      limitTarikTunaiMin: _get('limit_tarik_tunai_trx_min'),
      limitSetorTunaiMin: _get('limit_setor_tunai_trx_min'),
      limitTransferMin: _get('limit_transfer_trx_min'),
      limitPpobMin: _get('limit_ppob_trx_min'),
      limitByrLoanMin: _get('limit_byrloan_trx_min'),
      limitSaldoHarian: 0,
      limitPendingSetor: _get('limit_pending_setor'),
      limitPendingKredit: _get('limit_pending_kredit'),
      limitPendingTrf: _get('limit_pending_trf'),
      limitPendingTarikTunai: _get('limit_pending_tarik_tunai'),
      limitPendingPpob: _get('limit_pending_ppob'),
      limitTarikTunaiMax: _get('limit_tarik_tunai_trx_max'),
      limitSetorTunaiMax: _get('limit_setor_tunai_trx_max'),
      limitTransferMax: _get('limit_transfer_trx_max'),
      limitPpobMax: _get('limit_ppob_trx_max'),
      limitByrLoanMax: _get('limit_byrloan_trx_max'),
      aksesTarikTunai: _wipState!.aksesAktif['tarik_tunai'] == true ? 'Y' : 'N',
      aksesSetor: _wipState!.aksesAktif['setor'] == true ? 'Y' : 'N',
      aksesTransfer: _wipState!.aksesAktif['transfer'] == true ? 'Y' : 'N',
      aksesPpob: _wipState!.aksesAktif['ppob'] == true ? 'Y' : 'N',
      aksesKredit: _wipState!.aksesAktif['kredit'] == true ? 'Y' : 'N',
    );

    isSaving = false;
    notifyListeners();

    if (!context.mounted) return;

    if (result['value'] == 1) {
      _wipState!.applyToMain(this);
      _wipState = null;
      scaffoldKey.currentState?.closeEndDrawer();
      _showResultDialog(isSuccess: true, message: 'Limit transaksi berhasil disimpan!');
    } else {
      _showResultDialog(isSuccess: false, message: result['message'] ?? 'Gagal menyimpan limit');
    }
  }

  @override
  void dispose() {
    for (final l in _mainAllLimits) l.dispose();
    super.dispose();
  }
}