import 'package:cis_menu/models/index.dart';
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
          endDrawer: Drawer(
            width: 500,
            child: _buildDrawerContent(notifier, context),
          ),
          body: Column(
            children: [
              _buildHeader(notifier),
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
  Widget _buildHeader(KantorNotifier notifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      color: colorPrimary,
      child: Row(
        children: [
          const Text(
            'Kantor',
            style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colortextwhite,
              foregroundColor: colortextblack,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: notifier.openDrawerForTambah,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Kantor', style: TextStyle(fontWeight: FontWeight.w600)),
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  List<AppGridColumn> _buildColumns(KantorNotifier notifier) => [
        const AppGridColumn('no', 'No', width: 60, align: Alignment.center),
        const AppGridColumn('kd_bank', 'Kode Bank', width: 280, align: Alignment.center),
        const AppGridColumn('kd_kantor', 'Kode Kantor', width: 280, align: Alignment.center),
        const AppGridColumn('nama_kantor', 'Nama Kantor', width: 520),
        AppGridColumn(
          'aksi',
          'Aksi',
          width: 100,
          align: Alignment.center,
          isAction: true,
          cellBuilder: (_) => const Icon(Icons.edit_note, size: 30, color: Colors.grey),
          onActionTap: (rowData) {
            final kantor = KantorModel(
              bpr_id: rowData['kd_bank'],
              kdKantor: rowData['kd_kantor'],
              namaKantor: rowData['nama_kantor'],
            );
            notifier.openDrawerForAction(kantor);
          },
        ),
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

  // ==================== DRAWER CONTENT ====================
  Widget _buildDrawerContent(KantorNotifier notifier, BuildContext context) {
    if (notifier.drawerMode == 'aksi') {
      return _buildActionMenu(notifier, context);
    }
    return _buildFormPanel(notifier, context);
  }

  // ── Action Menu ──
  Widget _buildActionMenu(KantorNotifier notifier, BuildContext context) {
    if (notifier.kantorModel == null) {
      return const Center(child: Text('Pilih data kantor terlebih dahulu'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _drawerHeader('Pilih Aksi', notifier.closeDrawer),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAF9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffDCE3DF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notifier.kantorModel!.namaKantor ?? '-',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kode Kantor: ${notifier.kantorModel!.kdKantor ?? '-'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kode Bank: ${notifier.kantorModel!.bpr_id ?? '-'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Pilih aksi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _actionTile(Icons.edit, 'Edit', colorPrimary, notifier.openDrawerForEdit),
              _actionTile(Icons.delete_outline, 'Hapus', Colors.red, () => _confirmHapus(notifier, context)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: OutlinedButton(
            onPressed: notifier.closeDrawer,
            style: OutlinedButton.styleFrom(
              foregroundColor: colortextblack,
              side: const BorderSide(color: Color(0xffDCE3DF)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colortextwhite,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffDCE3DF)),
            ),
            child: Row(children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
              const Spacer(),
              Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Form Panel (tambah / edit) ──
  Widget _buildFormPanel(KantorNotifier notifier, BuildContext context) {
    final isEdit = notifier.drawerMode == 'edit';

    return Form(
      key: notifier.keyForm,
      child: Column(
        children: [
          _drawerHeader(notifier.drawerTitle, notifier.closeDrawer),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Kode Kantor ──
                _fieldLabel('Kode Kantor'),
                TextFormField(
                  controller: notifier.kdKantor,
                  readOnly: isEdit,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration(
                    'Kode Kantor',
                    fillColor: isEdit ? Colors.grey.shade100 : Colors.white,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Kode Kantor wajib diisi' : null,
                ),
                const SizedBox(height: 16),

                // ── Nama Kantor ──
                _fieldLabel('Nama Kantor'),
                TextFormField(
                  controller: notifier.namakantor,
                  decoration: _inputDecoration('Nama Kantor'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Nama Kantor wajib diisi' : null,
                ),
              ],
            ),
          ),

          // ── Bottom buttons ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2))
              ],
            ),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: notifier.isSaving
                      ? null
                      : () {
                          if (notifier.drawerMode == 'tambah') {
                            notifier.closeDrawer();
                          } else {
                            notifier.goBackToActionMenu();
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colortextwhite,
                    backgroundColor: colorcancel,
                    side: const BorderSide(color: Color(0xffDCE3DF)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    notifier.drawerMode == 'tambah' ? 'Batal' : 'Kembali',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: notifier.isSaving ? null : notifier.simpan,
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite))
                      : const Text('Simpan',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ==================== CONFIRM HAPUS ====================
  Future<void> _confirmHapus(KantorNotifier notifier, BuildContext context) async {
    final kantor = notifier.kantorModel;
    if (kantor == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: colorPrimary,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                ),
                child: Row(children: [
                  const Icon(Icons.delete_outline, color: colortextwhite, size: 20),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Konfirmasi Hapus',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: colortextwhite)),
                    const Text('Kantor',
                        style: TextStyle(fontSize: 12, color: colortextwhite)),
                  ]),
                ]),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Apakah Anda yakin ingin menghapus kantor ini?',
                        style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xffF8FAF9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffDCE3DF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _konfirmasiRow('Kode Bank', kantor.bpr_id?.toString() ?? '-'),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Kode Kantor', kantor.kdKantor?.toString() ?? '-'),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Nama Kantor', kantor.namaKantor?.toString() ?? '-'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorcancel,
                            foregroundColor: colortextwhite,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorPrimary,
                            foregroundColor: colortextwhite,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Hapus',
                              style: TextStyle(fontWeight: FontWeight.w600)),
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

    if (confirmed == true) {
      await notifier.hapus();
    }
  }

  // ==================== HELPERS ====================
  Widget _drawerHeader(String title, VoidCallback onClose) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: colorPrimary,
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: colortextwhite, fontSize: 16, fontWeight: FontWeight.w700))),
        IconButton(
            icon: const Icon(Icons.close, color: colortextwhite), onPressed: onClose),
      ]),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
    );
  }

  InputDecoration _inputDecoration(String hint, {Color? fillColor}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
      filled: true,
      fillColor: fillColor ?? Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: colorPrimary, width: 1.5),
      ),
    );
  }

  Widget _konfirmasiRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey))),
        const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }
}