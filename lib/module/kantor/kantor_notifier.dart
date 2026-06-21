import 'package:cis_menu/models/index.dart';
import 'package:cis_menu/pref/pref.dart';
import 'package:cis_menu/repository/kantor_repository.dart';
import 'package:cis_menu/utils/dialog_loading.dart';
import 'package:flutter/material.dart';
import 'package:cis_menu/utils/colors.dart';

import '../../network/network.dart';

class KantorNotifier extends ChangeNotifier {
  final BuildContext context;

  KantorNotifier({required this.context}) {
    getProfile();
  }

  UsersModel? users;

  getProfile() async {
    Pref().getUsers().then((value) {
      users = value;
      getKantor();
      notifyListeners();
    });
  }

  var isLoading = true;
  List<KantorModel> list = [];
  List<KantorModel> listResult = [];
  KantorModel? kantorModel;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  List<SandiBankModel> listSandi = [];
  SandiBankModel? sandiBankModel;

  // ── Drawer state ──
  // 'aksi' | 'tambah' | 'edit' | 'hapus'
  String drawerMode = 'tambah';
  bool isSaving = false;

  TextEditingController namakantor = TextEditingController();
  TextEditingController kdKantor = TextEditingController();
  final keyForm = GlobalKey<FormState>();

  // ── Drawer helpers ──
  void closeDrawer() {
    Navigator.of(context, rootNavigator: false).pop();
  }

  void openDrawerForTambah() {
    drawerMode = 'tambah';
    kantorModel = null;
    namakantor.clear();
    kdKantor.clear();
    notifyListeners();
    key.currentState!.openEndDrawer();
  }

  void openDrawerForAction(KantorModel k) {
    drawerMode = 'aksi';
    kantorModel = k;
    namakantor.text = k.namaKantor ?? '';
    kdKantor.text = k.kdKantor ?? '';
    notifyListeners();
    key.currentState!.openEndDrawer();
  }

  void openDrawerForEdit() {
    drawerMode = 'edit';
    notifyListeners();
  }

  void openDrawerForHapus() {
    drawerMode = 'hapus';
    notifyListeners();
  }

  void goBackToActionMenu() {
    drawerMode = 'aksi';
    notifyListeners();
  }

  String get drawerTitle {
    switch (drawerMode) {
      case 'tambah':
        return 'Tambah Kantor';
      case 'edit':
        return 'Edit Kantor';
      case 'hapus':
        return 'Hapus Kantor';
      default:
        return 'Kantor';
    }
  }

  // ── Simpan (tambah / edit) ──
  Future<void> simpan() async {
    if (!keyForm.currentState!.validate()) return;
    isSaving = true;
    notifyListeners();

    try {
      Map<String, dynamic> value;
      if (drawerMode == 'edit') {
        value = await KantorRepository.updateKantorCMS(
          token,
          NetworkURL.updateKantorCMS(),
          users!.bprId,
          users!.usersId,
          users!.bprId,
          kdKantor.text.trim(),
          namakantor.text.trim(),
        );
      } else {
        value = await KantorRepository.insertKantorCMS(
          token,
          NetworkURL.insertKantorCMS(),
          users!.bprId,
          users!.usersId,
          users!.bprId,
          kdKantor.text.trim(),
          namakantor.text.trim(),
        );
      }

      closeDrawer();
      if (value['value'] == 1) {
        await getKantor();
        _showResultDialog(isSuccess: true, message: value['message'] ?? 'Berhasil disimpan!');
      } else {
        _showResultDialog(isSuccess: false, message: value['message'] ?? 'Gagal menyimpan');
      }
    } catch (e) {
      closeDrawer();
      _showResultDialog(isSuccess: false, message: e.toString());
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // ── Hapus ──
  Future<void> hapus() async {
    isSaving = true;
    notifyListeners();
    DialogCustom().showLoading(context);
    try {
      final value = await KantorRepository.deleteKantorCMS(
        token,
        NetworkURL.deleteKantorCMS(),
        users!.bprId,
        users!.usersId,
        users!.bprId,
        kdKantor.text.trim(),
        namakantor.text.trim(),
      );
      Navigator.pop(context); // loading
      closeDrawer();
      if (value['value'] == 1) {
        await getKantor();
        _showResultDialog(isSuccess: true, message: value['message'] ?? 'Kantor berhasil dihapus!');
      } else {
        _showResultDialog(isSuccess: false, message: value['message'] ?? 'Gagal menghapus kantor');
      }
    } catch (e) {
      Navigator.pop(context);
      closeDrawer();
      _showResultDialog(isSuccess: false, message: e.toString());
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // ── Load data ──
  Future getKantor() async {
    isLoading = true;
    list.clear();
    listSandi.clear();
    notifyListeners();

    KantorRepository.getKantor(
      token,
      NetworkURL.getListKantorAccess(),
      users!.usersId,
      users!.bprId,
    ).then((value) {
      if (value['value'] == 1) {
        for (Map<String, dynamic> i in value['data']) {
          list.add(KantorModel.fromJson(i));
        }

        if (value['sandi_bank'] != null) {
          for (Map<String, dynamic> i in value['sandi_bank']) {
            listSandi.add(SandiBankModel.fromJson(i));
          }
        }

        if (listSandi.isEmpty && users != null) {
          try {
            listSandi.add(
              SandiBankModel.fromJson({
                "kode_bank": users!.bprId,
                "nama": users!.bprId,
              }),
            );
          } catch (_) {}
        }

        if (listSandi.isNotEmpty) {
          sandiBankModel = listSandi.first;
        }

        listResult = list.where((element) => element.bpr_id != null).toList();
        isLoading = false;
        notifyListeners();
      } else {
        isLoading = false;
        notifyListeners();
      }
    }).catchError((e) {
      isLoading = false;
      notifyListeners();
      _showResultDialog(isSuccess: false, message: e.toString());
    });
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
}