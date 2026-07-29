// lib/module/reset_device/reset_device_kolektor_page.dart
//
// Reset Device Kolektor — tampilan mengikuti pola "Ganti Device Agent" di
// aplikasi CMS Medfo: cari kolektor (nama/User ID) -> tampil kartu detail ->
// tombol Reset Device. login_device_id/login_device_name/fcm_token diisi
// oleh proses login kolektor sendiri (bukan bagian kita), kita cuma baca &
// bisa mengosongkannya.

import 'package:flutter/material.dart';
import '../../pref/pref.dart';
import '../../repository/collector_repository.dart';
import '../../utils/colors.dart';

class KolektorDeviceInfo {
  final String userid;
  final String nama;
  final String kdKantor;
  final String? loginDeviceId;
  final String? loginDeviceName;
  final String? lastActivityAt;
  final String? stsAktif;

  KolektorDeviceInfo({
    required this.userid,
    required this.nama,
    required this.kdKantor,
    this.loginDeviceId,
    this.loginDeviceName,
    this.lastActivityAt,
    this.stsAktif,
  });

  bool get isLoggedIn => (loginDeviceId ?? '').trim().isNotEmpty;

  // Status akun HANYA baca A/C vs B — A dan C sama-sama dianggap Aktif
  // (C dipakai fitur Buka/Tutup Transaksi, bukan blokir akun). Cuma B yang
  // berarti Diblokir.
  bool get isBlokir => (stsAktif ?? 'A').toUpperCase() == 'B';

  factory KolektorDeviceInfo.fromJson(Map<String, dynamic> json) {
    return KolektorDeviceInfo(
      userid: (json['userid'] ?? '').toString(),
      nama: (json['nama'] ?? '-').toString(),
      kdKantor: (json['kd_kantor'] ?? '').toString(),
      loginDeviceId: json['login_device_id']?.toString(),
      loginDeviceName: json['login_device_name']?.toString(),
      lastActivityAt: json['last_activity_at']?.toString(),
      stsAktif: json['stsaktif']?.toString(),
    );
  }
}

// ==================== NOTIFIER ====================
class ResetDeviceKolektorNotifier extends ChangeNotifier {
  bool isSearching = false;
  bool isLoading = false;
  String errorMessage = '';
  KolektorDeviceInfo? kolektorData;

  String? _bprId;

  ResetDeviceKolektorNotifier() {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final users = await Pref().getUsers();
    _bprId = users.bprId;
  }

  void setEmptySearchError(String message) {
    errorMessage = message;
    kolektorData = null;
    notifyListeners();
  }

  // ==================== CARI TELLER (nama / User ID) ====================
  Future<void> searchByKeyword(String keyword) async {
    if (keyword.isEmpty) {
      errorMessage = 'Masukkan Nama / User ID Kolektor';
      kolektorData = null;
      notifyListeners();
      return;
    }

    isSearching = true;
    errorMessage = '';
    notifyListeners();

    try {
      final result = await CollectorRepository.inquiryCollectorDb(
        search: keyword,
        bprId: _bprId,
        limit: 20,
      );

      if (result['value'] == 1) {
        final List<dynamic> data = result['data'] ?? [];
        final list = data.map((e) => KolektorDeviceInfo.fromJson(Map<String, dynamic>.from(e))).toList();

        // Cocokkan persis dengan userid yang diketik dulu, kalau gak ada
        // exact match ambil hasil pertama dari pencarian nama.
        KolektorDeviceInfo? match;
        for (final t in list) {
          if (t.userid.toLowerCase() == keyword.toLowerCase()) {
            match = t;
            break;
          }
        }
        match ??= list.isNotEmpty ? list.first : null;

        if (match == null) {
          errorMessage = "Kolektor dengan nama/User ID '$keyword' tidak ditemukan";
          kolektorData = null;
        } else {
          kolektorData = match;
          errorMessage = '';
        }
      } else {
        errorMessage = result['message'] ?? 'Kolektor tidak ditemukan';
        kolektorData = null;
      }
    } catch (e) {
      errorMessage = 'Terjadi kesalahan: $e';
      kolektorData = null;
    }

    isSearching = false;
    notifyListeners();
  }

