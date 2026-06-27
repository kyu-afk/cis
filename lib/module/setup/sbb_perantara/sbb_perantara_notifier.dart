import 'package:cis_menu/repository/collector_repository.dart';
import 'package:cis_menu/repository/sbb_perantara_repository.dart';
import 'package:flutter/material.dart';

class SbbPerantaraNotifier extends ChangeNotifier {
  final BuildContext context;
  SbbPerantaraNotifier({required this.context}) {
    _load();
  }

  bool isLoading = true;
  bool isSaving = false;
  bool isSearching = false;
  String? errorMsg;

  List<Map<String, dynamic>> items = [];

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();
  final noSbbCtrl = TextEditingController();
  final namaSbbCtrl = TextEditingController();

  int? editingId;

  Future<void> _load() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      final res = await SbbPerantaraRepository.inquiry();
      if (res['value'] == 1) {
        items = List<Map<String, dynamic>>.from(res['data'] ?? []);
      } else {
        errorMsg = res['message'];
      }
    } catch (e) {
      errorMsg = 'Gagal memuat data: $e';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => _load();

  void openAdd() {
    editingId = null;
    noSbbCtrl.clear();
    namaSbbCtrl.clear();
    scaffoldKey.currentState?.openEndDrawer();
  }

  void openEdit(Map<String, dynamic> item) {
    editingId = item['id'] as int?;
    noSbbCtrl.text = item['no_sbb'] ?? '';
    namaSbbCtrl.text = item['nama_sbb'] ?? '';
    scaffoldKey.currentState?.openEndDrawer();
  }

  void closeDrawer() {
    scaffoldKey.currentState?.closeEndDrawer();
    editingId = null;
    noSbbCtrl.clear();
    namaSbbCtrl.clear();
  }

  void clearNamaSbb() {
    namaSbbCtrl.clear();
    notifyListeners();
  }

  Future<void> cariSbb() async {
    final noSbb = noSbbCtrl.text.trim();
    if (noSbb.isEmpty) {
      _snack('Masukkan No SBB terlebih dahulu', isError: true);
      return;
    }
    isSearching = true;
    namaSbbCtrl.clear();
    notifyListeners();
    try {
      final result = await CollectorRepository.inquirySbbByAccount(noRek: noSbb);
      if (result['value'] == 1) {
        final nama = result['namaSbb']?.toString() ?? '';
        if (nama.isEmpty) {
          _snack('No SBB ditemukan namun nama tidak tersedia', isError: true);
        } else {
          namaSbbCtrl.text = nama;
          notifyListeners();
        }
      } else {
        _snack(result['message'] ?? 'No SBB tidak ditemukan', isError: true);
      }
    } catch (e) {
      _snack('Gagal mencari SBB: $e', isError: true);
    }
    isSearching = false;
    notifyListeners();
  }

  Future<void> simpan() async {
    if (!formKey.currentState!.validate()) return;
    if (editingId == null && namaSbbCtrl.text.trim().isEmpty) {
      _snack('Klik tombol Cari untuk verifikasi No SBB terlebih dahulu', isError: true);
      return;
    }
    isSaving = true;
    notifyListeners();
    try {
      final Map<String, dynamic> res;
      if (editingId != null) {
        res = await SbbPerantaraRepository.edit(
          id: editingId!,
          noSbb: noSbbCtrl.text.trim(),
          namaSbb: namaSbbCtrl.text.trim(),
        );
      } else {
        res = await SbbPerantaraRepository.add(
          noSbb: noSbbCtrl.text.trim(),
          namaSbb: namaSbbCtrl.text.trim(),
        );
      }
      if (res['value'] == 1) {
        closeDrawer();
        await _load();
        _snack('Data berhasil disimpan', isError: false);
      } else {
        _snack(res['message'] ?? 'Gagal menyimpan', isError: true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
    isSaving = false;
    notifyListeners();
  }

  Future<void> hapus(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus SBB Perantara'),
        content: Text('Hapus "${item['no_sbb']} - ${item['nama_sbb']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await SbbPerantaraRepository.delete(id: item['id'] as int);
    if (res['value'] == 1) {
      await _load();
      _snack('Data berhasil dihapus', isError: false);
    } else {
      _snack(res['message'] ?? 'Gagal menghapus', isError: true);
    }
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }
}
