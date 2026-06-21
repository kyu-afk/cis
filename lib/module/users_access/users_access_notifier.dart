import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/fasilitas_model.dart';
import '../../models/index.dart';
import '../../network/network.dart';
import '../../pref/pref.dart';
import '../../repository/users_access_repository.dart';
import '../../utils/colors.dart';
import '../../utils/user_level.dart';
import 'users_access_stsrec.dart';

class KantorItem {
  final String kdKantor;
  final String namaKantor;
  KantorItem(this.kdKantor, this.namaKantor);

  @override
  String toString() => '$kdKantor - $namaKantor';
}

class UsersAccessNotifier extends ChangeNotifier {
  final BuildContext context;

  UsersAccessNotifier({required this.context}) {
    _init();
  }

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();
  final scrollController = ScrollController();

  List<UsersAccessModel> _list = [];
  List<UsersAccessModel> get list => _list;

  List<UsersAccessModel> _filteredList = [];
  List<UsersAccessModel> get filteredList => _filteredList;

  List<KantorItem> _listKantor = [];
  List<KantorItem> get listKantor => _listKantor;

  List<FasilitasModel> _listFasilitas = [];
  List<FasilitasModel> get listFasilitas => _listFasilitas;

  List<FasilitasModel> _selectedFasilitas = [];
  List<FasilitasModel> get selectedFasilitas => _selectedFasilitas;

  bool isLoading = true;
  bool isSaving = false;
  bool obscurePass = true;
  bool isChangePassword = false;

  UsersAccessModel? selectedUser;
  KantorItem? selectedKantor;
  String? drawerMode;

  final searchCtrl = TextEditingController();
  String _searchKeyword = '';
  Timer? _debounceTimer;

  final ctrlUserId = TextEditingController();
  final ctrlNama = TextEditingController();
  final ctrlPass = TextEditingController();
  final ctrlTgl = TextEditingController();

  UsersModel? _sessionUser;

  // Manual errors
  Map<String, String> _manualErrors = {};
  Map<String, String> get manualErrors => _manualErrors;

  bool get isReadOnly => drawerMode == 'hapus' || drawerMode == 'blokir' || drawerMode == 'bukaBlokir' || drawerMode == 'forceLogout' || drawerMode == 'resetPassword';

  String get drawerTitle {
    switch (drawerMode) {
      case 'tambah': return 'Tambah User Access';
      case 'edit': return 'Edit User Access';
      case 'hapus': return 'Hapus User Access';
      case 'blokir': return 'Blokir User Access';
      case 'bukaBlokir': return 'Buka Blokir User Access';
      case 'forceLogout': return 'Force Logout User';
      case 'resetPassword': return 'Reset Password User';
      default: return 'Pilih Aksi';
    }
  }

  String get tombolLabel {
    switch (drawerMode) {
      case 'hapus': return 'Proses';
      case 'blokir': return 'Proses';
      case 'bukaBlokir': return 'Proses';
      case 'forceLogout': return 'Proses';
      case 'resetPassword': return 'Reset';
      default: return 'Simpan';
    }
  }

  String getNamaKantor(String? kdKantor) {
    if (kdKantor == null || kdKantor.isEmpty) return '-';
    final found = _listKantor.firstWhere(
      (k) => k.kdKantor == kdKantor,
      orElse: () => KantorItem('', ''),
    );
    return found.namaKantor.isEmpty ? kdKantor : found.namaKantor;
  }

  int get jumlahAktif => _list.where((u) => UsersAccessStsrec.isAktif(u)).length;
  int get jumlahTidakAktif => _list.length - jumlahAktif;

  Future<void> _init() async {
    _sessionUser = await Pref().getUsers();
    await loadAll();
  }

  Future<void> loadAll() async {
    if (_sessionUser == null) return;
    isLoading = true;
    notifyListeners();

    await Future.wait([
      _loadUsers(),
      loadKantor(),
      loadFasilitas(),
    ]);

    isLoading = false;
    notifyListeners();
  }

  bool get _canSeeAllKantor => UserLevelHelper.canSeeAllKantor(_sessionUser);

