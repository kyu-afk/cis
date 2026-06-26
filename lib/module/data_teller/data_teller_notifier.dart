import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import '../../pref/pref.dart';
import '../../repository/teller_repository.dart';
import '../../repository/users_access_repository.dart';
import '../../network/network.dart';
import '../../utils/colors.dart';
import '../../utils/user_level.dart';
import 'data_teller_stsrec.dart';
import 'package:flutter/foundation.dart';

// ==================== MODEL ====================
class DataTellerModel {
  String? id;
  String? noSbb;
  String? namasbb;
  String? namaTeller;
  String? userId;
  String? password;
  String? tglKadaluarsa;
  String? kdKantor;
  String? namaKantor;
  String? status;
  String? batch;
  bool? isTransaksiDibuka;
  bool? transaksiTeller;

  DataTellerModel({
    this.id,
    this.noSbb,
    this.namasbb,
    this.namaTeller,
    this.userId,
    this.password,
    this.tglKadaluarsa,
    this.kdKantor,
    this.namaKantor,
    this.status,
    this.batch,
    this.isTransaksiDibuka,
    this.transaksiTeller,
  });

  factory DataTellerModel.fromJson(Map<String, dynamic> json) {
    String? formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      if (dateStr.contains('T')) {
        return dateStr.split('T').first;
      }
      return dateStr;
    }

    return DataTellerModel(
      id: (json['id'] ?? '').toString(),
      userId: json['userid']?.toString(),
      namaTeller: json['nama']?.toString(),
      noSbb: json['sbb_teller']?.toString(),
      namasbb: json['nama_sbb']?.toString(),
      tglKadaluarsa: formatDate(json['tanggal_expired']?.toString()),
      kdKantor: json['kd_kantor']?.toString(),
      namaKantor: json['nama_kantor']?.toString(),
      status: json['status']?.toString(),
      batch: json['batch']?.toString(),
      isTransaksiDibuka: json['transaksi_teller'] == true,
      transaksiTeller: json['transaksi_teller'] == true,
    );
  }
}

class KantorDummy {
  final String kdKantor;
  final String namaKantor;
  final String bprId;
  KantorDummy(this.kdKantor, this.namaKantor, this.bprId);

  @override
  bool operator ==(Object other) =>
      other is KantorDummy && other.kdKantor == kdKantor;
  @override
  int get hashCode => kdKantor.hashCode;
}

class FasilitasDummy {
  final String modul;
  final String menu;
  final String submenu;
  final String subsubmenu;
  final String urut;
  FasilitasDummy(this.modul, this.menu, this.submenu, this.subsubmenu, this.urut);

  @override
  bool operator ==(Object other) =>
      other is FasilitasDummy && other.modul == modul && other.menu == menu && other.submenu == submenu;
  @override
  int get hashCode => Object.hash(modul, menu, submenu);
}

// ==================== NOTIFIER ====================
class DataTellerNotifier extends ChangeNotifier {
  final BuildContext context;

  DataTellerNotifier({required this.context}) {
    _setupListeners();
    _loadProfile();
  }

  // ==================== DATA ====================
  List<DataTellerModel> _list = [];
  List<DataTellerModel> get list => _list;
  
  List<DataTellerModel> _filteredList = [];
  List<DataTellerModel> get filteredList => _filteredList;
  
  List<KantorDummy> _listKantor = [];
  List<KantorDummy> get listKantor => _listKantor;
  
  List<FasilitasDummy> _listFasilitas = [];
  List<FasilitasDummy> get listFasilitas => _listFasilitas;
  
  List<FasilitasDummy> _selectedFasilitas = [];
  List<FasilitasDummy> get selectedFasilitas => _selectedFasilitas;

  // ==================== STATE ====================
  bool isLoading = true;
  bool isSaving = false;
  bool obscure = true;
  bool isLoadingVerifikasi = false;
  bool isChangePassword = false;
  
  // Flag untuk mencegah listener mereset saat verifikasi atau mengisi form
  bool _isInternalChange = false;
  
  // Simpan nilai asli dari database untuk validasi
  String _originalNoSbb = '';
  String _originalNamaSbb = '';

  // Manual errors
  Map<String, String> _manualErrors = {};
  Map<String, String> get manualErrors => _manualErrors;

  DataTellerModel? selectedTeller;
  KantorDummy? selectedKantor;

  String bprId = '';
  String userLogin = '';
  UsersModel? _sessionUser; // untuk filter level user

  // Scroll controller
  final scrollController = ScrollController();

  // Search
  final searchCtrl = TextEditingController();
  String _searchKeyword = '';
  Timer? _debounceTimer;

  // Alasan
  final alasanCtrl = TextEditingController();

  // Form controllers
  final userIdCtrl = TextEditingController();
  final namaTellerCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final noSbbCtrl = TextEditingController();
  final namaSbbCtrl = TextEditingController();
  final tglCtrl = TextEditingController();
  final batchCtrl = TextEditingController();

  // Limit transaksi controllers
  final limitSetorTunaiCtrl = TextEditingController(); // tcode 1000
  final limitTarikTunaiCtrl = TextEditingController(); // tcode 1100
  final limitPindahBukuCtrl = TextEditingController(); // tcode 2300

  // Keys
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();

  // Drawer mode
  String? drawerMode;

  bool get isReadOnly => drawerMode == 'hapus' || drawerMode == 'blokir' || drawerMode == 'unblokir' || drawerMode == 'resetPassword';
  bool get isFormMode => drawerMode == 'tambah' || drawerMode == 'edit';

