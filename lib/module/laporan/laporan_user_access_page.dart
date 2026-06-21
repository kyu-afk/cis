import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../network/network.dart';
import '../../pref/pref.dart';
import '../../repository/users_access_repository.dart';
import '../../utils/colors.dart';
import '../../utils/user_level.dart';
import '../../utils/widgets/app_data_grid.dart';
import '../users_access/users_access_stsrec.dart';

// ==================== NOTIFIER ====================
class _LaporanUserAccessNotifier extends ChangeNotifier {
  final BuildContext context;

  _LaporanUserAccessNotifier({required this.context}) {
    _init();
  }

  List<UsersAccessModel> _list = [];
  List<UsersAccessModel> get list => _list;

  List<UsersAccessModel> _filteredList = [];
  List<UsersAccessModel> get filteredList => _filteredList;

  final Map<String, String> _kantorMap = {};

  bool isLoading = true;
  String _searchKeyword = '';
  Timer? _debounceTimer;
  UsersModel? _sessionUser;

  final searchCtrl = TextEditingController();

  int get jumlahAktif => _list.where((u) => UsersAccessStsrec.isAktif(u)).length;
  int get jumlahTidakAktif => _list.length - jumlahAktif;

  String getNamaKantor(String? kdKantor) {
    if (kdKantor == null || kdKantor.isEmpty) return '-';
    return _kantorMap[kdKantor] ?? kdKantor;
  }

  Future<void> _init() async {
    _sessionUser = await Pref().getUsers();
    await loadAll();
  }

  Future<void> loadAll() async {
    if (_sessionUser == null) return;
    isLoading = true;
    notifyListeners();
    await Future.wait([_loadUsers(), _loadKantor()]);
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadUsers() async {
    final u = _sessionUser!;
    try {
      final result = await UsersAccessRepository.inquiryUsers(
        url: NetworkURL.inquiryUsers(),
        bprId: u.bprId,
        filterUserid: '',
        filterNamauser: '',
        page: 1,
        limit: 500,
      );
      if (result['value'] == 1) {
        final data = result['data'] as List<dynamic>? ?? [];
        final allUsers = data.map((e) => UsersAccessModel.fromJson(e)).toList();
        final visible = allUsers.where((u) => (u.kdkantor ?? '') != '000').toList();
        final canSeeAll = UserLevelHelper.canSeeAllKantor(_sessionUser);
        _list = canSeeAll
            ? visible
            : visible
                .where((u) =>
                    u.kdkantor == _sessionUser!.kodeKantor ||
                    u.userid?.toUpperCase() == _sessionUser!.usersId.toUpperCase())
                .toList();
      } else {
        _list = [];
      }
    } catch (_) {
      _list = [];
    }
    _applyFilter();
    notifyListeners();
  }

  Future<void> _loadKantor() async {
    final u = _sessionUser!;
    try {
      final result = await UsersAccessRepository.getListKantor(
        url: NetworkURL.getListKantorAccess(),
        userId: u.usersId,
        bprId: u.bprId,
      );
      if (result['value'] == 1) {
        final List<dynamic> data = result['kantor'] ?? [];
        for (final k in data) {
          final m = k as Map<String, dynamic>;
          final kd = (m['kd_kantor'] ?? m['kdkantor'] ?? '').toString();
          final nm = (m['nama_kantor'] ?? m['namakantor'] ?? '').toString();
          if (kd.isNotEmpty) _kantorMap[kd] = nm;
        }
      }
    } catch (_) {}
  }

  void _applyFilter() {
    final kw = _searchKeyword.trim().toLowerCase();
    if (kw.isEmpty) {
      _filteredList = List.from(_list);
    } else {
      _filteredList = _list.where((u) {
        return (u.userid ?? '').toLowerCase().contains(kw) ||
            (u.namauser ?? '').toLowerCase().contains(kw);
      }).toList();
    }
    const order = {'A': 0, 'B': 1, 'C': 2};
    _filteredList.sort((a, b) {
      final sa = order[UsersAccessStsrec.code(a)] ?? 9;
      final sb = order[UsersAccessStsrec.code(b)] ?? 9;
      if (sa != sb) return sa.compareTo(sb);
      return (a.namauser ?? '').toLowerCase().compareTo((b.namauser ?? '').toLowerCase());
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
class LaporanUserAccessPage extends StatelessWidget {
  const LaporanUserAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _LaporanUserAccessNotifier(context: context),
      child: Consumer<_LaporanUserAccessNotifier>(
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
        'Laporan User Access',
        style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTable(_LaporanUserAccessNotifier notifier) {
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
                  _badge('Aktif: ${notifier.jumlahAktif}', Colors.green),
                  _badge('Tidak Aktif: ${notifier.jumlahTidakAktif}', Colors.red),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 250,
                child: TextField(
                  controller: notifier.searchCtrl,
                  onChanged: notifier.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari User ID atau Nama',
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

  List<AppGridColumn> _buildColumns(_LaporanUserAccessNotifier notifier) => [
        const AppGridColumn('no', 'No', width: 60, align: Alignment.center),
        const AppGridColumn('namauser', 'Nama', width: 280),
        const AppGridColumn('userid', 'User ID', width: 280),
        const AppGridColumn('kantor', 'Kantor', width: 270),
        AppGridColumn('tglexp', 'Tanggal Kadaluarsa',
            width: 200,
            align: Alignment.centerRight,
            format: _formatDate),
        AppGridColumn('stsrec', 'Status',
            width: 150,
            align: Alignment.center,
            cellBuilder: (value) => _statusBadge(value)),
      ];

  List<Map<String, dynamic>> _buildRows(_LaporanUserAccessNotifier notifier) {
    int no = 0;
    return notifier.filteredList.map((u) {
      return {
        'no': ++no,
        'namauser': u.namauser ?? '-',
        'userid': u.userid ?? '-',
        'kantor': notifier.getNamaKantor(u.kdkantor),
        'tglexp': u.tglexp ?? '',
        'stsrec': UsersAccessStsrec.label(UsersAccessStsrec.code(u)),
      };
    }).toList();
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

  Widget _statusBadge(dynamic value) {
    final label = value.toString();
    Color color;
    if (label == 'AKTIF') {
      color = Colors.green;
    } else if (label == 'Blokir') {
      color = Colors.orange;
    } else if (label == 'Tutup') {
      color = Colors.blueGrey;
    } else {
      color = Colors.grey;
    }
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