  Future<void> _loadUsers() async {
    final u = _sessionUser!;
    try {
      final result = await UsersAccessRepository.inquiryUsers(
        url: NetworkURL.inquiryUsers(),
        bprId: u.bprId,
        filterUserid: '',
        filterNamauser: '',
        page: 1,
        limit: 500,
      );
      if (result['value'] == 1) {
        final data = result['data'] as List<dynamic>? ?? [];
        final allUsers = data.map((e) => UsersAccessModel.fromJson(e)).toList();

        final visibleUsers = allUsers
            .where((u) => (u.kdkantor ?? '') != '000')
            .toList();

        _list = _canSeeAllKantor
            ? visibleUsers
            : visibleUsers.where((u) =>
                u.kdkantor == _sessionUser!.kodeKantor ||
                u.userid?.toUpperCase() == _sessionUser!.usersId.toUpperCase()
              ).toList();
      } else {
        _list = [];
      }
    } catch (e) {
      _list = [];
    }
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    final kw = _searchKeyword.trim().toLowerCase();
    if (kw.isEmpty) {
      _filteredList = List.from(_list);
    } else {
      _filteredList = _list.where((u) {
        return (u.userid ?? '').toLowerCase().contains(kw) || (u.namauser ?? '').toLowerCase().contains(kw);
      }).toList();
    }
    const _statusOrder = {'A': 0, 'B': 1, 'C': 2};
    _filteredList.sort((a, b) {
      final sa = _statusOrder[UsersAccessStsrec.code(a)] ?? 9;
      final sb = _statusOrder[UsersAccessStsrec.code(b)] ?? 9;
      if (sa != sb) return sa.compareTo(sb);
      return (a.namauser ?? '').toLowerCase().compareTo((b.namauser ?? '').toLowerCase());
    });
    notifyListeners();
  }