  String get drawerTitle {
    switch (drawerMode) {
      case 'tambah': return 'Tambah Data Teller';
      case 'edit': return 'Edit Data Teller';
      case 'hapus': return 'Hapus Data Teller';
      case 'blokir': return 'Blokir Teller';
      case 'unblokir': return 'Unblokir Teller';
      case 'resetPassword': return 'Reset Password Teller';
      default: return '';
    }
  }

  String get tombolUtama {
    switch (drawerMode) {
      case 'hapus': return 'Proses';
      case 'blokir': return 'Proses';
      case 'unblokir': return 'Proses';
      case 'resetPassword': return 'Reset';
      default: return 'Simpan';
    }
  }

  Color get tombolColor {
    switch (drawerMode) {
      default: return colorPrimary;
    }
  }

  int get jumlahAktif => _list.where((t) => DataTellerStsrec.isAktif(t)).length;
  int get jumlahTidakAktif => _list.length - jumlahAktif;

  // ==================== LISTENERS ====================
  void _setupListeners() {
    noSbbCtrl.addListener(_onNoSbbChanged);
  }

  void _onNoSbbChanged() {
    if (_isInternalChange || isLoadingVerifikasi) return;
    
    final newNoSbb = noSbbCtrl.text.trim();
    final oldNoSbb = _originalNoSbb;
    
    if (newNoSbb != oldNoSbb && newNoSbb.isNotEmpty) {
      _isInternalChange = true;
      namaSbbCtrl.clear();
      _isInternalChange = false;
      
      if (kDebugMode) {
        print('No SBB berubah dari "$oldNoSbb" menjadi "$newNoSbb" - Nama SBB dikosongkan');
      }
    }
  }

  // ==================== MAPPING KANTOR ====================
  String getNamaKantor(String? kdKantor) {
    if (kdKantor == null || kdKantor.isEmpty) return '-';
    final found = _listKantor.firstWhere(
      (k) => k.kdKantor == kdKantor,
      orElse: () => KantorDummy('', '', ''),
    );
    return found.namaKantor.isEmpty ? kdKantor : found.namaKantor;
  }

  // ==================== MANUAL VALIDATION ====================
  Map<String, dynamic> validateAllFieldsManually() {
    bool allValid = true;
    final errors = <String, String>{};
    String? firstErrorKey;
    
    final isTambah = drawerMode == 'tambah';
    final isEdit = drawerMode == 'edit';
    
    // User ID (hanya untuk tambah)
    if (isTambah) {
      final userIdError = _validateUserIdManual(userIdCtrl.text.trim());
      if (userIdError != null) {
        errors['userId'] = userIdError;
        allValid = false;
        if (firstErrorKey == null) firstErrorKey = 'userId';
      }
    }
    
    // Nama Teller (tambah dan edit)
    if (isTambah || isEdit) {
      final namaError = _validateNamaTellerManual(namaTellerCtrl.text.trim());
      if (namaError != null) {
        errors['namaTeller'] = namaError;
        allValid = false;
        if (firstErrorKey == null) firstErrorKey = 'namaTeller';
      }
    }
    
    // Password (tambah)
    if (isTambah) {
      final passError = _validatePasswordManual(passwordCtrl.text.trim(), true);
      if (passError != null) {
        errors['password'] = passError;
        allValid = false;
        if (firstErrorKey == null) firstErrorKey = 'password';
      }
    }
    
    // Password (edit dengan change password)
    if (isEdit && isChangePassword) {
      final passError = _validatePasswordManual(passwordCtrl.text.trim(), false);
      if (passError != null) {
        errors['password'] = passError;
        allValid = false;
        if (firstErrorKey == null) firstErrorKey = 'password';
      }
    }
    
    // No SBB (tambah dan edit)
    if (isTambah || isEdit) {
      final noSbbError = _validateNoSbbManual(noSbbCtrl.text.trim());
      if (noSbbError != null) {
        errors['noSbb'] = noSbbError;
        allValid = false;
        if (firstErrorKey == null) firstErrorKey = 'noSbb';
      }
    }
    
    // Nama SBB (tambah dan edit)
    if (isTambah || isEdit) {
      final namaSbbError = _validateNamaSbbManual(namaSbbCtrl.text.trim());
      if (namaSbbError != null) {
        errors['namaSbb'] = namaSbbError;
        allValid = false;
        if (firstErrorKey == null) firstErrorKey = 'namaSbb';
      }
    }
    
    // Tanggal Kadaluarsa (tambah dan edit)
    if (isTambah || isEdit) {
      final tglError = _validateTglManual(tglCtrl.text.trim());
      if (tglError != null) {
        errors['tgl'] = tglError;
        allValid = false;
        if (firstErrorKey == null) firstErrorKey = 'tgl';
      }
    }
    
    // Kantor (tambah dan edit)
    if (isTambah || isEdit) {
      if (selectedKantor == null) {
        errors['kantor'] = 'Pilih kantor terlebih dahulu';
        allValid = false;
        if (firstErrorKey == null) firstErrorKey = 'kantor';
      }
    }
    
    // Batch (tambah dan edit)
    if (isTambah || isEdit) {
      final batchError = _validateBatchManual(batchCtrl.text.trim());
      if (batchError != null) {
        errors['batch'] = batchError;
        allValid = false;
        if (firstErrorKey == null) firstErrorKey = 'batch';
      }
    }
    
    _manualErrors = errors;
    notifyListeners();
    
    return {'isValid': allValid, 'firstErrorKey': firstErrorKey};
  }