  // ==================== RESET DEVICE ====================
  Future<Map<String, dynamic>> resetDevice(String userid) async {
    isLoading = true;
    notifyListeners();

    final result = await CollectorRepository.resetDevice(userid: userid);

    if (result['value'] == 1) {
      // Refresh data supaya kartu langsung nunjukin device udah kosong.
      await searchByKeyword(userid);
    }

    isLoading = false;
    notifyListeners();
    return {
      'success': result['value'] == 1,
      'message': result['message'] ?? (result['value'] == 1 ? 'Device kolektor berhasil direset' : 'Gagal reset device kolektor'),
    };
  }

  void reset() {
    isLoading = false;
    isSearching = false;
    errorMessage = '';
    kolektorData = null;
    notifyListeners();
  }
}

// ==================== PAGE ====================
class ResetDeviceKolektorPage extends StatefulWidget {
  const ResetDeviceKolektorPage({super.key});

  @override
  State<ResetDeviceKolektorPage> createState() => _ResetDeviceKolektorPageState();
}

class _ResetDeviceKolektorPageState extends State<ResetDeviceKolektorPage> {
  late ResetDeviceKolektorNotifier _notifier;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notifier = ResetDeviceKolektorNotifier();
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
    if (_notifier.kolektorData == null) return;

    final isConfirmed = await _showConfirmDialog(
      title: 'Konfirmasi Reset Device',
      message: 'Apakah Anda yakin ingin reset device kolektor ini?\n\n'
          'User ID: ${_notifier.kolektorData!.userid}\n'
          'Nama: ${_notifier.kolektorData!.nama}',
    );
    if (!isConfirmed) return;

    _showLoadingDialog();
    final result = await _notifier.resetDevice(_notifier.kolektorData!.userid);
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
                child: const Text('Reset Device Kolektor',
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
                                  hintText: 'Masukkan Nama / User ID Kolektor',
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
                      else if (_notifier.kolektorData != null)
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
                                child: const Text('Detail Kolektor',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorPrimary)),
                              ),
                              const Divider(height: 1, thickness: 1),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _infoRow('User ID', _notifier.kolektorData!.userid),
                                    _infoRow('Nama', _notifier.kolektorData!.nama),
                                    _infoRow('Kode Kantor', _notifier.kolektorData!.kdKantor),
                                    _infoRow('Device Name', _notifier.kolektorData!.loginDeviceName ?? ''),
                                    _infoRow('Terakhir Login', _notifier.kolektorData!.lastActivityAt ?? ''),
                                    const SizedBox(height: 12),
                                    // Status Akun — HANYA baca A/C (Aktif) vs B (Diblokir).
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: (_notifier.kolektorData!.isBlokir ? Colors.red : Colors.green).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _notifier.kolektorData!.isBlokir ? Colors.red : Colors.green,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _notifier.kolektorData!.isBlokir ? Icons.block : Icons.check_circle,
                                            color: _notifier.kolektorData!.isBlokir ? Colors.red : Colors.green,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Status Akun: ${_notifier.kolektorData!.isBlokir ? 'Diblokir' : 'Aktif'}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: _notifier.kolektorData!.isBlokir ? Colors.red : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: (_notifier.kolektorData!.isLoggedIn ? colorPrimary : Colors.grey).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _notifier.kolektorData!.isLoggedIn ? colorPrimary : Colors.grey,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _notifier.kolektorData!.isLoggedIn ? Icons.smartphone : Icons.phonelink_off,
                                            color: _notifier.kolektorData!.isLoggedIn ? colorPrimary : Colors.grey,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _notifier.kolektorData!.isLoggedIn ? 'Status: Sudah pernah Login' : 'Status: Belum pernah Login',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: _notifier.kolektorData!.isLoggedIn ? colorPrimary : Colors.grey.shade700,
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
                                      onPressed: (_notifier.isLoading || !_notifier.kolektorData!.isLoggedIn) ? null : _resetDevice,
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
                                Text('Silakan cari kolektor terlebih dahulu', style: TextStyle(color: Colors.grey)),
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
