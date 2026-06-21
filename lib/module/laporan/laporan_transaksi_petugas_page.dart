// lib/module/laporan/laporan_transaksi_petugas_page.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../models/transaksi_model.dart';
import '../../pref/pref.dart';
import '../../repository/transaksi_repository.dart';
import '../../repository/collector_repository.dart';
import '../../utils/colors.dart';
import '../../utils/widgets/app_data_grid.dart';
import '../data_petugas/data_petugas_notifier.dart';

// ==================== NOTIFIER ====================
class _LaporanTransaksiPetugasNotifier extends ChangeNotifier {
  final BuildContext context;

  _LaporanTransaksiPetugasNotifier({required this.context}) {
    _init();
  }

  List<TransaksiModel> _list = [];
  List<TransaksiModel> get list => _list;

  List<TransaksiModel> _filteredList = [];
  List<TransaksiModel> get filteredList => _filteredList;

  bool isLoading = true;
  String _searchKeyword = '';
  Timer? _debounceTimer;
  UsersModel? _sessionUser;

  // Filter tanggal
  DateTime? _tanggalDari;
  DateTime? _tanggalSampai;
  String _selectedStatus = 'SEMUA';

  final searchCtrl = TextEditingController();

  final List<String> _statusOptions = ['SEMUA', 'PENDING', 'POSTING', 'SETELMEN', 'TIMEOUT'];

  String _getStatusValue(String selectedStatus) {
    switch (selectedStatus) {
      case 'TIMEOUT':
        return 'timeout';
      case 'PENDING':
        return 'pending';
      case 'POSTING':
        return 'posting';
      case 'SETELMEN':
        return 'setelmen';
      default:
        return '';
    }
  }

  // Default tanggal adalah hari ini
  DateTime get defaultTanggalDari {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get defaultTanggalSampai {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get totalData => _filteredList.length;

  List<Map<String, dynamic>> _tableRows = [];
  List<Map<String, dynamic>> get tableRows => _tableRows;

  // Data untuk popup detail
  Map<String, dynamic>? _selectedDetailData;
  Map<String, dynamic>? get selectedDetailData => _selectedDetailData;

  String getNamaStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return 'PENDING';
      case 'POSTING':
        return 'POSTING';
      case 'SETELMEN':
        return 'SETELMEN';
      case 'TIMEOUT':
        return 'TIMEOUT';
      default:
        return status ?? '-';
    }
  }

  Future<void> _init() async {
    _sessionUser = await Pref().getUsers();
    _tanggalDari = defaultTanggalDari;
    _tanggalSampai = defaultTanggalSampai;
    await loadData();
  }

