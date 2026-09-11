// lib/module/reset_device/reset_device_cis_page.dart
//
// Reset Device CIS — untuk akun login CIS sendiri (cis_user, admin/backoffice
// yang login ke aplikasi CIS ini). Tampilan & alur mengikuti pola persis
// ResetDeviceKolektorPage/ResetDeviceTellerPage: cari user (nama/User ID) ->
// tampil kartu detail -> tombol Reset Device. login_device_id/login_device_name
// diisi oleh proses login user itu sendiri (bukan bagian kita), kita cuma
// baca & bisa mengosongkannya.

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../../models/index.dart';
import '../../pref/pref.dart';
import '../../repository/users_access_repository.dart';
import '../../utils/colors.dart';

// ==================== NOTIFIER ====================
class ResetDeviceCisNotifier extends ChangeNotifier {
  bool isSearching = false;
  bool isLoading = false;
  String errorMessage = '';
  UsersAccessModel? userData;

  String? _bprId;
  UsersModel? _sessionUser;

  ResetDeviceCisNotifier() {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final users = await Pref().getUsers();
    _sessionUser = users;
    _bprId = users.bprId;
  }

  bool get isLoggedIn => (userData?.loginDeviceId ?? '').trim().isNotEmpty;

  // Status akun HANYA baca A/C vs B — A dan C sama-sama dianggap Aktif,
  // cuma B yang berarti Diblokir. Sama polanya dengan reset device lain.
  bool get isBlokir => (userData?.stsaktif ?? 'A').toUpperCase() == 'B';

  bool get allDeviceOn => userData?.allDevice == true;

  void setEmptySearchError(String message) {
    errorMessage = message;
    userData = null;
    notifyListeners();
  }

  // ==================== CARI USER (nama / User ID) ====================
  Future<void> searchByKeyword(String keyword) async {
    if (keyword.isEmpty) {
      errorMessage = 'Masukkan Nama / User ID';
      userData = null;
      notifyListeners();
      return;
    }

    isSearching = true;
    errorMessage = '';
    notifyListeners();

    try {
      final list = await UsersAccessRepository.searchUsersAccess(
        bprId: _bprId ?? '',
        userLogin: _sessionUser?.usersId ?? '',
        term: 'WEB',
        keyword: keyword,
      );

      // Pencocokan diprioritaskan, bukan asal ambil hasil pertama:
      // 1) userid sama persis
      // 2) userid MENGANDUNG keyword
      // 3) nama MENGANDUNG keyword
      final kw = keyword.toLowerCase();
      UsersAccessModel? match;
      for (final u in list) {
        if ((u.userid ?? '').toLowerCase() == kw) { match = u; break; }
      }
      match ??= list.where((u) => (u.userid ?? '').toLowerCase().contains(kw)).firstOrNull;
      match ??= list.where((u) => (u.namauser ?? '').toLowerCase().contains(kw)).firstOrNull;

      if (match == null) {
        errorMessage = "User dengan nama/User ID '$keyword' tidak ditemukan";
        userData = null;
      } else {
        userData = match;
        errorMessage = '';
      }
    } catch (e) {
      errorMessage = 'Terjadi kesalahan: $e';
      userData = null;
    }

    isSearching = false;
    notifyListeners();
  }

  // ==================== RESET DEVICE ====================
  Future<Map<String, dynamic>> resetDevice(String userid) async {
    isLoading = true;
    notifyListeners();

    final result = await UsersAccessRepository.resetDeviceUser(
      bprId: _bprId ?? '',
      userlogin: _sessionUser?.usersId ?? '',
      targetUserId: userid,
      term: 'WEB',
    );

    if (result['value'] == 1) {
      // Refresh data supaya kartu langsung nunjukin device udah kosong.
      await searchByKeyword(userid);
    }

    isLoading = false;
    notifyListeners();
    return {
      'success': result['value'] == 1,
      'message': result['message'] ?? (result['value'] == 1 ? 'Device user berhasil direset' : 'Gagal reset device user'),
    };
  }

  void reset() {
    isLoading = false;
    isSearching = false;
    errorMessage = '';
    userData = null;
    notifyListeners();
  }
}

// ==================== PAGE ====================
class ResetDeviceCisPage extends StatefulWidget {
  const ResetDeviceCisPage({super.key});

  @override
  State<ResetDeviceCisPage> createState() => _ResetDeviceCisPageState();
}

