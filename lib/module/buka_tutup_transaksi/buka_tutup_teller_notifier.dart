import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../repository/teller_repository.dart';
import '../../repository/users_access_repository.dart';
import '../../network/network.dart';
import '../../pref/pref.dart';
import '../../utils/user_level.dart';
import '../data_teller/data_teller_notifier.dart';
import '../data_teller/data_teller_stsrec.dart';
import '../../utils/colors.dart';

class KantorDummyTeller {
  final String kdKantor;
  final String namaKantor;
  KantorDummyTeller(this.kdKantor, this.namaKantor);
}

class BukaTutupTellerModel {
  final String id;
  final String nama;
  final String userId;
  final String namaKantor;
  bool transaksiDibuka;

  BukaTutupTellerModel({
    required this.id,
    required this.nama,
    required this.userId,
    required this.namaKantor,
    required this.transaksiDibuka,
  });
}

class BukaTutupTellerNotifier extends ChangeNotifier {
  final BuildContext context;

  BukaTutupTellerNotifier({required this.context}) {
    _loadData();
  }

  List<BukaTutupTellerModel> _listTeller = [];
  List<BukaTutupTellerModel> get listTeller => _listTeller;

  List<KantorDummyTeller> _listKantor = [];
  Map<String, bool> _originalStatus = {};

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
  String _bprId = '';
  UsersModel? _sessionUser; // untuk filter level user

