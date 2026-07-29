import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../network/network.dart';
import '../../pref/pref.dart';
import '../../repository/collector_repository.dart';
import '../../repository/users_access_repository.dart';
import '../../utils/colors.dart';
import '../../utils/user_level.dart';
import '../../utils/widgets/app_data_grid.dart';
import '../data_petugas/data_petugas_notifier.dart';

// ==================== NOTIFIER ====================
class _LaporanDataPetugasNotifier extends ChangeNotifier {
  final BuildContext context;

  _LaporanDataPetugasNotifier({required this.context}) {
    _init();
  }

  List<DataPetugasModel> _list = [];
  List<DataPetugasModel> get list => _list;

  List<DataPetugasModel> _filteredList = [];
  List<DataPetugasModel> get filteredList => _filteredList;

  final List<KantorDummy> _listKantor = [];

  bool isLoading = true;
  String _searchKeyword = '';
  Timer? _debounceTimer;
  UsersModel? _sessionUser;

  final searchCtrl = TextEditingController();

  int get jumlahDibuka => _list.where((p) => p.stsBukaTutup == 'A').length;
  int get jumlahDitutup => _list.where((p) => p.stsBukaTutup == 'C').length;
  int get jumlahDiblokir => _list.where((p) => p.stsBukaTutup == 'B').length;

  String getNamaKantor(String? kdKantor) {
    if (kdKantor == null || kdKantor.isEmpty) return '-';
    final found = _listKantor.firstWhere(
      (k) => k.kdKantor == kdKantor,
      orElse: () => KantorDummy('', '', ''),
    );
    return found.namaKantor.isEmpty ? kdKantor : found.namaKantor;
  }

  Future<void> _init() async {
    _sessionUser = await Pref().getUsers();
    await loadAll();
  }

  Future<void> loadAll() async {
    if (_sessionUser == null) return;
    isLoading = true;
    notifyListeners();
    await Future.wait([_loadPetugas(), _loadKantor()]);
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPetugas() async {
    try {
      final result = await CollectorRepository.inquiryCollector(limit: 500);
      if (kDebugMode) print('LAPORAN KOLEKTOR: ${result['value']}');
      if (result['value'] == 1) {
        final List<dynamic> data = result['data'] ?? [];
        final allList = data
            .map((item) => DataPetugasModel.fromJson(item as Map<String, dynamic>))
            .toList();

        // PATCH: status buka/tutup diambil dari database lokal (sama persis
        // sumber yang dipakai menu Buka/Tutup Transaksi, sudah terbukti
        // akurat) — bukan dari field 'transaksi_kolektor' hasil middleware
        // yang kadang gak sinkron sama tombol buka/tutup yang sebenarnya.
        await _overrideBukaTutupFromLocalDb(allList);

        _list = UserLevelHelper.applyKantorFilter(
          list: allList,
          users: _sessionUser,
          getKdKantor: (p) => p.kdKantor,
        );
      } else {
        _list = [];
      }
    } catch (e) {
      if (kDebugMode) print('ERROR LAPORAN KOLEKTOR: $e');
      _list = [];
    }
    _applyFilter();
    notifyListeners();
  }

  Future<void> _overrideBukaTutupFromLocalDb(List<DataPetugasModel> list) async {
    try {
      final dbResult = await CollectorRepository.inquiryCollectorDb(limit: 1000);
      if (dbResult['value'] != 1) {
        if (kDebugMode) print('BUKA_TUTUP: gagal ambil inquiry-db: ${dbResult['message']}');
        return;
      }
      final List<dynamic> dbRows = dbResult['data'] ?? [];
      final Map<String, String> stsByNoHp = {
        for (final row in dbRows)
          if ((row['nohp'] ?? '').toString().trim().isNotEmpty)
            row['nohp'].toString().trim():
                (row['stsaktif'] ?? 'C').toString().toUpperCase(),
      };
      for (final petugas in list) {
        final key = (petugas.noHp ?? '').trim();
        if (key.isEmpty) continue;
        if (stsByNoHp.containsKey(key)) {
          final sts = stsByNoHp[key]!;
          petugas.stsBukaTutup = sts;
          petugas.transaksiKolektor = sts == 'A';
        }
      }
    } catch (e) {
      if (kDebugMode) print('BUKA_TUTUP: error override dari DB lokal: $e');
    }
  }

  Future<void> _loadKantor() async {
    try {
      final session = await Pref().getUsers();
      final result = await UsersAccessRepository.getListKantor(
        url: NetworkURL.getListKantorAccess(),
        userId: session.usersId,
        bprId: session.bprId,
      );
      if (result['value'] == 1) {
        final List<dynamic> data = result['kantor'] ?? [];
        _listKantor.clear();
        for (final k in data) {
          final m = k as Map<String, dynamic>;
          _listKantor.add(KantorDummy(
            (m['kd_kantor'] ?? m['kdkantor'] ?? '').toString(),
            (m['nama_kantor'] ?? m['namakantor'] ?? '').toString(),
            session.bprId,
          ));
        }
      }
    } catch (_) {}
  }

  void _applyFilter() {
    final kw = _searchKeyword.trim().toLowerCase();
    if (kw.isEmpty) {
      _filteredList = List.from(_list);
    } else {
      _filteredList = _list.where((p) {
        return (p.nama ?? '').toLowerCase().contains(kw) ||
            (p.noHp ?? '').toLowerCase().contains(kw) ||
            (p.nip ?? '').toLowerCase().contains(kw);
      }).toList();
    }
    const order = {'A': 0, 'C': 1, 'B': 2};
    _filteredList.sort((a, b) {
      final sa = order[a.stsBukaTutup] ?? 9;
      final sb = order[b.stsBukaTutup] ?? 9;
      if (sa != sb) return sa.compareTo(sb);
      return (a.nama ?? '').toLowerCase().compareTo((b.nama ?? '').toLowerCase());
    });
    notifyListeners();
  }

  void onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _searchKeyword = value;
      _applyFilter();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }
}

