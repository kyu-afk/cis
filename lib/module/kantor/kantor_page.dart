// PATCH: Kantor disamakan dengan MEDFO — read-only, data dari HRIS.
import 'package:cis_menu/module/kantor/kantor_notifier.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/colors.dart';
import '../../utils/widgets/app_data_grid.dart';

class KantorPage extends StatelessWidget {
  const KantorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => KantorNotifier(context: context),
      child: Consumer<KantorNotifier>(
        builder: (context, notifier, child) => Scaffold(
          key: notifier.key,
          backgroundColor: const Color(0xffF3F5F4),
          body: Column(
            children: [
              _buildHeader(),
              _buildInfoBanner(),
              Expanded(
                child: notifier.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => notifier.getKantor(),
                        child: _buildTable(notifier),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      color: colorPrimary,
      child: const Row(
        children: [
          Text(
            'Kantor',
            style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ==================== INFO BANNER ====================
  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xffFFF8E1),
        border: Border.all(color: const Color(0xffF9A825)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xffF9A825), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data kantor diambil dari HRIS. Untuk menambah/mengubah kantor, silakan akses hr.medtrans.id',
              style: TextStyle(fontSize: 13, color: Color(0xff5F4200)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TABEL ====================
  Widget _buildTable(KantorNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: _badge('Total: ${notifier.listResult.length}', Colors.black),
        ),
        Expanded(
          child: AppDataGrid(
            columns: _buildColumns(),
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  List<AppGridColumn> _buildColumns() => [
        const AppGridColumn('no', 'No', width: 60, align: Alignment.center),
        const AppGridColumn('kd_bank', 'Kode Bank', width: 320, align: Alignment.center),
        const AppGridColumn('kd_kantor', 'Kode Kantor', width: 320, align: Alignment.center),
        const AppGridColumn('nama_kantor', 'Nama Kantor', width: 550),
      ];

  List<Map<String, dynamic>> _buildRows(KantorNotifier notifier) {
    int no = 0;
    return notifier.listResult.map((k) => {
          'no': ++no,
          'kd_bank': k.bpr_id ?? '-',
          'kd_kantor': k.kdKantor ?? '-',
          'nama_kantor': k.namaKantor ?? '-',
        }).toList();
  }
}
