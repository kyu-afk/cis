// lib/module/laporan/laporan_histori_transaksi_kolektor_page.dart
//
// Histori Transaksi Kolektor — sama seperti "Laporan Transaksi Kolektor",
// tapi tanpa dikunci ke hari ini. Filter: Kolektor, Status, & Tanggal
// (opsional, default tidak ditentukan -> semua transaksi lama & hari ini muncul).

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../models/transaksi_model.dart';
import '../../pref/pref.dart';
import '../../repository/transaksi_repository.dart';
import '../../repository/setup_transaksi_repository.dart';
import '../../utils/colors.dart';
import '../../utils/widgets/app_data_grid.dart';
import '../../utils/widgets/searchable_dropdown_petugas.dart';
import '../data_petugas/data_petugas_notifier.dart';

// ==================== NOTIFIER ====================
class HistoriTransaksiKolektorNotifier extends ChangeNotifier {
  final BuildContext context;

  HistoriTransaksiKolektorNotifier({required this.context}) {
    _init();
  }

  List<TransaksiModel> _list = [];

  bool isLoading = true;
  UsersModel? _sessionUser;

  // ── Filter: Status ──
  // Sesuai nilai ASLI di kolom cis_settlement_items.status
  // (ditemukan dari data: ada, posted, failed, hapus, pending_otor).
  String _selectedStatus = 'SEMUA';
  String get selectedStatus => _selectedStatus;
  final List<String> statusOptions = const ['SEMUA', 'ADA', 'POSTED', 'PENDING OTOR', 'FAILED', 'HAPUS'];

  String _getStatusValue(String selectedStatus) {
    switch (selectedStatus) {
      case 'ADA':
        return 'ada';
      case 'POSTED':
        return 'posted';
      case 'PENDING OTOR':
        return 'pending_otor';
      case 'FAILED':
        return 'failed';
      case 'HAPUS':
        return 'hapus';
      default:
        return '';
    }
  }

  // ── Filter: Kolektor (default: belum dipilih = semua kolektor) ──
  DataPetugasModel? _selectedKolektor;
  DataPetugasModel? get selectedKolektor => _selectedKolektor;
  final kolektorSearchCtrl = TextEditingController();

  // ── Filter: Tanggal (default: TIDAK DITENTUKAN = semua tanggal tampil) ──
  DateTime? _tanggal;
  DateTime? get tanggal => _tanggal;

  int get totalData => _tableRows.length;

  // Terjemahan trx_code -> keterangan, sumbernya sama persis dengan
  // "Setup Transaksi Collector" (SetupTransaksiRepository.listTcode()).
  Map<String, String> _tcodeKeterangan = {};

  List<Map<String, dynamic>> _tableRows = [];
  List<Map<String, dynamic>> get tableRows => _tableRows;

  String getNamaStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'ada':
        return 'ADA';
      case 'posted':
        return 'POSTED';
      case 'pending_otor':
        return 'PENDING OTOR';
      case 'failed':
        return 'GAGAL';
      case 'hapus':
        return 'DIHAPUS';
      default:
        return (status ?? '-').toUpperCase();
    }
  }

  Future<void> _init() async {
    _sessionUser = await Pref().getUsers();
    await _loadTcodeKeterangan();
    await loadData();
  }

  Future<void> _loadTcodeKeterangan() async {
    try {
      final result = await SetupTransaksiRepository.listTcode();
      if (result['value'] == 1) {
        final List<dynamic> data = result['data'] ?? [];
        _tcodeKeterangan = {
          for (final e in data)
            (e['tcode'] ?? '').toString(): (e['keterangan'] ?? '').toString(),
        };
      }
    } catch (e) {
      if (kDebugMode) print('ERROR LOAD TCODE: $e');
    }
  }

  Future<void> loadData() async {
    if (_sessionUser == null) return;

    // Sesuai desain: tabel HANYA terisi kalau kolektor sudah dipilih.
    // Belum pilih kolektor -> kosongkan tabel, tidak usah hit API.
    if (_selectedKolektor == null) {
      _list = [];
      _buildTableRows();
      isLoading = false;
      notifyListeners();
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      final statusValue = _selectedStatus == 'SEMUA' ? null : _getStatusValue(_selectedStatus);
      // Satu tanggal saja: kalau dipilih, tglFrom = tglTo = tanggal itu
      // (cuma tanggal itu yang tampil). Kalau tidak dipilih, tidak dibatasi
      // sama sekali (transaksi kapan pun tampil).
      final tanggalStr = _tanggal != null ? DateFormat('yyyy-MM-dd').format(_tanggal!) : null;

      final result = await TransaksiRepository.inquirySettlementItemsDb(
        bprId: _sessionUser!.bprId,
        userid: _selectedKolektor!.userId,
        nohp: _selectedKolektor!.noHp,
        tglFrom: tanggalStr,
        tglTo: tanggalStr,
        status: statusValue,
      );

      if (result['value'] == 1) {
        final List<dynamic> data = result['data'] ?? [];
        _list = data.map((item) => TransaksiModel.fromJson(item)).toList();
        _list.sort((a, b) {
          final dateA = _parseDate(a.tglTrans);
          final dateB = _parseDate(b.tglTrans);
          return dateB.compareTo(dateA);
        });
      } else {
        _list = [];
        if (kDebugMode) print('Error load histori transaksi: ${result['message']}');
      }
    } catch (e) {
      if (kDebugMode) print('ERROR HISTORI TRANSAKSI KOLEKTOR: $e');
      _list = [];
    }

    _buildTableRows();
    isLoading = false;
    notifyListeners();
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime(2000, 1, 1);
    try {
      return DateFormat('yyyy-MM-dd').parse(dateStr);
    } catch (_) {
      try {
        return DateFormat('dd/MM/yyyy').parse(dateStr);
      } catch (_) {
        return DateTime(2000, 1, 1);
      }
    }
  }

  String _formatRupiah(String? value) {
    if (value == null || value.isEmpty || value == '-') return '-';
    final number = double.tryParse(value);
    if (number == null) return value;
    return NumberFormat('#,##0', 'id_ID').format(number.toInt());
  }

  void _buildTableRows() {
    _tableRows = _list.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;

      // Kolom "Transaksi": prioritas ambil dari daftar Setup Transaksi
      // Collector (trx_code -> keterangan), fallback ke keterangan bawaan
      // transaksi itu sendiri kalau tcode-nya gak ketemu di daftar.
      final transaksiLabel = _tcodeKeterangan[item.trxCode] ??
          ((item.keterangan != null && item.keterangan!.isNotEmpty)
              ? item.keterangan!
              : (item.trxCode != null && item.trxCode!.isNotEmpty)
                  ? item.trxCode!
                  : '-');

      return {
        'no': (index + 1).toString(),
        'keterangan': transaksiLabel,
        'status': getNamaStatus(item.status),
        'tgl_trans': item.tglTrans ?? '-',
        // Nama pemilik rekening (nasabah) lawan transaksi kolektor —
        // langsung dari API, bukan hasil lookup no_hp kolektor.
        'nama': (item.namaNasabah != null && item.namaNasabah!.isNotEmpty) ? item.namaNasabah! : '-',
        'no_rek': item.norekening ?? '-',
        'jumlah': _formatRupiah(item.jumlah),
      };
    }).toList();
  }

  void onStatusChanged(String? value) {
    if (value != null) {
      _selectedStatus = value;
      loadData();
    }
  }

  void onKolektorSelected(DataPetugasModel k) {
    _selectedKolektor = k;
    notifyListeners();
    loadData();
  }

  void clearKolektor() {
    _selectedKolektor = null;
    kolektorSearchCtrl.clear();
    // Kolektor dikosongkan -> tabel ikut dikosongkan (lihat loadData()).
    notifyListeners();
    loadData();
  }

  void onTanggalChanged(DateTime? date) {
    _tanggal = date;
    loadData();
  }

  @override
  void dispose() {
    kolektorSearchCtrl.dispose();
    super.dispose();
  }
}