// ==================== PAGE ====================
class LaporanDataPetugasPage extends StatelessWidget {
  const LaporanDataPetugasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _LaporanDataPetugasNotifier(context: context),
      child: Consumer<_LaporanDataPetugasNotifier>(
        builder: (context, notifier, _) => Scaffold(
          backgroundColor: const Color(0xffF3F5F4),
          body: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: notifier.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: notifier.loadAll,
                        child: _buildTable(notifier),
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
        'Laporan Data Kolektor',
        style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTable(_LaporanDataPetugasNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _badge('Total: ${notifier.list.length}', Colors.black),
                  _badge('Dibuka: ${notifier.jumlahDibuka}', Colors.green),
                  _badge('Ditutup: ${notifier.jumlahDitutup}', Colors.red),
                  _badge('Diblokir: ${notifier.jumlahDiblokir}', Colors.orange),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 250,
                child: TextField(
                  controller: notifier.searchCtrl,
                  onChanged: notifier.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari Nama atau No HP',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AppDataGrid(
            columns: _buildColumns(notifier),
            rows: _buildRows(notifier),
            onSelectionChanged: (added, removed) {},
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  List<AppGridColumn> _buildColumns(_LaporanDataPetugasNotifier notifier) => [
        const AppGridColumn('no', 'No', width: 60, align: Alignment.center),
        const AppGridColumn('nama', 'Nama Kolektor', width: 360),
        const AppGridColumn('noHp', 'No HP', width: 320),
        const AppGridColumn('kantor', 'Kantor', width: 320),
        AppGridColumn('statusBukaTutup', 'Status',
            width: 180,
            align: Alignment.center,
            cellBuilder: (value) => _statusBadge(value, _statusBukaTutupColor(value.toString()))),
      ];

  List<Map<String, dynamic>> _buildRows(_LaporanDataPetugasNotifier notifier) {
    int no = 0;
    return notifier.filteredList.map((p) {
      return {
        'no': ++no,
        'nama': p.nama ?? '-',
        'noHp': p.noHp ?? '-',
        'kantor': notifier.getNamaKantor(p.kdKantor),
        'statusBukaTutup': _labelBukaTutup(p.stsBukaTutup),
      };
    }).toList();
  }

  String _labelBukaTutup(String? sts) {
    switch (sts) {
      case 'A':
        return 'Dibuka';
      case 'B':
        return 'Diblokir';
      case 'C':
      default:
        return 'Ditutup';
    }
  }

  Color _statusBukaTutupColor(String label) {
    switch (label) {
      case 'Dibuka':
        return Colors.green;
      case 'Diblokir':
        return Colors.orange;
      case 'Ditutup':
      default:
        return Colors.red;
    }
  }

  Widget _statusBadge(dynamic value, Color color) {
    final label = value.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
