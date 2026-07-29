import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../network/network.dart';
import '../../pref/pref.dart';
import '../../repository/teller_repository.dart';
import '../../repository/users_access_repository.dart';
import '../../utils/colors.dart';
import '../../utils/user_level.dart';
import '../../utils/widgets/app_data_grid.dart';
import '../data_teller/data_teller_notifier.dart';

// ==================== NOTIFIER ====================
class _LaporanDataTellerNotifier extends ChangeNotifier {
  final BuildContext context;

  _LaporanDataTellerNotifier({required this.context}) {
    _init();
  }

  List<DataTellerModel> _list = [];
  List<DataTellerModel> get list => _list;

  List<DataTellerModel> _filteredList = [];
  List<DataTellerModel> get filteredList => _filteredList;

  final List<KantorDummy> _listKantor = [];

  bool isLoading = true;
  String _searchKeyword = '';
  Timer? _debounceTimer;
  UsersModel? _sessionUser;
  String _bprId = '';

  final searchCtrl = TextEditingController();

  int get jumlahDibuka => _list.where((t) => t.stsBukaTutup == 'A').length;
  int get jumlahDitutup => _list.where((t) => t.stsBukaTutup == 'C').length;
  int get jumlahDiblokir => _list.where((t) => t.stsBukaTutup == 'B').length;

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
    _bprId = _sessionUser!.bprId;
    await loadAll();
  }

  Future<void> loadAll() async {
    if (_sessionUser == null) return;
    isLoading = true;
    notifyListeners();
    await Future.wait([_loadTellers(), _loadKantor()]);
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadTellers() async {
    try {
      final result = await TellerRepository.inquiryTeller(bprId: _bprId, size: 500);
      if (result['value'] == 1) {
        final rawList = result['data'] as List;
        final allList = rawList
            .map((e) => DataTellerModel.fromJson(Map<String, dynamic>.from(e)))
            .where((t) => t.status?.toLowerCase() != 'hapus')
            .toList();

        // PATCH: status buka/tutup diambil dari database lokal (sama persis
        // sumber yang dipakai menu Buka/Tutup Transaksi, sudah terbukti
        // akurat) — bukan dari field 'transaksi_teller' hasil middleware
        // yang kadang gak sinkron sama tombol buka/tutup yang sebenarnya.
        await _overrideBukaTutupFromLocalDb(allList);

        _list = UserLevelHelper.applyKantorFilter(
          list: allList,
          users: _sessionUser,
          getKdKantor: (t) => t.kdKantor,
        );
      } else {
        _list = [];
      }
    } catch (e) {
      if (kDebugMode) print('ERROR LAPORAN TELLER: $e');
      _list = [];
    }
    _applyFilter();
    notifyListeners();
  }

  Future<void> _overrideBukaTutupFromLocalDb(List<DataTellerModel> list) async {
    try {
      final dbResult = await TellerRepository.inquiryTellerDb(bprId: _bprId, limit: 1000);
      if (dbResult['value'] != 1) {
        if (kDebugMode) print('BUKA_TUTUP: gagal ambil inquiry-db: ${dbResult['message']}');
        return;
      }
      final List<dynamic> dbRows = dbResult['data'] ?? [];
      final Map<String, String> stsByUserId = {
        for (final row in dbRows)
          if ((row['userid'] ?? '').toString().trim().isNotEmpty)
            row['userid'].toString().trim().toUpperCase():
                (row['stsaktif'] ?? 'C').toString().toUpperCase(),
      };
      for (final teller in list) {
        final key = (teller.userId ?? '').trim().toUpperCase();
        if (key.isEmpty) continue;
        if (stsByUserId.containsKey(key)) {
          final sts = stsByUserId[key]!;
          teller.stsBukaTutup = sts;
          teller.isTransaksiDibuka = sts == 'A';
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
      _filteredList = _list.where((t) {
        return (t.namaTeller ?? '').toLowerCase().contains(kw) ||
            (t.userId ?? '').toLowerCase().contains(kw) ||
            (t.noSbb ?? '').toLowerCase().contains(kw);
      }).toList();
    }
    const order = {'A': 0, 'C': 1, 'B': 2};
    _filteredList.sort((a, b) {
      final sa = order[a.stsBukaTutup] ?? 9;
      final sb = order[b.stsBukaTutup] ?? 9;
      if (sa != sb) return sa.compareTo(sb);
      return (a.namaTeller ?? '').toLowerCase().compareTo((b.namaTeller ?? '').toLowerCase());
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
class LaporanDataTellerPage extends StatelessWidget {
  const LaporanDataTellerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _LaporanDataTellerNotifier(context: context),
      child: Consumer<_LaporanDataTellerNotifier>(
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
        'Laporan Data Teller',
        style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTable(_LaporanDataTellerNotifier notifier) {
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
                    hintText: 'Cari Nama atau User ID',
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

  List<AppGridColumn> _buildColumns(_LaporanDataTellerNotifier notifier) => [
        const AppGridColumn('no', 'No', width: 60, align: Alignment.center),
        const AppGridColumn('namaTeller', 'Nama Teller', width: 320),
        const AppGridColumn('userId', 'User ID', width: 240),
        const AppGridColumn('noSbb', 'No SBB', width: 240),
        const AppGridColumn('kantor', 'Kantor', width: 200),
        AppGridColumn('statusBukaTutup', 'Status',
            width: 180,
            align: Alignment.center,
            cellBuilder: (value) => _statusBadge(value, _statusBukaTutupColor(value.toString()))),
      ];

  List<Map<String, dynamic>> _buildRows(_LaporanDataTellerNotifier notifier) {
    int no = 0;
    return notifier.filteredList.map((t) {
      return {
        'no': ++no,
        'namaTeller': t.namaTeller ?? '-',
        'userId': t.userId ?? '-',
        'noSbb': t.noSbb ?? '-',
        'kantor': notifier.getNamaKantor(t.kdKantor),
        'statusBukaTutup': _labelBukaTutup(t.stsBukaTutup),
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

  String _formatDate(dynamic v) {
    final raw = (v ?? '').toString().trim();
    if (raw.isEmpty) return '-';
    try {
      final dateOnly = raw.split(' ')[0].split('T')[0];
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateOnly));
    } catch (_) {
      return raw;
    }
  }
}
