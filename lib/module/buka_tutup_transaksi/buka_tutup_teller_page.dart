import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../utils/colors.dart';
import 'buka_tutup_teller_notifier.dart';

// ==================== DATAGRID SOURCE ====================
class _BukaTutupDataSource extends DataGridSource {
  _BukaTutupDataSource({
    required this.listTeller,
    required this.onToggle,
  }) {
    _buildRows();
  }

  final List<BukaTutupTellerModel> listTeller;
  final void Function(String id, bool value) onToggle;
  List<DataGridRow> _rows = [];

  void _buildRows() {
    // Sort berdasarkan nama terlebih dahulu
    final sortedList = List<BukaTutupTellerModel>.from(listTeller)
      ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    
    _rows = sortedList.asMap().entries.map((entry) {
      final i = entry.key;
      final t = entry.value;
      return DataGridRow(cells: [
        DataGridCell(columnName: 'no', value: i + 1),
        DataGridCell(columnName: 'nama', value: t.nama),
        DataGridCell(columnName: 'userId', value: t.userId),
        DataGridCell(columnName: 'kantor', value: t.namaKantor),
        DataGridCell(columnName: 'status', value: t.transaksiDibuka),
        DataGridCell(columnName: 'toggle', value: t.id),
      ]);
    }).toList();
  }

  void refresh() {
    _buildRows();
    notifyDataSourceListeners();
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final cells = row.getCells();
    final no = cells[0].value as int;
    final nama = cells[1].value as String;
    final userId = cells[2].value as String;
    final namaKantor = cells[3].value as String;
    final isDibuka = cells[4].value as bool;
    final id = cells[5].value as String;

    final parts = nama.trim().split(' ');
    final inisial = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : nama.substring(0, nama.length >= 2 ? 2 : 1).toUpperCase();

    final avatarBg = isDibuka
        ? const Color(0xFFEAF3DE)
        : const Color(0xFFFCEBEB);
    final avatarFg = isDibuka
        ? const Color(0xFF3B6D11)
        : const Color(0xFFA32D2D);

    return DataGridRowAdapter(cells: [
      // No
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text('$no', style: const TextStyle(fontSize: 13, color: Color(0xFF888780))),
      ),
      // Nama + Avatar
      Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: avatarBg,
              child: Text(inisial, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: avatarFg)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(nama, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      // User ID
      Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          userId.isNotEmpty ? userId : '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
        ),
      ),
      // Kantor
      Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(namaKantor, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
      ),
      // Status
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDibuka ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isDibuka ? 'Dibuka' : 'Ditutup',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDibuka ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D),
            ),
          ),
        ),
      ),
      // Switch
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Switch(
          value: isDibuka,
          onChanged: (val) => onToggle(id, val),
          activeThumbColor: colorPrimary,
          activeTrackColor: colorPrimaryLight,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFE0E0E0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ]);
  }
}

// ==================== HALAMAN UTAMA ====================
class BukaTutupTellerPage extends StatefulWidget {
  const BukaTutupTellerPage({super.key});

  @override
  State<BukaTutupTellerPage> createState() => _BukaTutupTellerPageState();
}

class _BukaTutupTellerPageState extends State<BukaTutupTellerPage> {
  _BukaTutupDataSource? _dataSource;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BukaTutupTellerNotifier(context: context),
      child: Consumer<BukaTutupTellerNotifier>(
        builder: (context, notifier, child) {
          if (notifier.errorMessage != null) {
            return Scaffold(
              backgroundColor: colorSurfaceTint,
              appBar: _buildAppBar(),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(notifier.errorMessage!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => notifier.refreshData(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (notifier.isLoading) {
            return Scaffold(
              backgroundColor: colorSurfaceTint,
              appBar: _buildAppBar(),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          _dataSource = _BukaTutupDataSource(
            listTeller: notifier.listTeller,
            onToggle: (id, value) => notifier.toggleTeller(id, value),
          );

          return Scaffold(
            backgroundColor: colorSurfaceTint,
            appBar: _buildAppBar(),
            body: Column(
              children: [
                _buildToolbar(notifier),
                _buildBadge(notifier),
                Expanded(child: _buildTable()),
                _buildBottomBar(notifier),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Buka Tutup Transaksi — Teller'),
      backgroundColor: colorPrimary,
      foregroundColor: colortextwhite,
      elevation: 0,
    );
  }

  Widget _buildToolbar(BukaTutupTellerNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE3E8E5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: notifier.isSaving ? null : notifier.bukaSemua,
              icon: const Icon(Icons.lock_open_rounded, size: 16),
              label: const Text('Buka semua'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade600,
                backgroundColor: colortextwhite,
                side: const BorderSide(color: Colors.green, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: notifier.isSaving ? null : notifier.tutupSemua,
              icon: const Icon(Icons.lock_rounded, size: 16),
              label: const Text('Tutup semua'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                backgroundColor: colortextwhite,
                side: const BorderSide(color: Colors.red, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BukaTutupTellerNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: colorPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            ' Total Teller: ${notifier.listTeller.length}',
            style: const TextStyle(
              color: colorPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (_dataSource == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDCE3DF)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SfDataGrid(
            source: _dataSource!,
            selectionMode: SelectionMode.none,
            headerRowHeight: 44,
            rowHeight: 58,
            columnWidthMode: ColumnWidthMode.fill,
            gridLinesVisibility: GridLinesVisibility.horizontal,
            headerGridLinesVisibility: GridLinesVisibility.horizontal,
            columns: [
              GridColumn(
                columnName: 'no',
                columnWidthMode: ColumnWidthMode.none,
                width: 48,
                label: _headerCell('No', Alignment.center),
              ),
              GridColumn(
                columnName: 'nama',
                minimumWidth: 180,
                label: _headerCell('Nama teller', Alignment.centerLeft),
              ),
              GridColumn(
                columnName: 'userId',
                columnWidthMode: ColumnWidthMode.none,
                width: 320,
                label: _headerCell('User ID', Alignment.centerLeft),
              ),
              GridColumn(
                columnName: 'kantor',
                minimumWidth: 150,
                label: _headerCell('Kantor', Alignment.centerLeft),
              ),
              GridColumn(
                columnName: 'status',
                columnWidthMode: ColumnWidthMode.none,
                width: 100,
                label: _headerCell('Status', Alignment.center),
              ),
              GridColumn(
                columnName: 'toggle',
                columnWidthMode: ColumnWidthMode.none,
                width: 88,
                label: _headerCell('Transaksi', Alignment.center),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(String title, Alignment align) {
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: colorPrimaryLight,
        border: Border(right: BorderSide(color: Color(0xFFE3E8E5))),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: colortextwhite,
        ),
      ),
    );
  }

  Widget _buildBottomBar(BukaTutupTellerNotifier notifier) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: notifier.isSaving 
                  ? null 
                  : () => notifier.cancelPerubahan(),
              style: OutlinedButton.styleFrom(
                foregroundColor: colortextwhite,
                backgroundColor: colorcancel,
                side: const BorderSide(color: Color(0xFFDCE3DF)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Batal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: notifier.isSaving ? null : () => notifier.simpanPerubahan(),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorPrimary,
                foregroundColor: colortextwhite,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: notifier.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite),
                    )
                  : const Text('Simpan perubahan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}