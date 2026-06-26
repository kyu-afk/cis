import 'dart:convert';

import 'package:cis_menu/config/template_bootstrap.dart';
import 'package:cis_menu/config/template_config.dart';
import 'package:cis_menu/models/index.dart';
import 'package:cis_menu/module/auth/login_page.dart';
import 'package:cis_menu/network/network.dart';
import 'package:cis_menu/pref/pref.dart';
import 'package:cis_menu/utils/dialog_custom.dart';
import 'package:cis_menu/utils/dialog_loading.dart';
import 'package:cis_menu/utils/idle_logout_service.dart';
import 'package:cis_menu/network/api_client.dart';
import 'package:cis_menu/utils/informationdialog.dart';
import 'package:cis_menu/utils/url.dart';
import 'package:cis_menu/utils/user_level.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../repository/auth_repository.dart';
import '../../utils/button_custom.dart';

class MenuNotifier extends ChangeNotifier {
  final BuildContext context;

  MenuNotifier({required this.context}) {
    getProfile();
  }

  final passForm = GlobalKey<FormState>();

  List<FasilitasAddModel> listFasilitas = [];
  UsersModel? users;
  var isloading = true;

  // ==================== ROLE / LEVEL USER ====================
  // lvl 2 → Super Admin  : bypass semua fasilitas, lihat semua kantor
  // lvl 3 → System       : hanya Kantor & User Access, lihat semua kantor
  // lvl 1 → User Biasa   : tunduk pada listFasilitas, hanya kantor sendiri

  /// Super admin — bypass semua aturan akses menu (lvl 2 atau TemplateConfig.superAccess)
  bool get isSuperAdmin {
    if (TemplateConfig.superAccess) return true;
    return UserLevelHelper.isSuperAdmin(users);
  }

  /// System user — hanya boleh akses Kantor & User Access (lvl 3)
  bool get isSystemUser => UserLevelHelper.isSystem(users);

  /// Alias untuk kompatibilitas backward (dulu disebut isMasterAdmin)
  bool get isMasterAdmin => isSuperAdmin;
  // ==================== END ROLE ====================

  getProfile() async {
    isloading = true;
    listFasilitas.clear();
    notifyListeners();

    try {
      final fasilitasJson = await Pref().getFasilitas();
      users = await Pref().getUsers();

      if (kDebugMode) {
        print("RAW LOCAL STORAGE: $fasilitasJson");
      }

      final json = jsonDecode(fasilitasJson);
      if (json is List) {
        for (var i = 0; i < json.length; i++) {
          listFasilitas.add(
            FasilitasAddModel.fromJson(
              Map<String, dynamic>.from(json[i] as Map),
            ),
          );
        }
      }

      if (kDebugMode) {
        print("LIST FASILITAS LENGTH: ${listFasilitas.length}");
        for (final f in listFasilitas) {
          print("  modul=${f.modul} menu=${f.menu} submenu=${f.submenu} flag=${f.flag}");
        }
        if (isMasterAdmin) {
          print("[MenuNotifier] user level: ${UserLevelHelper.label(users)}");
          if (isSuperAdmin) print("✅ SUPER ADMIN (lvl2) - akses terbatas: Kantor, User Access, Setup, Laporan");
          if (isSystemUser) print("✅ SYSTEM (lvl3) - hanya Kantor & User Access");
        }
      }
    } finally {
      isloading = false;
      notifyListeners();

      // Mulai idle-logout timer setelah sesi berhasil dimuat.
      if (!TemplateConfig.skipLogin) {
        IdleLogoutService.start(_autoLogout);
      }
    }
  }

  /// Dipanggil oleh IdleLogoutService saat timeout atau tab di-close.
  /// Dipanggil oleh IdleLogoutService saat timeout, tab di-close, atau
  /// tab terlalu lama di background.
  ///
  /// Urutan: hit API logout → clear local prefs → redirect ke /login.
  /// Jika API gagal tetap clear prefs dan redirect agar user tidak
  /// terjebak di sesi yang sudah tidak valid.
  Future<void> _autoLogout() async {
    if (kDebugMode) print("[MenuNotifier] Auto-logout dipicu");

    // Hit API logout supaya session di server ikut ter-terminate.
    if (!TemplateConfig.skipLogin && users != null) {
      try {
        await AuthRepository.logOut(
          NetworkURL.logout(),
          users!.bprId,
          users!.usersId,
          users!.usersId,
        );
      } catch (e) {
        // Abaikan error jaringan — tetap lanjut hapus sesi lokal.
        if (kDebugMode) print("[MenuNotifier] _autoLogout API error (ignored): $e");
      }
    }

    await Pref().hapus();

    final nav = ApiClient.navigatorKey.currentState;
    nav?.pushNamedAndRemoveUntil("/login", (route) => false);
  }

  int page = 0;

  gantipage(int value) {
    page = value;
    notifyListeners();
  }

  static String _norm(String value) => value.trim().toUpperCase();

  static bool _isFlagTrue(String flag) {
    final normalized = _norm(flag);
    return normalized == 'TRUE' || normalized == '1';
  }

