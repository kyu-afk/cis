import 'package:flutter/material.dart';
import '../../repository/collector_repository.dart';
import '../../module/data_petugas/data_petugas_notifier.dart';
import '/utils/colors.dart';

class ResetMpinNotifier extends ChangeNotifier {
  final BuildContext context;

  ResetMpinNotifier({required this.context});

  bool isSearching = false;
  bool isResetting = false;
  bool showResult = false;
  int refreshKey = 0;

  final GlobalKey<FormState> keyForm = GlobalKey<FormState>();
  final TextEditingController namaPetugasInput = TextEditingController();

  final TextEditingController namaPetugasResult = TextEditingController();
  final TextEditingController noHpResult = TextEditingController();
  final TextEditingController nipResult = TextEditingController();
  final TextEditingController noSbbPetugasResult = TextEditingController();
  final TextEditingController namaSbbResult = TextEditingController();

  String _collectorId = '';
  String _noSbb = '';
  String _kdKantor = '';
  String _namaPetugas = '';

  /// ID petugas yang sudah berhasil di-reset MPIN-nya.
  /// Digunakan untuk menyembunyikan petugas tersebut dari hasil pencarian
  /// sehingga tidak bisa dipilih dan diproses ulang.
  final Set<String> excludedCollectorIds = {};

  void onPetugasSelected(DataPetugasModel petugas) {
    _collectorId = petugas.id ?? '';
    _kdKantor = petugas.kdKantor ?? '';
    _noSbb = petugas.noSbb ?? '';
    _namaPetugas = petugas.nama ?? '';

    namaPetugasResult.text = petugas.nama ?? '';
    noHpResult.text = petugas.noHp ?? '';
    nipResult.text = petugas.nip ?? '';
    noSbbPetugasResult.text = petugas.noSbb ?? '';
    namaSbbResult.text = petugas.namaSbb ?? '';
    
    showResult = true;
    notifyListeners();
  }

  void reset() {
    namaPetugasInput.clear();
    _clearResult();
    excludedCollectorIds.clear();
    refreshKey++;
    notifyListeners();
  }

  void _clearResult() {
    namaPetugasResult.clear();
    noHpResult.clear();
    nipResult.clear();
    noSbbPetugasResult.clear();
    namaSbbResult.clear();
    _collectorId = '';
    _noSbb = '';
    _kdKantor = '';
    _namaPetugas = '';
    showResult = false;
  }

  Future<void> resetMpin() async {
    if (_collectorId.isEmpty || _noSbb.isEmpty || _kdKantor.isEmpty) {
      _showInfoDialog(
        title: 'Peringatan',
        message: 'Data petugas belum lengkap',
        isSuccess: false,
      );
      return;
    }

    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    isResetting = true;
    notifyListeners();

    final result = await CollectorRepository.resetMpin(
      collectorId: _collectorId,
      noSbb: _noSbb,
      kdKantor: _kdKantor,
    );

    isResetting = false;
    notifyListeners();

    if (!context.mounted) return;

    if (result['value'] == 1) {
      excludedCollectorIds.add(_collectorId);
      _showResultDialog(
        isSuccess: true,
        message: 'MPIN berhasil direset! Petugas $_namaPetugas sekarang dapat login dengan MPIN default.',
      );
    } else {
      _showResultDialog(
        isSuccess: false,
        message: result['message']?.toString().isNotEmpty == true
            ? result['message']
            : 'Reset MPIN gagal, silakan coba lagi.',
      );
    }
  }

  Future<bool> _showConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
                const SizedBox(width: 10),
                const Text('Konfirmasi Reset MPIN',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),
              const Text('Apakah Anda yakin ingin mereset MPIN petugas ini ke default?',
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAF9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffDCE3DF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRowMini('Nama', namaPetugasResult.text),
                    const SizedBox(height: 6),
                    _infoRowMini('No HP', noHpResult.text),
                    const SizedBox(height: 6),
                    _infoRowMini('NIP', nipResult.text),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFE0B2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reset MPIN akan membuka blokir, dan mengatur percobaan salah MPIN ke 0',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colortextwhite,
                      backgroundColor: colorcancel,
                      side: const BorderSide(color: Colors.transparent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorPrimary,
                      foregroundColor: colortextwhite,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Reset'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  void _showResultDialog({required bool isSuccess, required String message}) {
    if (!context.mounted) return;
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
              Text(message, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
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
                  onPressed: () {
                    Navigator.pop(_);
                    if (isSuccess) reset();
                  },
                  child: const Text('OK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog({required String title, required String message, required bool isSuccess}) {
    if (!context.mounted) return;
    final color = isSuccess ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D);
    final bgColor = isSuccess ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB);
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;

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
              Text(message, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
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

  Widget _infoRowMini(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 60,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }

  @override
  void dispose() {
    namaPetugasInput.dispose();
    namaPetugasResult.dispose();
    noHpResult.dispose();
    nipResult.dispose();
    noSbbPetugasResult.dispose();
    namaSbbResult.dispose();
    super.dispose();
  }
}