// ==================== PAGE ====================
class HistoriTransaksiKolektorPage extends StatelessWidget {
  const HistoriTransaksiKolektorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HistoriTransaksiKolektorNotifier(context: context),
      child: Consumer<HistoriTransaksiKolektorNotifier>(
        builder: (context, notifier, _) => Scaffold(
          backgroundColor: const Color(0xffF3F5F4),
          body: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: notifier.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: notifier.loadData,
                        child: _buildContent(context, notifier),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      color: colorPrimary,
      child: const Text(
        'Histori Transaksi Kolektor',
        style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildContent(BuildContext context, HistoriTransaksiKolektorNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterSection(context, notifier),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildBadges(notifier),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: notifier.selectedKolektor == null
                ? _buildEmptyKolektorHint()
                : AppDataGrid(
                    columns: _buildColumns(),
                    rows: notifier.tableRows,
                    pageSize: 10,
                  ),
          ),
        ],
      ),
    );
  }

  List<AppGridColumn> _buildColumns() => [
        const AppGridColumn('keterangan', 'Transaksi', width: 200, align: Alignment.centerLeft),
        const AppGridColumn('status', 'Status', width: 160, align: Alignment.centerLeft),
        const AppGridColumn('tgl_trans', 'Tanggal', width: 220, align: Alignment.centerLeft),
        const AppGridColumn('nama', 'Nama', width: 240, align: Alignment.centerLeft),
        const AppGridColumn('no_rek', 'No Rek', width: 220, align: Alignment.centerLeft),
        AppGridColumn('jumlah', 'Nilai', width: 160, align: Alignment.centerRight, headerAlign: Alignment.centerLeft),
      ];

  Widget _buildFilterSection(BuildContext context, HistoriTransaksiKolektorNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Kolektor ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kolektor', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                SearchableDropdownPetugas(
                  controller: notifier.kolektorSearchCtrl,
                  hintText: 'Pilih Kolektor',
                  onPetugasSelected: notifier.onKolektorSelected,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ── Status ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: notifier.selectedStatus,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      items: notifier.statusOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: notifier.onStatusChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ── Tanggal — opsional (kosong = semua tanggal) ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tanggal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                _datePickerField(
                  context: context,
                  value: notifier.tanggal,
                  onChanged: notifier.onTanggalChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePickerField({
    required BuildContext context,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020, 1, 1),
          lastDate: DateTime.now(),
          initialDate: value ?? DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: colorPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value == null ? 'Tidak ditentukan' : DateFormat('dd/MM/yyyy').format(value),
                style: TextStyle(
                  color: value == null ? Colors.grey.shade600 : Colors.black87,
                  fontSize: 13,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close, size: 14, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyKolektorHint() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Pilih kolektor terlebih dahulu untuk melihat histori transaksinya',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadges(HistoriTransaksiKolektorNotifier notifier) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _badge('Total: ${notifier.totalData}', Colors.black),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
