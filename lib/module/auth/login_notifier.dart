import 'package:cis_menu/models/index.dart';
import 'package:cis_menu/pref/pref.dart';
import 'package:cis_menu/repository/auth_repository.dart';
import 'package:cis_menu/utils/dialog_custom.dart';
import 'package:flutter/material.dart';

import '../../network/network.dart';
import 'login_page.dart';
import '../menu/menu_page.dart';
import 'hari_libur_page.dart';
import '../../utils/hari_libur_exception.dart';

class LoginNotifier extends ChangeNotifier {
  final BuildContext context;

  LoginNotifier({required this.context}) {
    getProfile();
  }

  var obscure = true;
  bool isLoading = false;

  gantiobscure() {
    obscure = !obscure;
    notifyListeners();
  }

  TextEditingController username = TextEditingController();
  TextEditingController password = TextEditingController();
  final keyForm = GlobalKey<FormState>();

  UsersModel? users;
  List<FasilitasAddModel> listFasilitas = [];

  Future<void> getProfile() async {
    final value = await Pref().getUsers();
    users = value;
    // Cek juga token — jika hapus() sudah dipanggil saat auto-logout,
    // token pasti kosong sehingga tidak ada auto-redirect ke menu.
    final token = await Pref().getToken();
    final isLoggedIn = users != null &&
        (users!.usersId).isNotEmpty &&
        token.isNotEmpty;
    if (isLoggedIn) {
      await _proceedIfNotHoliday();
    }
    notifyListeners();
  }

  // ==================== CEK HARI LIBUR ====================
  // Dipanggil sebelum masuk ke menu, baik dari login manual maupun
  // auto-login sesi tersimpan. Kalau hari ini hari libur (nasional/cuti
  // bersama/khusus BPR ini), sesi di-clear dan diarahkan ke HariLiburPage
  // — bukan cuma dihalangi tampilannya doang, tapi beneran gak jadi login.
  Future<void> _proceedIfNotHoliday() async {
    final bprId = users?.bprId ?? '';
    if (bprId.isEmpty) {
      _navigateToMenu();
      return;
    }

    // PENGECUALIAN: bpr_id tertentu (mis. 609999) tetap boleh login
    // walaupun hari ini hari libur — skip semua pengecekan di bawah.
    if (isHariLiburExempt(bprId)) {
      _navigateToMenu();
      return;
    }

    // Cek 2 sumber libur:
    // 1. Tanggal spesifik (libur nasional / cuti bersama / libur khusus BPR)
    // 2. Hari dalam minggu yang memang libur rutin (mis. Sabtu-Minggu),
    //    dari setup jam kerja — jam buka/tutup-nya sendiri diabaikan.
    final hariLibur = await AuthRepository.checkHariLibur(bprId: bprId);
    String? keterangan = hariLibur?.keterangan;

    if (keterangan == null) {
      final jamKerjaLibur = await AuthRepository.checkJamKerjaLibur(bprId: bprId);
      if (jamKerjaLibur != null) {
        keterangan = 'Hari ${jamKerjaLibur.hariNama}';
      }
    }

    if (keterangan != null) {
      // PATCH: login-nya sendiri sebenarnya BERHASIL (userid/password benar),
      // cuma kita yang menolak masuk karena hari libur — jadi status login
      // di server (stslogin) kemungkinan sudah keburu keubah jadi 'Y'.
      // Panggil logout ke server di sini juga, supaya statusnya balik ke 'N'
      // dan akunnya gak nyangkut "masih login" padahal user gak jadi masuk.
      if (users != null) {
        try {
          await AuthRepository.logOut(
            NetworkURL.logout(),
            users!.bprId,
            users!.usersId,
            users!.usersId,
          );
        } catch (e) {
          // Diamkan — walau logout ke server gagal, sesi lokal tetap harus
          // dibersihkan di bawah supaya user gak nyangkut di sisi Flutter-nya.
        }
      }

      await Pref().hapus();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HariLiburPage(keterangan: keterangan)),
          (route) => false,
        );
      }
      return;
    }

    _navigateToMenu();
  }

  Future<void> cek() async {
    if (isLoading) return;
    if (!(keyForm.currentState?.validate() ?? false)) return;

    isLoading = true;
    listFasilitas.clear();
    if (context.mounted) CustomDialog.loading(context);
    notifyListeners();

    try {
      final value = await AuthRepository.login(
        token,
        NetworkURL.login(),
        username.text.trim(),
        password.text.trim(),
      );

      isLoading = false;

      // Tutup dialog loading terlebih dahulu
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (value['value'] == 1) {
        try {
          users = UsersModel.fromJson(
            Map<String, dynamic>.from(value['data'] ?? {}),
          );

          final fasilitasCount = (value['fasilitas'] as List?)?.length ?? 0;
          await _proceedIfNotHoliday();
        } catch (e) {
          if (context.mounted) {
            CustomDialog.messageResponse(
              context,
              'Gagal memproses data login: $e',
            );
          }
        }
      } else {
        if (context.mounted) {
          CustomDialog.messageResponse(
            context,
            value['message'] ?? 'User tidak ditemukan atau password salah',
          );
        }
      }
    } catch (e) {
      isLoading = false;
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (context.mounted) {
        CustomDialog.messageResponse(
          context,
          'Terjadi kesalahan, silakan coba lagi.',
        );
      }
    }

    notifyListeners();
  }

  void _navigateToMenu() {
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MenuPage()),
        (route) => false,
      );
    }
  }

  Future<void> logout() async {
    if (users != null) {
      if (context.mounted) CustomDialog.loading(context);

      try {
        final result = await AuthRepository.logOut(
          NetworkURL.logout(),
          users!.bprId,
          users!.usersId,
          users!.usersId,
        );

        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (result['value'] == 1) {
          await Pref().hapus();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            );
          }
        } else {
          if (context.mounted) {
            CustomDialog.messageResponse(context, result['message']);
          }
        }
      } catch (e) {
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (context.mounted) {
          CustomDialog.messageResponse(context, 'Terjadi kesalahan: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }
}