  String? _validateUserIdManual(String value) {
    if (value.isEmpty) {
      return 'User ID wajib diisi';
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return 'User ID tidak boleh mengandung spasi';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'User ID harus mengandung huruf';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'User ID harus mengandung angka';
    }
    if (_list.any((t) => t.userId?.toUpperCase() == value.toUpperCase())) {
      return 'User ID sudah terdaftar';
    }
    return null;
  }

  String? _validateNamaTellerManual(String value) {
    if (value.isEmpty) {
      return 'Nama teller wajib diisi';
    }
    if (RegExp(r'[!@#\$%^&*()_+={}\[\]|\\:;"<>,.?/~`]').hasMatch(value)) {
      return 'Nama tidak boleh mengandung karakter spesial';
    }
    return null;
  }

  String? _validatePasswordManual(String value, bool isRequired) {
    if (isRequired && value.isEmpty) {
      return 'Password wajib diisi';
    }
    if (value.isNotEmpty && value.length < 6) {
      return 'Minimal 6 karakter';
    }
    return null;
  }

  String? _validateNoSbbManual(String value) {
    if (value.isEmpty) {
      return 'No SBB wajib diisi';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'No SBB hanya boleh berisi angka';
    }
    final isDuplicate = _list.any((t) {
      if (drawerMode == 'edit' && t.userId == selectedTeller?.userId) return false;
      return t.noSbb == value;
    });
    if (isDuplicate) {
      return 'No SBB sudah digunakan oleh teller lain';
    }
    return null;
  }

  String? _validateNamaSbbManual(String value) {
    if (value.isEmpty) {
      return 'Nama SBB wajib diisi. Silakan klik tombol Cari untuk verifikasi No SBB terlebih dahulu';
    }
    return null;
  }

  String? _validateTglManual(String value) {
    if (value.isEmpty) {
      return 'Tanggal wajib diisi';
    }
    return null;
  }

  String? _validateBatchManual(String value) {
    if (value.isEmpty) {
      return 'Batch wajib diisi';
    }
    final isDuplicate = _list.any((t) {
      if (drawerMode == 'edit' && t.userId == selectedTeller?.userId) return false;
      return t.batch == value;
    });
    if (isDuplicate) {
      return 'Batch sudah digunakan oleh teller lain';
    }
    return null;
  }