  Future<void> loadData() async {
    if (_sessionUser == null) return;
    isLoading = true;
    notifyListeners();

    try {
      // PERBAIKAN: Gunakan _getStatusValue() untuk konversi status
      final statusValue = _selectedStatus == 'SEMUA' ? null : _getStatusValue(_selectedStatus);
      
      if (kDebugMode) {
        print('🔍 FILTER STATUS: $_selectedStatus -> $statusValue');
      }

      final result = await TransaksiRepository.inquiryTransaksi(
        bprId: _sessionUser!.bprId,
        userLogin: _sessionUser!.usersId,
        tglFrom: _tanggalDari != null ? DateFormat('yyyy-MM-dd').format(_tanggalDari!) : null,
        tglTo: _tanggalSampai != null ? DateFormat('yyyy-MM-dd').format(_tanggalSampai!) : null,
        status: statusValue, // PERBAIKAN: Gunakan statusValue
        page: 1,
        size: 500,
      );

      if (result['value'] == 1) {
        final List<dynamic> data = result['data'] ?? [];
        _list = data.map((item) => TransaksiModel.fromJson(item)).toList();
        
        // Sorting berdasarkan created_at dari yang terbaru
        _list.sort((a, b) {
          final dateA = _parseDate(a.tglTrans);
          final dateB = _parseDate(b.tglTrans);
          return dateB.compareTo(dateA);
        });
      } else {
        _list = [];
        if (kDebugMode) {
          print('Error load transaksi: ${result['message']}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR LAPORAN TRANSAKSI: $e');
      }
      _list = [];
    }

    _applyFilter();
    isLoading = false;
    notifyListeners();
  }

  // Helper untuk parsing tanggal
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

  void _applyFilter() {
    final kw = _searchKeyword.trim().toLowerCase();

    if (kw.isEmpty) {
      _filteredList = List.from(_list);
    } else {
      _filteredList = _list.where((item) {
        return (item.noHp?.toLowerCase().contains(kw) ?? false) ||
            (item.noreff?.toLowerCase().contains(kw) ?? false) ||
            (item.keterangan?.toLowerCase().contains(kw) ?? false);
      }).toList();
    }

    _buildTableRows();
    notifyListeners();
  }

  String _formatRupiah(String? value) {
    if (value == null || value.isEmpty || value == '-') return '-';
    final number = double.tryParse(value);
    if (number == null) return value;
    final formatted = NumberFormat('#,##0', 'id_ID').format(number.toInt());
    return '$formatted';
  }

  void _buildTableRows() {
    _tableRows = _filteredList.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final statusLabel = getNamaStatus(item.status);

      return {
        'no': (index + 1).toString(),
        'tgl_trans': item.tglTrans ?? '-',
        'noreff': item.noreff ?? '-',
        'no_hp': item.noHp ?? '-',
        'no_rek': item.norekening ?? '-',
        'keterangan': item.keterangan ?? '-',
        'jumlah': _formatRupiah(item.jumlah),
        'status': statusLabel,
        '_raw_data': item.toJson(),
      };
    }).toList();
  }

  void onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _searchKeyword = value;
      _applyFilter();
    });
  }

  void onTanggalDariChanged(DateTime? date) {
    _tanggalDari = date;
    loadData();
  }

  void onTanggalSampaiChanged(DateTime? date) {
    _tanggalSampai = date;
    loadData();
  }

  void onStatusChanged(String? value) {
    if (value != null) {
      _selectedStatus = value;
      loadData();
    }
  }

  void clearSearch() {
    searchCtrl.clear();
    _searchKeyword = '';
    _applyFilter();
  }

  // ==================== POPUP DETAIL ====================
  Future<void> showDetailPopup(BuildContext context, Map<String, dynamic> rowData) async {
    final rawData = rowData['_raw_data'] as Map<String, dynamic>? ?? {};
    
    String namaPetugas = '-';
    final noHp = rawData['nohp']?.toString() ?? '';
    
    if (noHp.isNotEmpty) {
      try {
        final result = await CollectorRepository.inquiryCollector(
          filterNama: '',
          limit: 100,
        );
        if (result['value'] == 1) {
          final List<dynamic> data = result['data'] ?? [];
          for (var item in data) {
            final petugas = DataPetugasModel.fromJson(item as Map<String, dynamic>);
            if (petugas.noHp == noHp) {
              namaPetugas = petugas.nama ?? '-';
              break;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error get nama petugas: $e');
      }
    }

    _selectedDetailData = {
      'nohp': rawData['nohp'] ?? '-',
      'nama_petugas': namaPetugas,
      'no_rek': rawData['no_rek'] ?? '-',
      'trx_code': rawData['trx_code'] ?? '-',
      'trx_type': rawData['trx_type'] ?? '-',
      'amount': _formatRupiah(rawData['amount']?.toString()),
      'biaya_layanan': _formatRupiah(rawData['biaya_layanan']?.toString()),
      'fee_bpr': _formatRupiah(rawData['fee_bpr']?.toString()),
      'noreff': rawData['noreff'] ?? '-',
      'tgl_trans': rawData['tgl_trans'] ?? '-',
      'keterangan': rawData['keterangan'] ?? '-',
      'status': getNamaStatus(rawData['status']?.toString()),
    };
    notifyListeners();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DetailPopup(
        data: _selectedDetailData!,
        onClose: () {
          _selectedDetailData = null;
          notifyListeners();
        },
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }
}

// ==================== POPUP DETAIL ====================
class _DetailPopup extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onClose;

  const _DetailPopup({required this.data, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: colorPrimary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: colortextwhite, size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    'Detail Transaksi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colortextwhite,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: colortextwhite, size: 22),
                    onPressed: () {
                      onClose();
                      Navigator.pop(context);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('No HP', data['nohp'] ?? '-'),
                  const SizedBox(height: 8),
                  _detailRow('Nama Petugas', data['nama_petugas'] ?? '-'),
                  const SizedBox(height: 8),
                  _detailRow('Kode Transaksi', data['trx_code'] ?? '-'),
                  const SizedBox(height: 8),
                  _detailRow('Tipe Transaksi', data['trx_type'] ?? '-'),
                  const SizedBox(height: 8),
                  _detailRow('No Rekening', data['no_rek'] ?? '-'),
                  const SizedBox(height: 8),
                  _detailRow('Transaksi', data['keterangan'] ?? '-'),
                  const SizedBox(height: 8),
                  _detailRow('Nilai', data['amount'] ?? '-'),
                  const SizedBox(height: 8),
                  _detailRow('Biaya Layanan', data['biaya_layanan'] ?? '-'),
                  const SizedBox(height: 8),
                  _detailRow('Fee BPR', data['fee_bpr'] ?? '-'),
                  const SizedBox(height: 8),
                  _detailRow('No Referensi', data['noreff'] ?? '-'),
                  const SizedBox(height: 8),
                  _detailRow('Tanggal Transaksi', data['tgl_trans'] ?? '-'),
                  const SizedBox(height: 8),
                  _detailRow('Status', data['status'] ?? '-'),
                  const SizedBox(height: 8),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorPrimary,
                        foregroundColor: colortextwhite,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        onClose();
                        Navigator.pop(context);
                      },
                      child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ==================== PAGE ====================
class LaporanTransaksiPetugasPage extends StatelessWidget {
  const LaporanTransaksiPetugasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _LaporanTransaksiPetugasNotifier(context: context),
      child: Consumer<_LaporanTransaksiPetugasNotifier>(
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
        'Laporan Transaksi Petugas',
        style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _LaporanTransaksiPetugasNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterSection(context, notifier),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBadges(notifier),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: notifier.searchCtrl,
                    onChanged: notifier.onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Cari No HP / No Reff',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: notifier.searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: notifier.clearSearch,
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AppDataGrid(
              columns: _buildColumns(notifier, context),
              rows: notifier.tableRows,
              pageSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  List<AppGridColumn> _buildColumns(
    _LaporanTransaksiPetugasNotifier notifier,
    BuildContext context,
  ) => [
    const AppGridColumn('tgl_trans', 'Tgl Transaksi',
        width: 140, align: Alignment.centerLeft),
    const AppGridColumn('noreff', 'No Referensi',
        width: 160, align: Alignment.centerLeft),
    const AppGridColumn('no_hp', 'No HP',
        width: 160, align: Alignment.centerLeft),
    const AppGridColumn('keterangan', 'Transaksi',
        width: 180, align: Alignment.centerLeft),
    const AppGridColumn('no_rek', 'No Rekening',
        width: 170, align: Alignment.centerLeft),
    AppGridColumn('jumlah', 'Nilai',
        width: 160, align: Alignment.centerRight, headerAlign: Alignment.centerLeft),
    const AppGridColumn('status', 'Status',
        width: 140, align: Alignment.centerLeft),
    AppGridColumn(
      'aksi',
      'Detail',
      width: 100,
      align: Alignment.center,
      isAction: true,
      cellBuilder: (_) => const Icon(Icons.visibility, size: 24, color: colorPrimary),
      onActionTap: (rowData) {
        notifier.showDetailPopup(context, rowData);
      },
    ),
  ];

  Widget _buildFilterSection(BuildContext context, _LaporanTransaksiPetugasNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
      ),
      child: Row(
        children: [
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
                      value: notifier._selectedStatus,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      items: const [
                        DropdownMenuItem(value: 'SEMUA', child: Text('SEMUA')),
                        DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                        DropdownMenuItem(value: 'POSTING', child: Text('POSTING')),
                        DropdownMenuItem(value: 'SETELMEN', child: Text('SETELMEN')),
                        DropdownMenuItem(value: 'TIMEOUT', child: Text('TIMEOUT')),
                      ],
                      onChanged: notifier.onStatusChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tgl Transaksi (Dari)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2024, 1, 1),
                      lastDate: DateTime.now(),
                      initialDate: notifier._tanggalDari ?? DateTime.now(),
                    );
                    if (picked != null) notifier.onTanggalDariChanged(picked);
                  },
                  child: Container(
                    height: 36,
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
                            notifier._tanggalDari == null
                                ? 'Pilih tanggal'
                                : DateFormat('dd/MM/yyyy').format(notifier._tanggalDari!),
                            style: TextStyle(
                              color: notifier._tanggalDari == null ? Colors.grey.shade600 : Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (notifier._tanggalDari != null)
                          GestureDetector(
                            onTap: () => notifier.onTanggalDariChanged(null),
                            child: const Icon(Icons.close, size: 14, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tgl Transaksi (Sampai)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2024, 1, 1),
                      lastDate: DateTime.now(),
                      initialDate: notifier._tanggalSampai ?? DateTime.now(),
                    );
                    if (picked != null) notifier.onTanggalSampaiChanged(picked);
                  },
                  child: Container(
                    height: 36,
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
                            notifier._tanggalSampai == null
                                ? 'Pilih tanggal'
                                : DateFormat('dd/MM/yyyy').format(notifier._tanggalSampai!),
                            style: TextStyle(
                              color: notifier._tanggalSampai == null ? Colors.grey.shade600 : Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (notifier._tanggalSampai != null)
                          GestureDetector(
                            onTap: () => notifier.onTanggalSampaiChanged(null),
                            child: const Icon(Icons.close, size: 14, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
              ]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadges(_LaporanTransaksiPetugasNotifier notifier) {
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
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}