  /// Cek akses berdasarkan menu + submenu (case-insensitive).
  ///
  /// Super admin (lvl2) hanya boleh: Kantor, User Access, Setup, Laporan.
  /// System (lvl3) hanya true untuk Kantor dan User Access.
  /// User biasa (lvl1) cek listFasilitas.
  bool hasAccess(String menu, {String? submenu}) {
    if (isSuperAdmin) return UserLevelHelper.superAdminCanAccessMenu(menu);
    if (isSystemUser) return UserLevelHelper.systemCanAccessMenu(menu);
    if (listFasilitas.isEmpty) return false;

    final menuKey    = _norm(menu);
    final submenuKey = _norm(submenu ?? menu);

    return listFasilitas.any((akses) {
      if (!_isFlagTrue(akses.flag)) return false;
      return _norm(akses.menu) == menuKey &&
          _norm(akses.submenu) == submenuKey;
    });
  }

  /// Tampilkan grup ExpansionTile jika ada minimal satu submenu yang boleh.
  bool hasAnyInMenu(String menu, List<String> submenus) {
    if (isSuperAdmin) return UserLevelHelper.superAdminCanAccessMenu(menu);
    if (isSystemUser) return UserLevelHelper.systemCanAccessMenu(menu);
    return submenus.any((sub) => hasAccess(menu, submenu: sub));
  }

  confirmDelete() async {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(20),
            width: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Text(
                      "Konfirmasi",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Anda yakin akan keluar dari aplikasi?",
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ButtonSecondary(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        name: "Tidak",
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ButtonPrimary(
                        onTap: () {
                          Navigator.pop(context);
                          remove();
                        },
                        name: "Ya",
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  remove() async {
    CustomDialog.loading(context);

    try {
      if (!TemplateConfig.skipLogin && users != null) {
        final result = await AuthRepository.logOut(
          NetworkURL.logout(),
          users!.bprId,
          users!.usersId,
          users!.usersId,
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (result['value'] != 1) {
          if (context.mounted) {
            CustomDialog.messageResponse(
              context,
              result['message'] ?? "Logout gagal",
            );
          }
          notifyListeners();
          return;
        }
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      await Pref().remove();

      if (TemplateConfig.skipLogin) {
        await TemplateBootstrap.seedSession();
        page = 1;
        await getProfile();
        return;
      }

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
      notifyListeners();
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (context.mounted) {
        CustomDialog.messageResponse(context, e.toString());
      }
      notifyListeners();
    }
  }

  TextEditingController passLama = TextEditingController();
  TextEditingController passBaru = TextEditingController();
  TextEditingController confirmpassBaru = TextEditingController();
  TextEditingController passC = TextEditingController();

  gantipassword() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(20),
            width: 500,
            child: Form(
              key: passForm,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text("Ganti Password")),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("Password Lama", style: TextStyle(fontSize: 12)),
                  TextFormField(
                    controller: passLama,
                    obscureText: true,
                    validator: (e) {
                      if (e == null || e.isEmpty) return "Wajib diisi";
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: "Password Lama",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Password Baru", style: TextStyle(fontSize: 12)),
                  TextFormField(
                    obscureText: true,
                    controller: passBaru,
                    validator: (e) {
                      if (e == null || e.isEmpty) return "Wajib diisi";
                      if (e.length < 6) return "Minimal 6 karakter";
                      if (e.trim() == passLama.text.trim()) return "Password baru tidak boleh sama dengan password lama";
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: "Password Baru",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Konfirmasi Password Baru",
                      style: TextStyle(fontSize: 12)),
                  TextFormField(
                    obscureText: true,
                    controller: passC,
                    validator: (e) {
                      if (e == null || e.isEmpty) return "Wajib diisi";
                      if (passBaru.text.trim() != passC.text.trim()) {
                        return "Konfirmasi password harus sama";
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: "Konfirmasi Password Baru",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ButtonPrimary(
                    onTap: () {
                      confirmPass();
                    },
                    name: "Ganti Sekarang",
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
    notifyListeners();
  }

  var isLoading = false;

  Future confirmPass() async {
    if (passForm.currentState?.validate() ?? false) {
      var passwordBaru = passBaru.text.trim();
      var passwordLama = passLama.text.trim();
      var passwordNC   = passC.text.trim();

      DialogCustom().showLoading(context);
      notifyListeners();

      try {
        final result = await AuthRepository.gantiPassword(
          token,
          NetworkURL.gantipassword(),
          users!.bprId,
          users!.usersId,
          encryptString(passwordBaru),
          encryptString(passwordLama),
          passwordNC,
          users!.usersId,
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (result['value'] == 1) {
          if (context.mounted) {
            Navigator.pop(context);
            passBaru.clear();
            passLama.clear();
            passC.clear();
            informationDialog(context, "Informasi", result['message']);
          }
        } else {
          if (context.mounted) {
            informationDialog(context, "Informasi", result['message']);
          }
        }
        notifyListeners();
      } catch (e) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (context.mounted) {
          informationDialog(context, "Error", "Terjadi kesalahan: $e");
        }
      }
    }
  }

  @override
  void dispose() {
    IdleLogoutService.stop();
    passLama.dispose();
    passBaru.dispose();
    confirmpassBaru.dispose();
    passC.dispose();
    super.dispose();
  }
}