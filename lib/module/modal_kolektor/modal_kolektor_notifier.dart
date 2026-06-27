import 'package:cis_menu/repository/collector_repository.dart';
import 'package:cis_menu/repository/modal_kolektor_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ModalKolektorNotifier extends ChangeNotifier {
  final BuildContext context;
  ModalKolektorNotifier({required this.context}) {
    _load();
  }

  bool isLoading = true;
  bool isSaving = false;
  String? errorMsg;

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> _allPetugas = [];

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();
  final searchCtrl = TextEditingController();
  final noHpCtrl = TextEditingController();
  final nominalCtrl = TextEditingController();
  final keteranganCtrl = TextEditingController();

  String? selectedPetugasHp;
  String? selectedPetugasNama;
  bool showDropdown = false;

  // Untuk action drawer
  Map<String, dynamic>? selectedItem;

  final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  Future<void> _load() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      final resPetugas = await CollectorRepository.inquiryCollector(limit: 200);
      if (resPetugas['value'] == 1) {
        _allPetugas = List<Map<String, dynamic>>.from(resPetugas['data'] ?? []);
      }

      final resModal = await ModalKolektorRepository.inquiry();
      if (resModal['value'] == 1) {
        items = List<Map<String, dynamic>>.from(resModal['data'] ?? []);
      } else {
        errorMsg = resModal['message'];
      }
    } catch (e) {
      errorMsg = 'Gagal memuat data: $e';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => _load();

  // ── TypeAhead ──────────────────────────────────────────────────────────────
  List<String> getSuggestions(String q) {
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    return _allPetugas
        .where((p) {
          final nama = (p['nama'] ?? '').toString().toLowerCase();
          final hp = (p['nohp'] ?? '').toString();
          return nama.contains(lower) || hp.contains(lower);
        })
        .map((p) => '${p['nama']} (${p['nohp']})')
        .take(8)
        .toList();
  }

  void onPetugasSelected(String suggestion) {
    final match = _allPetugas.firstWhere(
      (p) => '${p['nama']} (${p['nohp']})' == suggestion,
      orElse: () => {},
    );
    if (match.isNotEmpty) {
      selectedPetugasHp = match['nohp']?.toString() ?? '';
      selectedPetugasNama = match['nama']?.toString() ?? '';
      noHpCtrl.text = selectedPetugasHp ?? '';
      searchCtrl.text = suggestion;
    }
    showDropdown = false;
    notifyListeners();
  }

  void toggleDropdown(bool val) {
    showDropdown = val;
    notifyListeners();
  }

  void onNominalChanged(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) { nominalCtrl.clear(); notifyListeners(); return; }
    final number = int.tryParse(digits) ?? 0;
    final formatted = NumberFormat('#,###', 'id_ID').format(number);
    nominalCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    notifyListeners();
  }

  double get nominalValue {
    final digits = nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(digits) ?? 0;
  }

  // ── Form ──────────────────────────────────────────────────────────────────
  void openAdd() {
    _resetForm();
    scaffoldKey.currentState?.openEndDrawer();
  }

  void _resetForm() {
    selectedPetugasHp = null;
    selectedPetugasNama = null;
    searchCtrl.clear();
    noHpCtrl.clear();
    nominalCtrl.clear();
    keteranganCtrl.clear();
    showDropdown = false;
  }

  void closeDrawer() {
    _resetForm();
    selectedItem = null;
    scaffoldKey.currentState?.closeEndDrawer();
    notifyListeners();
  }

  Future<void> simpan() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedPetugasHp == null) {
      _snack('Pilih petugas terlebih dahulu', isError: true);
      return;
    }
    if (nominalValue <= 0) {
      _snack('Nominal harus lebih dari 0', isError: true);
      return;
    }
    isSaving = true;
    notifyListeners();
    try {
      final res = await ModalKolektorRepository.add(
        petugasHp: selectedPetugasHp!,
        petugasNama: selectedPetugasNama ?? '',
        nominal: nominalValue,
        keterangan: keteranganCtrl.text.trim(),
      );
      if (res['value'] == 1) {
        closeDrawer();
        await _load();
        _snack('Modal berhasil ditambahkan', isError: false);
      } else {
        _snack(res['message'] ?? 'Gagal menyimpan', isError: true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
    isSaving = false;
    notifyListeners();
  }

  // ── Action drawer (hapus) ─────────────────────────────────────────────────
  void openActionDrawer(Map<String, dynamic> item) {
    selectedItem = item;
    scaffoldKey.currentState?.openEndDrawer();
    notifyListeners();
  }

  Future<void> hapus() async {
    if (selectedItem == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Modal'),
        content: Text('Hapus modal untuk ${selectedItem!['petugas_nama']}?'),
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
    final res = await ModalKolektorRepository.delete(id: selectedItem!['id'] as int);
    if (res['value'] == 1) {
      closeDrawer();
      await _load();
      _snack('Data berhasil dihapus', isError: false);
    } else {
      _snack(res['message'] ?? 'Gagal menghapus', isError: true);
    }
  }

  String fmtNominal(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    return fmt.format(n);
  }

  String fmtStatus(String? s) => s == 'DIBERIKAN' ? 'Diberikan' : 'Menunggu';

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }
}