  void onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _searchKeyword = value;
      _applyFilter();
    });
  }

  Future<void> refreshList() async {
    await _loadUsers();
  }

  Future<void> loadKantor() async {
    final u = _sessionUser!;
    try {
      final result = await UsersAccessRepository.getListKantor(
        url: NetworkURL.getListKantorAccess(),
        userId: u.usersId,
        bprId: u.bprId,
      );
      if (result['value'] == 1) {
        final raw = result['kantor'] as List<dynamic>? ?? [];
        _listKantor = raw.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return KantorItem(
            (m['kd_kantor'] ?? m['kdkantor'] ?? '').toString(),
            (m['nama_kantor'] ?? m['namakantor'] ?? '').toString(),
          );
        }).toList();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loadFasilitas() async {
    final u = _sessionUser!;
    try {
      final result = await UsersAccessRepository.getListFasilitas(
        url: NetworkURL.getListFasilitas(),
        userId: u.usersId,
        bprId: u.bprId,
      );
      if (result['value'] == 1) {
        final raw = result['data'] as List<dynamic>? ?? [];
        _listFasilitas = raw
            .map((e) => FasilitasModel.fromJson(e))
            .where((f) => f.isActive == true)
            .toList();
      }
    } catch (_) {}
    notifyListeners();
  }

  void resetForm() {
    selectedUser = null;
    selectedKantor = null;
    _selectedFasilitas = [];
    _manualErrors = {};
    ctrlUserId.clear();
    ctrlNama.clear();
    ctrlPass.clear();
    ctrlTgl.clear();
    isChangePassword = false;
    formKey.currentState?.reset();
    notifyListeners();
  }

  void isiFormDariUser(UsersAccessModel u) {
    _manualErrors = {};
    ctrlUserId.text = u.userid ?? '';
    ctrlNama.text = u.namauser ?? '';
    final rawTgl = u.tglexp ?? '';
    ctrlTgl.text = rawTgl.isNotEmpty ? rawTgl.split(' ')[0].split('T')[0] : '';
    ctrlPass.clear();
    isChangePassword = false;

    selectedKantor = _listKantor.where((k) => k.kdKantor == u.kdkantor).firstOrNull;

    _selectedFasilitas = [];
    if (u.akses != null) {
      for (final akses in u.akses!) {
        final match = _listFasilitas
            .where((f) => f.modul == akses.modul && f.menu == akses.menu && f.submenu == akses.submenu)
            .firstOrNull;
        if (match != null) _selectedFasilitas.add(match);
      }
    }
    notifyListeners();
  }

  void toggleFasilitas(FasilitasModel f) {
    if (_selectedFasilitas.contains(f)) {
      _selectedFasilitas.remove(f);
    } else {
      _selectedFasilitas.add(f);
    }
    if (_selectedFasilitas.isNotEmpty && _manualErrors.containsKey('fasilitas')) {
      _manualErrors.remove('fasilitas');
      notifyListeners();
    }
    notifyListeners();
  }

  void setSelectedKantor(KantorItem? kantor) {
    selectedKantor = kantor;
    if (kantor != null && _manualErrors.containsKey('kantor')) {
      _manualErrors.remove('kantor');
      notifyListeners();
    }
    notifyListeners();
  }

  void toggleChangePassword(bool? value) {
    isChangePassword = value ?? false;
    if (!isChangePassword) {
      ctrlPass.clear();
    }
    notifyListeners();
  }

  void openDrawerForAction(UsersAccessModel user) {
    selectedUser = user;
    isiFormDariUser(user);
    drawerMode = 'aksi';
    scaffoldKey.currentState?.openEndDrawer();
    notifyListeners();
  }

  void openDrawerForTambah() {
    resetForm();
    drawerMode = 'tambah';
    scaffoldKey.currentState?.openEndDrawer();
    notifyListeners();
  }

  void openDrawerForEdit() {
    drawerMode = 'edit';
    notifyListeners();
  }

  void openDrawerForHapus() {
    drawerMode = 'hapus';
    notifyListeners();
  }

  void openDrawerForBlokir() {
    drawerMode = 'blokir';
    notifyListeners();
  }

  void openDrawerForBukaBlokir() {
    drawerMode = 'bukaBlokir';
    notifyListeners();
  }

  void openDrawerForForceLogout() {
    drawerMode = 'forceLogout';
    notifyListeners();
  }

  void openDrawerForResetPassword() {
    drawerMode = 'resetPassword';
    notifyListeners();
  }

  void closeDrawer() {
    drawerMode = null;
    scaffoldKey.currentState?.closeEndDrawer();
    resetForm();
    notifyListeners();
  }

  void goBackToActionMenu() {
    drawerMode = 'aksi';
    notifyListeners();
  }

  // ==================== RESET PASSWORD ====================
  Future<void> resetPassword() async {
    if (!context.mounted) return;
    
    isSaving = true;
    notifyListeners();

    final u = _sessionUser!;
    final result = await UsersAccessRepository.resetPasswordUser(
      url: NetworkURL.resetPasswordUser(),
      bprId: u.bprId,
      userlogin: u.usersId,
      targetUserId: selectedUser!.userid ?? '',
      term: 'WEB',
    );

    isSaving = false;
    notifyListeners();

    if (result['value'] == 1) {
      closeDrawer();
      await _loadUsers();
      _showSuccessDialog('Password user berhasil direset! User dapat login kembali.');
    } else {
      final errorMsg = result['message']?.toString() ?? 'Gagal mereset password';
      _showErrorDialog(errorMsg);
    }
  }

  Future<bool> _showResetPasswordConfirmDialog() async {
    final user = selectedUser;
    if (user == null) return false;

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
                  const Icon(Icons.lock_reset, color: colortextwhite, size: 20),
                  const SizedBox(width: 10),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Reset Password',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colortextwhite)),
                    Text('User Access', style: TextStyle(fontSize: 12, color: colortextwhite)),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Apakah Anda yakin ingin mereset password user ini?',
                        style: TextStyle(fontSize: 14)),
                    const Text('Password akan direset sehingga user dapat login kembali.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                          _konfirmasiRow('Nama', user.namauser ?? '-'),
                          const SizedBox(height: 6),
                          _konfirmasiRow('User ID', user.userid ?? '-'),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Kantor', getNamaKantor(user.kdkantor)),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Status', UsersAccessStsrec.labelFor(user)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
                          child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w600)),
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
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }

  // ==================== MANUAL VALIDATION METHODS ====================
  
  bool validateAllFieldsManually() {
    bool allValid = true;
    final errors = <String, String>{};
    
    if (drawerMode == 'tambah') {
      final userIdError = _validateUserIdManual(ctrlUserId.text.trim());
      if (userIdError != null) {
        errors['userid'] = userIdError;
        allValid = false;
      }
    }
    
    if (drawerMode == 'tambah' || drawerMode == 'edit') {
      final namaError = _validateNamaManual(ctrlNama.text.trim());
      if (namaError != null) {
        errors['nama'] = namaError;
        allValid = false;
      }
    }
    
    if (drawerMode == 'tambah') {
      final passError = _validatePasswordManual(ctrlPass.text.trim(), true);
      if (passError != null) {
        errors['password'] = passError;
        allValid = false;
      }
    } else if (drawerMode == 'edit' && isChangePassword) {
      final passError = _validatePasswordManual(ctrlPass.text.trim(), false);
      if (passError != null) {
        errors['password'] = passError;
        allValid = false;
      }
    }
    
    if (drawerMode == 'tambah' || drawerMode == 'edit') {
      final tglError = _validateTglManual(ctrlTgl.text.trim());
      if (tglError != null) {
        errors['tgl'] = tglError;
        allValid = false;
      }
    }
    
    if (drawerMode == 'tambah' || drawerMode == 'edit') {
      if (selectedKantor == null) {
        errors['kantor'] = 'Pilih kantor terlebih dahulu';
        allValid = false;
      }
    }
    
    if (drawerMode == 'tambah' || drawerMode == 'edit') {
      if (_selectedFasilitas.isEmpty) {
        errors['fasilitas'] = 'Pilih minimal 1 fasilitas';
        allValid = false;
      }
    }
    
    _manualErrors = errors;
    notifyListeners();
    
    return allValid;
  }

  String? _validateUserIdManual(String value) {
    if (value.isEmpty) {
      return 'User ID wajib diisi';
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return 'User ID tidak boleh mengandung spasi';
    }
    
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
    final hasNumber = RegExp(r'[0-9]').hasMatch(value);
    if (!hasLetter || !hasNumber) {
      return 'User ID harus mengandung huruf dan angka (contoh: johndoe123)';
    }
    
    if (_list.any((u) => u.userid?.toUpperCase() == value.toUpperCase())) {
      return 'User ID sudah terdaftar';
    }
    return null;
  }

  String? _validateNamaManual(String value) {
    if (value.isEmpty) {
      return 'Nama users wajib diisi';
    }
    
    final hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value);
    if (hasSpecialChar) {
      return 'Nama users tidak boleh mengandung karakter spesial (!@#\$%^&* dll)';
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

  String? _validateTglManual(String value) {
    if (value.isEmpty) {
      return 'Tanggal wajib diisi';
    }
    return null;
  }

  // ==================== VALIDATION METHODS (for form) ====================
  
  String? validateUserId(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'User ID wajib diisi';
    if (RegExp(r'\s').hasMatch(text)) return 'User ID tidak boleh mengandung spasi';
    
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(text);
    final hasNumber = RegExp(r'[0-9]').hasMatch(text);
    if (!hasLetter || !hasNumber) {
      return 'User ID harus mengandung huruf dan angka (contoh: johndoe123)';
    }
    
    if (drawerMode == 'tambah' && _list.any((u) => u.userid?.toUpperCase() == text.toUpperCase())) {
      return 'User ID sudah terdaftar';
    }
    return null;
  }

  String? validateNama(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Nama users wajib diisi';
    
    final hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(text);
    if (hasSpecialChar) {
      return 'Nama users tidak boleh mengandung karakter spesial (!@#\$%^&* dll)';
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

  String? validateTgl(String? v) => (v ?? '').trim().isEmpty ? 'Tanggal wajib diisi' : null;

  bool validateForm() {
    if (drawerMode == 'tambah' || drawerMode == 'edit') {
      if (!(formKey.currentState?.validate() ?? false)) return false;
      if (selectedKantor == null) {
        _showErrorDialog('Pilih kantor terlebih dahulu');
        return false;
      }
      if (_selectedFasilitas.isEmpty) {
        _showErrorDialog('Pilih minimal 1 fasilitas');
        return false;
      }
    }
    return true;
  }

  List<_ConfirmChangeRow> _buildChangeRows() {
    if (selectedUser == null) return [];
    final rows = <_ConfirmChangeRow>[];
    final u = selectedUser!;

    final oldNama = u.namauser ?? '-';
    final newNama = ctrlNama.text.trim();
    if (oldNama != newNama) rows.add(_ConfirmChangeRow('Nama', oldNama, newNama));

    final oldKantor = getNamaKantor(u.kdkantor);
    final newKantor = selectedKantor?.toString() ?? '-';
    if (oldKantor != newKantor) rows.add(_ConfirmChangeRow('Kantor', oldKantor, newKantor));

    final oldTgl = (u.tglexp ?? '').split(' ')[0].split('T')[0];
    final newTgl = ctrlTgl.text.trim();
    if (oldTgl != newTgl) rows.add(_ConfirmChangeRow('Tgl Kadaluarsa', oldTgl.isEmpty ? '-' : oldTgl, newTgl.isEmpty ? '-' : newTgl));

    if (isChangePassword) rows.add(const _ConfirmChangeRow('Password', '(lama)', '(baru)'));

    final oldFas = u.akses?.length ?? 0;
    final newFas = _selectedFasilitas.length;
    if (oldFas != newFas) rows.add(_ConfirmChangeRow('Fasilitas', '$oldFas item', '$newFas item'));

    if (rows.isEmpty) {
      rows.add(_ConfirmChangeRow('Nama', oldNama, newNama));
      rows.add(_ConfirmChangeRow('Kantor', oldKantor, newKantor));
      rows.add(_ConfirmChangeRow('Tgl Kadaluarsa', oldTgl.isEmpty ? '-' : oldTgl, newTgl.isEmpty ? '-' : newTgl));
    }
    return rows;
  }

  // ==================== EXECUTE ACTION ====================
  Future<void> executeAction() async {
    switch (drawerMode) {
      case 'resetPassword':
        final confirmed = await _showResetPasswordConfirmDialog();
        if (!confirmed) return;
        await resetPassword();
        break;
      case 'tambah':
      case 'edit':
        await simpan();
        break;
      case 'hapus':
        await hapus();
        break;
      case 'blokir':
        await blokir();
        break;
      case 'bukaBlokir':
        await bukaBlokir();
        break;
      case 'forceLogout':
        await forceLogout();
        break;
    }
  }

  Future<void> simpan() async {
    if (!validateForm()) return;

    if (!context.mounted) return;
    final isInsert = drawerMode == 'tambah';
    
    if (isInsert && ctrlPass.text.trim().isEmpty) {
      _showErrorDialog('Password wajib diisi');
      return;
    }
    if (isInsert && ctrlPass.text.trim().length < 6) {
      _showErrorDialog('Password minimal 6 karakter');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmDialog(
        title    : isInsert ? 'Konfirmasi Tambah' : 'Konfirmasi Edit',
        subtitle : isInsert ? 'Tambah user baru dengan data berikut?' : 'Simpan perubahan data user berikut?',
        icon     : isInsert ? Icons.person_add_outlined : Icons.edit_outlined,
        labelOk  : isInsert ? 'Tambah' : 'Simpan',
        rows     : [
          _ConfirmRow('User ID',   ctrlUserId.text.trim()),
          _ConfirmRow('Nama',      ctrlNama.text.trim()),
          _ConfirmRow('Kantor',    selectedKantor?.toString() ?? '-'),
          _ConfirmRow('Tgl Exp',   ctrlTgl.text.trim()),
          _ConfirmRow('Fasilitas', '${_selectedFasilitas.length} item dipilih'),
          if (isInsert) _ConfirmRow('Password', '********'),
        ],
        changeRows: isInsert ? null : _buildChangeRows(),
      ),
    );
    if (confirmed != true) return;

    isSaving = true;
    notifyListeners();

    final u = _sessionUser!;
    final fasJson = jsonEncode(_selectedFasilitas.map((f) => f.toJson()).toList());

    String? encPass;
    if (!isInsert && !isChangePassword) {
      encPass = await UsersAccessRepository.resolveEncryptedPassForUpdate(
        bprId: u.bprId,
        targetUserId: ctrlUserId.text.trim(),
        inquiryPass: selectedUser?.pass,
      );
    }

    final result = await UsersAccessRepository.saveUsers(
      url: isInsert ? NetworkURL.insertUsers() : NetworkURL.updateUsers(),
      action: isInsert ? 'insert' : 'update',
      bprId: u.bprId,
      userlogin: u.usersId,
      userId: ctrlUserId.text.trim(),
      password: isInsert ? ctrlPass.text.trim() : (isChangePassword ? ctrlPass.text.trim() : ''),
      existingEncryptedPass: encPass,
      username: ctrlUserId.text.trim(),
      namaUsers: ctrlNama.text.trim(),
      kdKantor: selectedKantor!.kdKantor,
      tglKadaluarsa: ctrlTgl.text.trim(),
      stsAktif: 'A',
      listFasilitas: fasJson,
    );

    isSaving = false;
    notifyListeners();

    if (result['value'] == 1) {
      closeDrawer();
      await _loadUsers();
      _showSuccessDialog(isInsert ? 'User berhasil ditambahkan!' : 'User berhasil diupdate!');
    } else {
      final errorMsg = result['message']?.toString() ?? 'Terjadi kesalahan';
      _showErrorDialog(errorMsg);
    }
  }

  Future<void> hapus() async {
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmDialog(
        title    : 'Konfirmasi Hapus',
        subtitle : 'User berikut akan dihapus secara permanen.',
        icon     : Icons.delete_outline,
        labelOk  : 'Hapus',
        isDanger : true,
        rows     : [
          _ConfirmRow('User ID', selectedUser?.userid ?? '-'),
          _ConfirmRow('Nama',    selectedUser?.namauser ?? '-'),
        ],
      ),
    );
    if (confirmed != true) return;

    isSaving = true;
    notifyListeners();

    final u = _sessionUser!;
    final result = await UsersAccessRepository.deleteUsers(
      url: NetworkURL.deleteUsers(),
      bprId: u.bprId,
      userlogin: u.usersId,
      targetUserId: selectedUser!.userid ?? '',
      deletedBy: u.usersId,
    );

    isSaving = false;
    notifyListeners();

    if (result['value'] == 1) {
      closeDrawer();
      await _loadUsers();
      _showSuccessDialog('User berhasil dihapus!');
    } else {
      final errorMsg = result['message']?.toString() ?? 'Terjadi kesalahan';
      _showErrorDialog(errorMsg);
    }
  }

  Future<void> blokir() async {
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmDialog(
        title    : 'Konfirmasi Blokir',
        subtitle : 'User berikut akan diblokir.',
        icon     : Icons.block_outlined,
        labelOk  : 'Blokir',
        isDanger : true,
        rows     : [
          _ConfirmRow('User ID', selectedUser?.userid ?? '-'),
          _ConfirmRow('Nama',    selectedUser?.namauser ?? '-'),
        ],
      ),
    );
    if (confirmed != true) return;

    isSaving = true;
    notifyListeners();

    final u = _sessionUser!;
    final result = await UsersAccessRepository.blokirUsers(
      url: NetworkURL.blokirUsers(),
      bprId: u.bprId,
      userlogin: u.usersId,
      targetUserId: selectedUser!.userid ?? '',
      blockedBy: u.usersId,
      alasan: '',
    );

    isSaving = false;
    notifyListeners();

    if (result['value'] == 1) {
      closeDrawer();
      await _loadUsers();
      _showSuccessDialog('User berhasil diblokir!');
    } else {
      final errorMsg = result['message']?.toString() ?? 'Terjadi kesalahan';
      _showErrorDialog(errorMsg);
    }
  }

  Future<void> forceLogout() async {
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmDialog(
        title    : 'Konfirmasi Force Logout',
        subtitle : 'User berikut akan dipaksa logout dari semua perangkat.',
        icon     : Icons.logout,
        labelOk  : 'Force Logout',
        isDanger : false,
        rows     : [
          _ConfirmRow('User ID', selectedUser?.userid ?? '-'),
          _ConfirmRow('Nama',    selectedUser?.namauser ?? '-'),
        ],
      ),
    );
    if (confirmed != true) return;

    isSaving = true;
    notifyListeners();

    final u = _sessionUser!;
    final result = await UsersAccessRepository.forceLogoutUser(
      url: NetworkURL.forceLogout(),
      bprId: u.bprId,
      userlogin: u.usersId,
      targetUserId: selectedUser!.userid ?? '',
    );

    isSaving = false;
    notifyListeners();

    if (result['value'] == 1) {
      closeDrawer();
      await _loadUsers();
      _showSuccessDialog('User berhasil di-force logout!');
    } else {
      final errorMsg = result['message']?.toString() ?? 'Terjadi kesalahan';
      _showErrorDialog(errorMsg);
    }
  }

  Future<void> bukaBlokir() async {
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmDialog(
        title    : 'Konfirmasi Buka Blokir',
        subtitle : 'Blokir user berikut akan dibuka.',
        icon     : Icons.lock_open_outlined,
        labelOk  : 'Buka Blokir',
        rows     : [
          _ConfirmRow('User ID', selectedUser?.userid ?? '-'),
          _ConfirmRow('Nama',    selectedUser?.namauser ?? '-'),
        ],
      ),
    );
    if (confirmed != true) return;

    isSaving = true;
    notifyListeners();

    final u = _sessionUser!;
    final result = await UsersAccessRepository.bukaBlokirUsers(
      url: NetworkURL.unblokirUsers(),
      bprId: u.bprId,
      userlogin: u.usersId,
      targetUserId: selectedUser!.userid ?? '',
      unblockedBy: u.usersId,
    );

    isSaving = false;
    notifyListeners();

    if (result['value'] == 1) {
      closeDrawer();
      await _loadUsers();
      _showSuccessDialog('Blokir user berhasil dibuka!');
    } else {
      final errorMsg = result['message']?.toString() ?? 'Terjadi kesalahan';
      _showErrorDialog(errorMsg);
    }
  }

  Future<void> pilihTanggal() async {
    DateTime initial = DateTime.now();
    try {
      if (ctrlTgl.text.isNotEmpty) initial = DateTime.parse(ctrlTgl.text.split(' ')[0].split('T')[0]);
    } catch (_) {}

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime(2090),
    );
    if (date != null) {
      ctrlTgl.text = DateFormat('yyyy-MM-dd').format(date);
      if (_manualErrors.containsKey('tgl')) {
        _manualErrors.remove('tgl');
        notifyListeners();
      }
      notifyListeners();
    }
  }

  void toggleObscure() {
    obscurePass = !obscurePass;
    notifyListeners();
  }

  void _showSuccessDialog(String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(isSuccess: true, message: message),
    );
  }

  void _showErrorDialog(String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(isSuccess: false, message: message),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    scrollController.dispose();
    ctrlUserId.dispose();
    ctrlNama.dispose();
    ctrlPass.dispose();
    ctrlTgl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }
}