class _ResetDeviceCisPageState extends State<ResetDeviceCisPage> {
  late ResetDeviceCisNotifier _notifier;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notifier = ResetDeviceCisNotifier();
  }

  @override
  void dispose() {
    _notifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      _notifier.setEmptySearchError('Masukkan kata kunci pencarian');
      return;
    }
    await _notifier.searchByKeyword(keyword);
  }

  void _clearResult() {
    _searchController.clear();
    _notifier.reset();
  }

  Future<void> _resetDevice() async {
    if (_notifier.userData == null) return;

    final isConfirmed = await _showConfirmDialog(
      title: 'Konfirmasi Reset Device',
      message: 'Apakah Anda yakin ingin reset device user ini?\n\n'
          'User ID: ${_notifier.userData!.userid}\n'
          'Nama: ${_notifier.userData!.namauser}',
    );
    if (!isConfirmed) return;

    _showLoadingDialog();
    final result = await _notifier.resetDevice(_notifier.userData!.userid ?? '');
    if (mounted) Navigator.pop(context);

    if (result['success'] == true) {
      _showSuccessDialog(result['message']);
    } else {
      _showErrorDialog(result['message']);
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  Future<bool> _showConfirmDialog({required String title, required String message}) async {
    return await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.phonelink_erase, color: colorPrimary, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            content: Text(message),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Ya, Reset Device'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [colorPrimary, Color(0xff6D28D9)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              const Text('BERHASIL!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorPrimary)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, color: Colors.red.shade600, size: 32),
              ),
              const SizedBox(height: 20),
              const Text('GAGAL!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorPrimary)),
          ),
          const Text(':', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(child: Text(value.trim().isEmpty ? '-' : value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _notifier,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xffF6F3FE),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                color: colorPrimary,
                child: const Text('Reset Device User CIS',
                    style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: colorPrimary.withOpacity(0.25)),
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Masukkan Nama / User ID',
                                  border: InputBorder.none,
                                  icon: Icon(Icons.search, color: colorPrimary),
                                ),
                                onSubmitted: (_) => _search(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _notifier.isSearching ? null : _search,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorPrimary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(80, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: _notifier.isSearching
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Cari'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Result Area
                      if (_notifier.errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_notifier.errorMessage, style: TextStyle(color: Colors.red.shade700))),
                            ],
                          ),
                        )
                      else if (_notifier.userData != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorPrimary.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorPrimary.withOpacity(0.06),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                                child: const Text('Detail User',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorPrimary)),
                              ),
                              const Divider(height: 1, thickness: 1),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _infoRow('User ID', _notifier.userData!.userid ?? ''),
                                    _infoRow('Nama', _notifier.userData!.namauser ?? ''),
                                    _infoRow('Kantor', _notifier.userData!.namaKantor ?? _notifier.userData!.kdkantor ?? ''),
                                    _infoRow('Device Name', _notifier.userData!.loginDeviceName ?? ''),
                                    const SizedBox(height: 12),
                                    // Status Akun — HANYA baca A/C (Aktif) vs B (Diblokir).
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: (_notifier.isBlokir ? Colors.red : Colors.green).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _notifier.isBlokir ? Colors.red : Colors.green,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _notifier.isBlokir ? Icons.block : Icons.check_circle,
                                            color: _notifier.isBlokir ? Colors.red : Colors.green,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Status Akun: ${_notifier.isBlokir ? 'Diblokir' : 'Aktif'}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: _notifier.isBlokir ? Colors.red : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // All Device — kalau ON, device_id/name diabaikan saat login
                                    // (user boleh login dari mana saja), reset device jadi gak relevan.
                                    if (_notifier.allDeviceOn)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.blue, width: 1.5),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.public, color: Colors.blue, size: 18),
                                            const SizedBox(width: 10),
                                            Text(
                                              'All Device aktif — user ini boleh login dari device manapun',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (_notifier.allDeviceOn) const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: (_notifier.isLoggedIn ? colorPrimary : Colors.grey).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _notifier.isLoggedIn ? colorPrimary : Colors.grey,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _notifier.isLoggedIn ? Icons.smartphone : Icons.phonelink_off,
                                            color: _notifier.isLoggedIn ? colorPrimary : Colors.grey,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _notifier.isLoggedIn ? 'Status: Sedang Login' : 'Status: Belum Login',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: _notifier.isLoggedIn ? colorPrimary : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _notifier.isLoading ? null : _clearResult,
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Batal'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade200,
                                        foregroundColor: Colors.black87,
                                        minimumSize: const Size(120, 42),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: (_notifier.isLoading || !_notifier.isLoggedIn) ? null : _resetDevice,
                                      icon: const Icon(Icons.phonelink_erase, size: 18),
                                      label: const Text('Reset Device'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorPrimary,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: Colors.grey.shade300,
                                        minimumSize: const Size(150, 42),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (!_notifier.isSearching)
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorPrimary.withOpacity(0.15)),
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.search, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('Silakan cari user CIS terlebih dahulu', style: TextStyle(color: Colors.grey)),
                                SizedBox(height: 8),
                                Text('Masukkan nama atau User ID lalu tekan Cari',
                                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