  Future<void> _loadKantorList() async {
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
          return KantorDummyTeller(
            (m['kd_kantor'] ?? m['kdkantor'] ?? '').toString(),
            (m['nama_kantor'] ?? m['namakantor'] ?? '').toString(),
          );
        }).toList();
      }
    } catch (_) {}
  }

  String _getNamaKantor(String? kdKantor) {
    if (kdKantor == null || kdKantor.isEmpty) return '-';
    final found = _listKantor.firstWhere(
      (k) => k.kdKantor == kdKantor,
      orElse: () => KantorDummyTeller('', ''),
    );
    return found.namaKantor.isEmpty ? kdKantor : found.namaKantor;
  }

  Future<void> _loadData() async {
    isLoading = true;
    errorMessage = null;
    _originalStatus.clear();
    notifyListeners();

    try {
      final users = await Pref().getUsers();
      _bprId = users.bprId;
      _sessionUser = users;
      
      await _loadKantorList();
      
      final result = await TellerRepository.inquiryTeller(bprId: _bprId);
      
      if (result['value'] == 1) {
        final List<dynamic> data = result['data'] ?? [];
        final allTeller = data
            .map((e) => DataTellerModel.fromJson(e as Map<String, dynamic>))
            .where((t) => DataTellerStsrec.isAktif(t))
            .toList();

        // Filter per kode kantor untuk user biasa (lvl1)
        final tellerAktif = UserLevelHelper.applyKantorFilter(
          list: allTeller,
          users: _sessionUser,
          getKdKantor: (t) => t.kdKantor,
        );

        _listTeller = tellerAktif.map((t) => BukaTutupTellerModel(
          id: t.id ?? '',
          nama: t.namaTeller ?? '-',
          userId: t.userId ?? '',
          namaKantor: _getNamaKantor(t.kdKantor),
          transaksiDibuka: t.isTransaksiDibuka ?? true,
        )).toList();

        for (final t in _listTeller) {
          _originalStatus[t.id] = t.transaksiDibuka;
        }
      } else {
        errorMessage = result['message'] ?? 'Gagal memuat data teller';
      }
    } catch (e) {
      errorMessage = 'Terjadi kesalahan: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  void toggleTeller(String id, bool value) {
    final index = _listTeller.indexWhere((t) => t.id == id);
    if (index != -1) {
      _listTeller[index].transaksiDibuka = value;
      notifyListeners();
    }
  }

  void bukaSemua() {
    for (var i = 0; i < _listTeller.length; i++) {
      _listTeller[i].transaksiDibuka = true;
    }
    notifyListeners();
  }

  void tutupSemua() {
    for (var i = 0; i < _listTeller.length; i++) {
      _listTeller[i].transaksiDibuka = false;
    }
    notifyListeners();
  }

  void cancelPerubahan() {
    for (final teller in _listTeller) {
      final original = _originalStatus[teller.id] ?? true;
      teller.transaksiDibuka = original;
    }
    notifyListeners();
  }

  List<_PerubahanDataTeller> _getPerubahan() {
    final List<_PerubahanDataTeller> perubahan = [];
    
    for (final teller in _listTeller) {
      final oldStatus = _originalStatus[teller.id] ?? true;
      final newStatus = teller.transaksiDibuka;
      
      if (oldStatus != newStatus) {
        perubahan.add(_PerubahanDataTeller(
          namaTeller: teller.nama,
          oldStatus: oldStatus,
          newStatus: newStatus,
        ));
      }
    }
    
    return perubahan;
  }

  Future<bool> _showConfirmPerubahanDialog() async {
    final perubahan = _getPerubahan();
    
    if (perubahan.isEmpty) {
      _showInfoDialog('Informasi', 'Tidak ada perubahan yang disimpan');
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: colorPrimary,
                child: Row(
                  children: [
                    const Icon(Icons.sync_alt, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Konfirmasi Perubahan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 2),
                        Text('Buka/Tutup Transaksi Teller',
                            style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Periksa kembali perubahan status transaksi teller berikut:',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 14),
                    
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: SingleChildScrollView(
                        child: Column(
                          children: perubahan.map((p) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xffF8FAF9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xffDCE3DF)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.namaTeller,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
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
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: p.oldStatus ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(p.oldStatus ? 'Dibuka' : 'Ditutup',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                                      color: p.oldStatus ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D))),
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
                                            const Text('Sesudah',
                                                style: TextStyle(fontSize: 10, color: Colors.grey)),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: p.newStatus ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(p.newStatus ? 'Dibuka' : 'Ditutup',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                                      color: p.newStatus ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D))),
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

                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colortextwhite,
                            backgroundColor: colorError,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorPrimary,
                            foregroundColor: colortextwhite,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Future<bool> simpanPerubahan() async {
    final confirmed = await _showConfirmPerubahanDialog();
    if (!confirmed) return false;

    final List<BukaTutupTellerModel> tellerYangDiubah = _listTeller
        .where((t) => _originalStatus[t.id] != t.transaksiDibuka)
        .toList();

    isSaving = true;
    notifyListeners();

    bool allSuccess = true;
    final List<String> errors = [];

    for (final teller in tellerYangDiubah) {
      if (teller.userId.isEmpty) {
        errors.add('User ID teller ${teller.nama} tidak ditemukan');
        allSuccess = false;
        continue;
      }

      final result = teller.transaksiDibuka
          ? await TellerRepository.bukaTransaksiTeller(userId: teller.userId)
          : await TellerRepository.tutupTransaksiTeller(userId: teller.userId);

      if (result['value'] != 1) {
        allSuccess = false;
        errors.add('${teller.nama}: ${result['message']}');
      } else {
        _originalStatus[teller.id] = teller.transaksiDibuka;
      }
    }

    isSaving = false;
    notifyListeners();

    if (!context.mounted) return false;

    if (allSuccess) {
      _showResultDialog(true, 'Perubahan berhasil disimpan!');
      return true;
    } else {
      _showResultDialog(false, 'Gagal menyimpan perubahan:\n${errors.join('\n')}');
      return false;
    }
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: colorPrimary,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('Informasi', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorPrimary,
                          foregroundColor: colortextwhite,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(_),
                        child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
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

  void _showResultDialog(bool isSuccess, String message) {
    final color = isSuccess ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D);
    final bgColor = isSuccess ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB);
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    final title = isSuccess ? 'Berhasil' : 'Gagal';

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

  void refreshData() {
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _PerubahanDataTeller {
  final String namaTeller;
  final bool oldStatus;
  final bool newStatus;

  _PerubahanDataTeller({
    required this.namaTeller,
    required this.oldStatus,
    required this.newStatus,
  });
}