class _ResultDialog extends StatelessWidget {
  final bool isSuccess;
  final String message;

  const _ResultDialog({required this.isSuccess, required this.message});

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

class _ConfirmRow {
  final String label;
  final String value;
  const _ConfirmRow(this.label, this.value);
}

class _ConfirmChangeRow {
  final String label;
  final String before;
  final String after;
  const _ConfirmChangeRow(this.label, this.before, this.after);
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String labelOk;
  final bool isDanger;
  final List<_ConfirmRow> rows;
  final List<_ConfirmChangeRow>? changeRows;

  const _ConfirmDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.labelOk,
    required this.rows,
    this.isDanger = false,
    this.changeRows,
  });

  @override
  Widget build(BuildContext context) {
    final headerColor = isDanger ? colorcancel : colorPrimary;
    final hasChanges = changeRows != null && changeRows!.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 460,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(children: [
                Icon(icon, color: colortextwhite, size: 20),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: colortextwhite)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: colortextwhite)),
                ]),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasChanges) ...[
                      ...changeRows!.map((row) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAF9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDCE3DF), width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.label,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Sebelum',
                                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Text(row.before,
                                          style: const TextStyle(
                                              fontSize: 13, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Icon(Icons.arrow_forward, size: 20, color: headerColor),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Sesudah',
                                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Text(row.after,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: headerColor)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAF9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDCE3DF), width: 0.5),
                        ),
                        child: Column(
                          children: rows.map((row) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(row.label,
                                      style: const TextStyle(
                                          fontSize: 12, color: Color(0xFF888780))),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(row.value,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF2C2C2A),
                                          fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
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
                      backgroundColor: headerColor,
                      foregroundColor: colortextwhite,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(labelOk, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}