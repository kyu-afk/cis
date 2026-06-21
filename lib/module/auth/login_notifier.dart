import 'package:cis_menu/models/index.dart';
import 'package:cis_menu/pref/pref.dart';
import 'package:cis_menu/repository/auth_repository.dart';
import 'package:cis_menu/utils/dialog_custom.dart';
import 'package:flutter/material.dart';

import '../../network/network.dart';
import 'login_page.dart';
import '../menu/menu_page.dart';

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
      _navigateToMenu();
    }
    notifyListeners();
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
          _navigateToMenu();
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