  // ==================== DIALOG ====================
  void _showErrorDialog(String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TellerResultDialog(isSuccess: false, message: message),
    );
  }

  void _showSuccessDialog(String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TellerResultDialog(isSuccess: true, message: message),
    );
  }

  void _showInDevelopmentDialog() {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.construction,
                  size: 40,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Fitur Dalam Pengembangan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fitur reset password sedang dalam tahap pengembangan.\nMohon maaf atas ketidaknyamanannya.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorPrimary,
                    foregroundColor: colortextwhite,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(_);
                    closeDrawer();
                  },
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSbbFoundDialog({required String namaSbb, required String noSbb, required String stsrec}) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                color: colorPrimary,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SBB ditemukan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.75),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      namaSbb,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No. SBB',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                noSbb,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              stsrec.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(_),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Proses',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
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

  // ==================== VERIFIKASI SBB ====================
  Future<void> verifikasiNoSbb() async {
    final sbb = noSbbCtrl.text.trim();
    if (sbb.isEmpty) {
      _showErrorDialog('Masukkan No SBB terlebih dahulu');
      return;
    }

    _isInternalChange = true;
    isLoadingVerifikasi = true;
    notifyListeners();

    final result = await TellerRepository.inquirySbbByAccount(noRek: sbb);
    
    if (kDebugMode) {
      print('=== VERIFIKASI SBB ===');
      print('No SBB input: $sbb');
      print('Result value: ${result['value']}');
      print('Result namaSbb: ${result['namaSbb']}');
      print('======================');
    }
    
    final resultValue = result['value'];
    final namaSbb = result['namaSbb']?.toString() ?? '';
    final noSbbResult = result['noSbb']?.toString() ?? sbb;
    final stsrecResult = result['stsrec']?.toString() ?? 'AKTIF';
    final messageError = result['message']?.toString() ?? 'No SBB tidak ditemukan';
    
    if (resultValue == 1) {
      if (namaSbb.isEmpty) {
        namaSbbCtrl.clear();
        _showErrorDialog(
          result['message']?.toString() ?? 'No SBB ditemukan namun nama tidak tersedia.\nSilakan periksa kembali data SBB.',
        );
      } else {
        namaSbbCtrl.text = namaSbb;
        if (_manualErrors.containsKey('namaSbb')) {
          _manualErrors.remove('namaSbb');
        }
        if (_manualErrors.containsKey('noSbb')) {
          _manualErrors.remove('noSbb');
        }
        _showSbbFoundDialog(
          namaSbb: namaSbb,
          noSbb: noSbbResult,
          stsrec: stsrecResult,
        );
        notifyListeners();
      }
    } else {
      namaSbbCtrl.clear();
      _showErrorDialog(messageError);
    }

    isLoadingVerifikasi = false;
    _isInternalChange = false;
    notifyListeners();
  }

  // ==================== LOAD DATA ====================
  Future<void> _loadProfile() async {
    final users = await Pref().getUsers();
    _sessionUser = users;
    bprId = users.bprId;
    userLogin = users.usersId;
    await _loadData();
  }

  Future<void> _loadData() async {
    isLoading = true;
    notifyListeners();

    final result = await TellerRepository.inquiryTeller(bprId: bprId);
    if (result['value'] == 1) {
      final rawList = result['data'] as List;
      final allList = rawList
          .map((e) => DataTellerModel.fromJson(Map<String, dynamic>.from(e)))
          .where((teller) => teller.status?.toLowerCase() != 'hapus')
          .toList();

      _list = UserLevelHelper.applyKantorFilter(
        list: allList,
        users: _sessionUser,
        getKdKantor: (t) => t.kdKantor,
      );
      _applyFilter();
    } else {
      final errorMsg = result['message']?.toString() ?? 'Gagal memuat data';
      _showErrorDialog(errorMsg);
    }

    await _loadKantor();

    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadKantor() async {
    try {
      final session = await Pref().getUsers();
      final kantorResult = await UsersAccessRepository.getListKantor(
        url: NetworkURL.getListKantorAccess(),
        userId: session.usersId,
        bprId: session.bprId,
      );
      if (kantorResult['value'] == 1) {
        final List<dynamic> kantorData = kantorResult['kantor'] ?? [];
        _listKantor = kantorData.map((k) {
          final m = k as Map<String, dynamic>;
          return KantorDummy(
            (m['kd_kantor'] ?? m['kdkantor'] ?? '').toString(),
            (m['nama_kantor'] ?? m['namakantor'] ?? '').toString(),
            session.bprId,
          );
        }).toList();
      }
    } catch (_) {}
  }

  void _applyFilter() {
    final kw = _searchKeyword.trim().toLowerCase();
    if (kw.isEmpty) {
      _filteredList = List.from(_list);
    } else {
      _filteredList = _list.where((t) {
        return (t.namaTeller ?? '').toLowerCase().contains(kw) ||
               (t.userId ?? '').toLowerCase().contains(kw);
      }).toList();
    }
    const _statusOrder = {'aktif': 0, 'blokir': 1};
    _filteredList.sort((a, b) {
      final sa = _statusOrder[DataTellerStsrec.code(a)] ?? 9;
      final sb = _statusOrder[DataTellerStsrec.code(b)] ?? 9;
      if (sa != sb) return sa.compareTo(sb);
      return (a.namaTeller ?? '').toLowerCase().compareTo((b.namaTeller ?? '').toLowerCase());
    });
    notifyListeners();
  }

  void onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchKeyword = value;
      _applyFilter();
    });
  }

  Future<void> refreshList() async {
    await _loadData();
  }

  // ==================== FORM HELPERS ====================
  void resetForm() {
    selectedTeller = null;
    selectedKantor = null;
    _selectedFasilitas.clear();
    _manualErrors.clear();
    
    _isInternalChange = true;
    userIdCtrl.clear();
    namaTellerCtrl.clear();
    passwordCtrl.clear();
    noSbbCtrl.clear();
    namaSbbCtrl.clear();
    tglCtrl.clear();
    alasanCtrl.clear();
    batchCtrl.clear();
    limitSetorTunaiCtrl.clear();
    limitTarikTunaiCtrl.clear();
    limitPindahBukuCtrl.clear();
    _isInternalChange = false;
    
    _originalNoSbb = '';
    _originalNamaSbb = '';
    
    isChangePassword = false;
    obscure = true;
    
    notifyListeners();
  }

  void isiForm(DataTellerModel teller) {
    _manualErrors.clear();
    _isInternalChange = true;

    userIdCtrl.text = teller.userId ?? '';
    namaTellerCtrl.text = teller.namaTeller ?? '';
    tglCtrl.text = teller.tglKadaluarsa ?? '';
    noSbbCtrl.text = teller.noSbb ?? '';
    namaSbbCtrl.text = teller.namasbb ?? '';
    batchCtrl.text = teller.batch ?? '';
    passwordCtrl.clear();
    alasanCtrl.clear();
    isChangePassword = false;
    limitSetorTunaiCtrl.clear();
    limitTarikTunaiCtrl.clear();
    limitPindahBukuCtrl.clear();

    _originalNoSbb = teller.noSbb ?? '';
    _originalNamaSbb = teller.namasbb ?? '';

    selectedKantor = _listKantor.firstWhere(
      (k) => k.kdKantor == teller.kdKantor,
      orElse: () => _listKantor.isNotEmpty ? _listKantor.first : KantorDummy('', '', ''),
    );
    _selectedFasilitas.clear();

    _isInternalChange = false;
    notifyListeners();

    // Load existing limits from server
    if (teller.userId != null && teller.userId!.isNotEmpty) {
      _loadLimitTeller(teller.userId!);
    }
  }

  double _parseLimitNominal(String text) {
    final clean = text.trim().replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(clean) ?? 0.0;
  }

  Future<void> _saveLimitTeller(String userId) async {
    try {
      await TellerRepository.saveLimitTeller(
        userId: userId,
        limitSetorTunai: _parseLimitNominal(limitSetorTunaiCtrl.text),
        limitTarikTunai: _parseLimitNominal(limitTarikTunaiCtrl.text),
        limitPindahBuku: _parseLimitNominal(limitPindahBukuCtrl.text),
        bprId: bprId,
      );
    } catch (e) {
      if (kDebugMode) print('ERROR SAVE LIMIT TELLER: $e');
    }
  }

  Future<void> _loadLimitTeller(String userId) async {
    try {
      final result = await TellerRepository.getLimitTeller(userId: userId, bprId: bprId);
      if (result['value'] == 1) {
        final limits = result['limits'] as List<dynamic>;
        final _rupiahFmt = NumberFormat('#,###', 'id_ID');
        for (final l in limits) {
          final tcode = l['tcode']?.toString() ?? '';
          final nominal = (l['limit_nominal'] as num?)?.toDouble() ?? 0.0;
          final formatted = nominal == 0 ? '' : _rupiahFmt.format(nominal.toInt());
          if (tcode == '1000') limitSetorTunaiCtrl.text = formatted;
          if (tcode == '1100') limitTarikTunaiCtrl.text = formatted;
          if (tcode == '2300') limitPindahBukuCtrl.text = formatted;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  // ==================== DRAWER ACTIONS ====================
  void tambahTeller() {
    resetForm();
    selectedTeller = null;
    drawerMode = 'tambah';
    scaffoldKey.currentState?.openEndDrawer();
    notifyListeners();
  }

  void openDrawerForAction(DataTellerModel teller) {
    resetForm();
    selectedTeller = teller;
    isiForm(teller);
    drawerMode = 'aksi';
    scaffoldKey.currentState?.openEndDrawer();
    notifyListeners();
  }

  void pilihAksi(String mode) {
    if (selectedTeller != null) {
      isiForm(selectedTeller!);
    }
    drawerMode = mode;
    notifyListeners();
  }

  void goBackToActionMenu() {
    drawerMode = 'aksi';
    notifyListeners();
  }

  void closeDrawer() {
    drawerMode = null;
    selectedTeller = null;
    resetForm();
    scaffoldKey.currentState?.closeEndDrawer();
    notifyListeners();
  }

  void toggleChangePassword(bool? value) {
    isChangePassword = value ?? false;
    if (!isChangePassword) {
      passwordCtrl.clear();
      if (_manualErrors.containsKey('password')) {
        _manualErrors.remove('password');
        notifyListeners();
      }
    }
    notifyListeners();
  }

  void toggleObscure() {
    obscure = !obscure;
    notifyListeners();
  }

  // ==================== DETEKSI PERUBAHAN UNTUK EDIT ====================
  Map<String, Map<String, String>> _getChangesForEdit() {
    final changes = <String, Map<String, String>>{};
    
    if (selectedTeller == null) return changes;
    
    final old = selectedTeller!;
    
    if (old.namaTeller != namaTellerCtrl.text.trim()) {
      changes['Nama Teller'] = {
        'old': old.namaTeller ?? '-',
        'new': namaTellerCtrl.text.trim().isEmpty ? '-' : namaTellerCtrl.text.trim(),
      };
    }
    
    if (old.noSbb != noSbbCtrl.text.trim()) {
      changes['No SBB'] = {
        'old': old.noSbb ?? '-',
        'new': noSbbCtrl.text.trim().isEmpty ? '-' : noSbbCtrl.text.trim(),
      };
    }
    
    if (old.namasbb != namaSbbCtrl.text.trim()) {
      changes['Nama SBB'] = {
        'old': old.namasbb ?? '-',
        'new': namaSbbCtrl.text.trim().isEmpty ? '-' : namaSbbCtrl.text.trim(),
      };
    }
    
    if (old.tglKadaluarsa != tglCtrl.text.trim()) {
      changes['Tanggal Kadaluarsa'] = {
        'old': old.tglKadaluarsa ?? '-',
        'new': tglCtrl.text.trim().isEmpty ? '-' : tglCtrl.text.trim(),
      };
    }
    
    if (old.batch != batchCtrl.text.trim()) {
      changes['Batch'] = {
        'old': old.batch ?? '-',
        'new': batchCtrl.text.trim().isEmpty ? '-' : batchCtrl.text.trim(),
      };
    }
    
    final oldKantor = getNamaKantor(old.kdKantor);
    final newKantor = selectedKantor?.namaKantor ?? '-';
    if (oldKantor != newKantor) {
      changes['Kantor'] = {
        'old': oldKantor,
        'new': newKantor,
      };
    }
    
    if (isChangePassword && passwordCtrl.text.trim().isNotEmpty) {
      changes['Password'] = {
        'old': '********',
        'new': '******** (diubah)',
      };
    }

    // Limit transaksi selalu ditampilkan di konfirmasi jika diisi
    final limitSetor = limitSetorTunaiCtrl.text.trim();
    final limitTarik = limitTarikTunaiCtrl.text.trim();
    final limitPindah = limitPindahBukuCtrl.text.trim();
    if (limitSetor.isNotEmpty || limitTarik.isNotEmpty || limitPindah.isNotEmpty) {
      changes['Limit Setor Tunai'] = {'old': '-', 'new': limitSetor.isEmpty ? '0' : limitSetor};
      changes['Limit Tarik Tunai'] = {'old': '-', 'new': limitTarik.isEmpty ? '0' : limitTarik};
      changes['Limit Pindah Buku'] = {'old': '-', 'new': limitPindah.isEmpty ? '0' : limitPindah};
    }

    return changes;
  }

  // ==================== POPUP ALASAN ====================
  Future<String?> showAlasanDialog() async {
    final aksiLabel = drawerMode == 'hapus' ? 'Hapus'
        : drawerMode == 'blokir' ? 'Blokir'
        : drawerMode == 'unblokir' ? 'Unblokir' : 'Aksi';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        String? errorText;
        final alasanLocalCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setStateDialog) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_aksiIcon(), color: tombolColor, size: 22),
                    const SizedBox(width: 10),
                    Text('Alasan $aksiLabel',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  Text('Masukkan alasan untuk melakukan $aksiLabel pada teller ini.',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: alasanLocalCtrl,
                    maxLines: 3,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Tulis alasan di sini...',
                      errorText: errorText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    onChanged: (_) {
                      if (errorText != null) setStateDialog(() => errorText = null);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colortextwhite,
                          backgroundColor: colorcancel,
                          side: const BorderSide(color: Colors.transparent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(ctx, null),
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
                        onPressed: () {
                          if (alasanLocalCtrl.text.trim().isEmpty) {
                            setStateDialog(() => errorText = 'Alasan wajib diisi');
                          } else {
                            Navigator.pop(ctx, alasanLocalCtrl.text.trim());
                          }
                        },
                        child: const Text('Proses'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== POPUP KONFIRMASI (DENGAN PERBANDINGAN) ====================
  Future<bool> showKonfirmasiDialog(String alasan) async {
    final aksiLabel = drawerMode == 'hapus' ? 'menghapus'
        : drawerMode == 'blokir' ? 'memblokir'
        : drawerMode == 'unblokir' ? 'meng-unblokir'
        : drawerMode == 'edit' ? 'mengubah'
        : 'melakukan aksi pada';
    
    final isEditMode = drawerMode == 'edit';
    final changes = isEditMode ? _getChangesForEdit() : {};
    
    if (isEditMode && changes.isEmpty && !isChangePassword) {
      _showErrorDialog('Tidak ada perubahan data yang disimpan');
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 480,
          constraints: const BoxConstraints(maxHeight: 550),
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: colorPrimary,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                ),
                child: Row(children: [
                  Icon(_aksiIcon(), color: colortextwhite, size: 20),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      isEditMode ? 'Konfirmasi Perubahan' : 'Konfirmasi',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colortextwhite),
                    ),
                    const Text('Data Teller', style: TextStyle(fontSize: 12, color: colortextwhite)),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditMode 
                          ? 'Periksa kembali perubahan data teller berikut:'
                          : 'Apakah Anda yakin ingin $aksiLabel akun ini?',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    
                    if (isEditMode && changes.isNotEmpty)
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 350),
                        child: SingleChildScrollView(
                          child: Column(
                            children: changes.entries.map((entry) {
                              final label = entry.key;
                              final oldVal = entry.value['old'] ?? '-';
                              final newVal = entry.value['new'] ?? '-';
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF8FAF9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xffDCE3DF)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Sebelum',
                                                style: TextStyle(fontSize: 10, color: Colors.grey),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                oldVal,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 12),
                                          child: Icon(Icons.arrow_forward, size: 20, color: colorPrimary),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Sesudah',
                                                style: TextStyle(fontSize: 10, color: Colors.grey),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                newVal,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    
                    if (!isEditMode)
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
                            _konfirmasiRow('Nama', selectedTeller?.namaTeller ?? '-'),
                            const SizedBox(height: 6),
                            _konfirmasiRow('User ID', selectedTeller?.userId ?? '-'),
                            const SizedBox(height: 6),
                            _konfirmasiRow('No SBB', selectedTeller?.noSbb ?? '-'),
                            const SizedBox(height: 6),
                            _konfirmasiRow('Status', DataTellerStsrec.statusFor(selectedTeller)),
                            if (alasan.isNotEmpty) ...[
                              const Divider(height: 16),
                              _konfirmasiRow('Alasan', alasan),
                            ],
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colortextwhite,
                            backgroundColor: colorcancel,
                            side: const BorderSide(color: Colors.transparent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(isEditMode ? 'Batal' : 'Batal'),
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
                          child: Text(isEditMode ? 'Simpan' : 'Proses'),
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
    return result ?? false;
  }

  // ==================== POPUP KONFIRMASI KHUSUS INSERT ====================
  Future<bool> _showInsertConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: colorPrimary,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                ),
                child: Row(children: [
                  const Icon(Icons.preview, color: colortextwhite, size: 20),
                  const SizedBox(width: 10),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Konfirmasi Tambah Data',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colortextwhite)),
                    Text('Data Teller', style: TextStyle(fontSize: 12, color: colortextwhite)),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Periksa kembali data teller yang akan ditambahkan:',
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
                          _konfirmasiRow('User ID', userIdCtrl.text.trim().toUpperCase()),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Nama Teller', namaTellerCtrl.text.trim()),
                          const SizedBox(height: 6),
                          _konfirmasiRow('No SBB', noSbbCtrl.text.trim()),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Tanggal Kadaluarsa', tglCtrl.text.trim()),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Kantor', selectedKantor?.namaKantor ?? '-'),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Batch', batchCtrl.text.trim()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colortextwhite,
                            backgroundColor: colorcancel,
                            side: const BorderSide(color: Colors.transparent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(context, false),
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
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Widget _konfirmasiRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 70,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }

  IconData _aksiIcon() {
    if (drawerMode == 'hapus') return Icons.delete_outline;
    if (drawerMode == 'blokir') return Icons.block;
    if (drawerMode == 'unblokir') return Icons.lock_open;
    if (drawerMode == 'resetPassword') return Icons.lock_reset;
    return Icons.info_outline;
  }

  // ==================== EKSEKUSI AKSI ====================
  Future<void> executeAction() async {
    if (drawerMode == 'resetPassword') {
      isSaving = true;
      notifyListeners();

      final result = await TellerRepository.resetPasswordTeller(
        userId: selectedTeller?.userId ?? '',
      );

      isSaving = false;
      notifyListeners();

      if (result['value'] == 1) {
        closeDrawer();
        await _loadData();
        _showSuccessDialog('Reset password teller berhasil!');
      } else {
        _showErrorDialog(result['message']?.toString() ?? 'Terjadi kesalahan');
      }
      return;
    }
    
    if (drawerMode == 'tambah') {
      final validationResult = validateAllFieldsManually();
      if (!(validationResult['isValid'] as bool)) return;
      final confirmed = await _showInsertConfirmDialog();
      if (!confirmed) return;
      await konfirmasiAksi();
      return;
    }
    
    if (drawerMode == 'edit') {
      final validationResult = validateAllFieldsManually();
      if (!(validationResult['isValid'] as bool)) return;
      final confirmed = await showKonfirmasiDialog('');
      if (!confirmed) return;
      await konfirmasiAksi();
      return;
    }
    
    final alasan = await showAlasanDialog();
    if (alasan == null) return;
    alasanCtrl.text = alasan;
    
    final confirmed = await showKonfirmasiDialog(alasan);
    if (!confirmed) return;
    
    await konfirmasiAksi();
  }

  Future<void> konfirmasiAksi() async {
    isSaving = true;
    notifyListeners();

    Map<String, dynamic> result;

    switch (drawerMode) {
      case 'tambah':
        result = await TellerRepository.insertTeller(
          userId: userIdCtrl.text.trim().toUpperCase(),
          password: passwordCtrl.text.trim(),
          nama: namaTellerCtrl.text.trim(),
          noHp: '',
          nip: '',
          kdKantor: selectedKantor?.kdKantor ?? '',
          sbbTeller: noSbbCtrl.text.trim(),
          namaSbb: namaSbbCtrl.text.trim(),
          tanggalExpired: tglCtrl.text.trim().length > 10
              ? tglCtrl.text.trim().substring(0, 10)
              : tglCtrl.text.trim(),
          batch: batchCtrl.text.trim(),
          bprId: bprId,
        );
        if (result['value'] == 1) {
          await _saveLimitTeller(userIdCtrl.text.trim().toUpperCase());
        }
        break;
      case 'edit':
        result = await TellerRepository.updateTeller(
          id: selectedTeller!.id ?? '0',
          nama: namaTellerCtrl.text.trim(),
          noHp: '',
          nip: '',
          kdKantor: selectedKantor?.kdKantor ?? '',
          sbbTeller: noSbbCtrl.text.trim(),
          namaSbb: namaSbbCtrl.text.trim(),
          tanggalExpired: tglCtrl.text.trim().length > 10
              ? tglCtrl.text.trim().substring(0, 10)
              : tglCtrl.text.trim(),
          password: isChangePassword ? passwordCtrl.text.trim() : null,
          batch: batchCtrl.text.trim(),
          bprId: bprId,
        );
        if (result['value'] == 1 && selectedTeller?.userId != null) {
          await _saveLimitTeller(selectedTeller!.userId!);
        }
        break;
      case 'hapus':
        result = await TellerRepository.deleteTeller(
          id: selectedTeller!.id ?? '0',
          alasan: alasanCtrl.text.trim(),
        );
        break;
      case 'blokir':
        result = await TellerRepository.blokirTeller(
          id: selectedTeller!.id ?? '0',
          alasan: alasanCtrl.text.trim(),
        );
        break;
      case 'unblokir':
        result = await TellerRepository.unblokirTeller(
          id: selectedTeller!.id ?? '0',
          alasan: alasanCtrl.text.trim(),
        );
        break;
      default:
        result = {'value': 0, 'message': 'Aksi tidak dikenal'};
    }

    isSaving = false;
    notifyListeners();

    final errorMessage = result['message']?.toString() ?? 'Terjadi kesalahan';
    
    if (result['value'] == 1) {
      final msgMap = {
        'tambah': 'Teller berhasil ditambahkan!',
        'edit': 'Teller berhasil diupdate!',
        'hapus': 'Teller berhasil dihapus!',
        'blokir': 'Teller berhasil diblokir!',
        'unblokir': 'Teller berhasil di-unblokir!',
        'resetPassword': 'Reset password teller berhasil!',
      };
      closeDrawer();
      await _loadData();
      _showSuccessDialog(msgMap[drawerMode] ?? 'Berhasil!');
    } else {
      _showErrorDialog(errorMessage);
    }
  }

  bool _validateForm() {
    if (!(formKey.currentState?.validate() ?? false)) return false;
    if (selectedKantor == null) {
      _showErrorDialog('Pilih kantor terlebih dahulu');
      return false;
    }

    if (drawerMode == 'edit' && selectedTeller != null) {
      final currentNoSbb = noSbbCtrl.text.trim();
      final currentNamaSbb = namaSbbCtrl.text.trim();
      
      if (currentNoSbb != _originalNoSbb) {
        if (currentNamaSbb.isEmpty) {
          _showErrorDialog(
            'No SBB telah diubah.\n\nSilakan klik tombol "Cari" untuk memverifikasi No SBB yang baru terlebih dahulu.',
          );
          return false;
        }
        if (currentNamaSbb == _originalNamaSbb) {
          _showErrorDialog(
            'No SBB telah diubah dari "$_originalNoSbb" menjadi "$currentNoSbb",\n\ntetapi Nama SBB masih menggunakan nama lama.\n\nSilakan klik tombol "Cari" untuk memverifikasi No SBB yang baru.',
          );
          return false;
        }
      }
    }

    if (drawerMode == 'tambah' || drawerMode == 'edit') {
      final noSbb = noSbbCtrl.text.trim();
      final namaSbb = namaSbbCtrl.text.trim();
      
      if (noSbb.isNotEmpty && namaSbb.isEmpty) {
        _showErrorDialog(
          'No SBB belum diverifikasi.\n\nSilakan klik tombol "Cari" untuk memverifikasi No SBB terlebih dahulu.',
        );
        return false;
      }
    }

    if (drawerMode == 'tambah') {
      if (batchCtrl.text.trim().isEmpty) {
        _showErrorDialog('Batch wajib diisi');
        return false;
      }
      if (namaSbbCtrl.text.trim().isEmpty) {
        _showErrorDialog(
          'Nama SBB wajib diisi.\n\nSilakan klik tombol "Cari" untuk memverifikasi No SBB terlebih dahulu.',
        );
        return false;
      }
    }
    
    if (drawerMode == 'edit' && isChangePassword) {
      final pass = passwordCtrl.text.trim();
      if (pass.isEmpty) {
        _showErrorDialog('Password baru wajib diisi');
        return false;
      }
      if (pass.length < 6) {
        _showErrorDialog('Password minimal 6 karakter');
        return false;
      }
    }
    return true;
  }

  Future<void> pilihTanggal() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2090),
    );
    if (date != null) {
      tglCtrl.text = DateFormat('yyyy-MM-dd').format(date);
      if (_manualErrors.containsKey('tgl')) {
        _manualErrors.remove('tgl');
        notifyListeners();
      }
      notifyListeners();
    }
  }

  void toggleFasilitas(FasilitasDummy f) {
    if (_selectedFasilitas.contains(f)) {
      _selectedFasilitas.remove(f);
    } else {
      _selectedFasilitas.add(f);
    }
    if (_selectedFasilitas.isNotEmpty && _manualErrors.containsKey('fasilitas')) {
      _manualErrors.remove('fasilitas');
    }
    notifyListeners();
  }

  void setSelectedKantor(KantorDummy? kantor) {
    selectedKantor = kantor;
    if (kantor != null && _manualErrors.containsKey('kantor')) {
      _manualErrors.remove('kantor');
    }
    notifyListeners();
  }

  // ==================== VALIDATORS (untuk form, jika masih digunakan) ====================
  String? validateUserId(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'User ID wajib diisi';
    if (RegExp(r'\s').hasMatch(text)) return 'User ID tidak boleh mengandung spasi';
    if (!RegExp(r'[a-zA-Z]').hasMatch(text)) return 'User ID harus mengandung huruf';
    if (!RegExp(r'[0-9]').hasMatch(text)) return 'User ID harus mengandung angka';
    if (drawerMode == 'tambah' && _list.any((t) => t.userId?.toUpperCase() == text.toUpperCase())) {
      return 'User ID sudah terdaftar';
    }
    return null;
  }

  String? validateNamaTeller(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Nama teller wajib diisi';
    if (RegExp(r'[!@#\$%^&*()_+={}\[\]|\\:;"<>,.?/~`]').hasMatch(text)) {
      return 'Nama tidak boleh mengandung karakter spesial';
    }
    return null;
  }

  String? validatePassword(String? v) {
    final text = (v ?? '').trim();
    if (drawerMode == 'tambah' && text.isEmpty) return 'Password wajib diisi';
    if (drawerMode == 'edit' && isChangePassword && text.isEmpty) return 'Password baru wajib diisi';
    if (text.isNotEmpty && text.length < 6) return 'Minimal 6 karakter';
    return null;
  }

  String? validateNoSbb(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'No SBB wajib diisi';
    if (!RegExp(r'^[0-9]+$').hasMatch(text)) {
      return 'No SBB hanya boleh berisi angka';
    }
    return null;
  }

  String? validateNamaSbb(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) {
      return 'Nama SBB wajib diisi. Silakan klik tombol Cari untuk verifikasi No SBB terlebih dahulu';
    }
    return null;
  }

  String? validateTgl(String? v) =>
      (v ?? '').trim().isEmpty ? 'Tanggal wajib diisi' : null;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    scrollController.dispose();
    noSbbCtrl.removeListener(_onNoSbbChanged);
    noSbbCtrl.dispose();
    userIdCtrl.dispose();
    namaTellerCtrl.dispose();
    passwordCtrl.dispose();
    namaSbbCtrl.dispose();
    tglCtrl.dispose();
    alasanCtrl.dispose();
    batchCtrl.dispose();
    limitSetorTunaiCtrl.dispose();
    limitTarikTunaiCtrl.dispose();
    limitPindahBukuCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }
}

// ==================== RESULT DIALOG ====================
class _TellerResultDialog extends StatelessWidget {
  final bool isSuccess;
  final String message;

  const _TellerResultDialog({required this.isSuccess, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D);
    final bgColor = isSuccess ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB);
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    final title = isSuccess ? 'Berhasil' : 'Gagal';

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
            Text(
              title,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
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
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}