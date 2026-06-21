import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../utils/widgets/app_data_grid.dart';
import 'pengisian_modal_notifier.dart';

class PengisianModalPage extends StatefulWidget {
  const PengisianModalPage({super.key});

  @override
  State<PengisianModalPage> createState() => _PengisianModalPageState();
}

class _PengisianModalPageState extends State<PengisianModalPage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        final notifier = context.read<PengisianModalNotifier>();
        notifier.toggleDropdown(false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PengisianModalNotifier(context: context),
      child: Consumer<PengisianModalNotifier>(
        builder: (context, notifier, child) {
          if (notifier.errorMessage != null) {
            return Scaffold(
              backgroundColor: const Color(0xffF3F5F4),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorPrimary,
                        foregroundColor: colortextwhite,
                      ),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (notifier.isLoading) {
            return const Scaffold(
              backgroundColor: Color(0xffF3F5F4),
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            key: scaffoldKey,
            backgroundColor: const Color(0xffF3F5F4),
            endDrawer: Drawer(
              width: 550,
              child: notifier.selectedRiwayat != null
                  ? _buildActionDrawer(notifier)
                  : _buildFormDrawer(notifier),
            ),
            body: RefreshIndicator(
              onRefresh: () => notifier.refreshData(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(notifier),
                  _buildSummary(notifier),
                  Expanded(
                    child: AppDataGrid(
                      columns: _buildGridColumns(notifier),
                      rows: _buildGridRows(notifier),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // PERBAIKAN 2: Action Drawer untuk Print Ulang dan Delete
  Widget _buildActionDrawer(PengisianModalNotifier notifier) {
    final selected = notifier.selectedRiwayat;
    if (selected == null) {
      return const Center(child: Text('Pilih data terlebih dahulu'));
    }

    // State: null = menu aksi, 'print'/'delete' = detail read only + konfirmasi
    final mode = notifier.actionMode;

    // Judul & warna berdasarkan mode
    final String title = mode == null
        ? 'Pilih Aksi'
        : mode == 'print' ? 'Print Ulang' : 'Hapus Data';
    final Color accentColor = mode == 'delete' ? colorPrimary : colorPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: colorPrimary,
          child: Row(
            children: [
              if (mode != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: colortextwhite),
                  onPressed: () => notifier.pilihAksi(null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (mode != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: colortextwhite, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: colortextwhite),
                onPressed: () => notifier.closeActionDrawer(scaffoldKey),
              ),
            ],
          ),
        ),

        // Isi
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Info card (selalu tampil)
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
                    Text(selected['namaPetugas'] ?? '-',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _infoRowDetail('No HP', selected['noHp'] ?? '-'),
                    _infoRowDetail('Nominal', selected['nominal'] ?? '-'),
                    _infoRowDetail('Waktu', selected['waktu'] ?? '-'),
                    _infoRowDetail('Status', selected['status'] ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Mode: menu aksi
              if (mode == null) ...[
                const Text('Pilih aksi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _actionTile(Icons.print, 'Print Ulang', colorPrimary, () => notifier.pilihAksi('print')),
                _actionTile(Icons.delete_outline, 'Hapus', Colors.red, () => notifier.pilihAksi('delete')),
              ],

              // Mode: detail konfirmasi
              if (mode != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        mode == 'print' ? Icons.info_outline : Icons.warning_amber_rounded,
                        color: accentColor, size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mode == 'print'
                              ? 'Yakin ingin mencetak ulang struk untuk data ini?'
                              : 'Yakin ingin menghapus data pengisian modal ini? Tindakan tidak dapat dibatalkan.',
                          style: TextStyle(fontSize: 13, color: accentColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Bottom buttons
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: mode == null
              // Menu aksi: hanya tombol Tutup
              ? OutlinedButton(
                  onPressed: () => notifier.closeActionDrawer(scaffoldKey),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colortextblack,
                    side: const BorderSide(color: Color(0xffDCE3DF)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
                )
              // Detail: Kembali + Proses/Cetak
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: notifier.isSaving ? null : () => notifier.pilihAksi(null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colortextwhite,
                          backgroundColor: colorcancel,
                          side: const BorderSide(color: Colors.transparent),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Kembali', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: notifier.isSaving ? null : () => notifier.executeAction(scaffoldKey),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: colortextwhite,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: notifier.isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite))
                            : Text(
                                mode == 'print' ? 'Cetak' : 'Hapus',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _infoRowDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
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
              Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
              const Spacer(),
              Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(PengisianModalNotifier notifier) {
    final totalNominal = notifier.totalNominalHariIni;
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final totalTransaksi = notifier.listRiwayat.length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'total data: $totalTransaksi',
              style: const TextStyle(
                color: colorPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'total nominal: ${formatter.format(totalNominal)}',
              style: const TextStyle(
                color: colorPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // PERBAIKAN 1: Perbaiki kolom aksi agar bisa diklik
  List<AppGridColumn> _buildGridColumns(PengisianModalNotifier notifier) => [
    const AppGridColumn('no', 'No', width: 60, align: Alignment.centerLeft),
    const AppGridColumn('namaPetugas', 'Nama Petugas', width: 250, align: Alignment.centerLeft),
    const AppGridColumn('noHp', 'No HP', width: 200, align: Alignment.centerLeft),
    const AppGridColumn('nominal', 'Nominal', width: 200, align: Alignment.centerRight, headerAlign: Alignment.centerLeft),
    const AppGridColumn('waktu', 'Waktu', width: 190, align: Alignment.centerLeft),
    const AppGridColumn('status', 'Status', width: 190, align: Alignment.centerLeft),
    AppGridColumn(
      'aksi',
      'Aksi',
      width: 140,
      align: Alignment.center,
      isAction: true,
      cellBuilder: (_) => const Icon(Icons.edit_note, size: 30, color: Colors.grey),
      onActionTap: (rowData) => notifier.openActionDrawer(rowData, scaffoldKey),
    ),
  ];

  List<Map<String, dynamic>> _buildGridRows(PengisianModalNotifier notifier) {
    final sortedList = List<Map<String, dynamic>>.from(notifier.listRiwayat)
      ..sort((a, b) => (a['namaPetugas'] ?? '').toLowerCase().compareTo((b['namaPetugas'] ?? '').toLowerCase()));
    
    int no = 0;
    return sortedList.map((item) {
      return {
        'no': ++no,
        'id': item['id']?.toString() ?? '',
        'namaPetugas': item['namaPetugas'] ?? '-',
        'noHp': item['noHp'] ?? '-',
        'nominal': item['nominal'] ?? '-',
        'waktu': item['waktu'] ?? '-',
        'status': item['status'] ?? '-',
        'noreff': item['noreff'] ?? '-',
      };
    }).toList();
  }

  Widget _buildHeader(PengisianModalNotifier notifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      color: colorPrimary,
      child: Row(
        children: [
          const Text(
            "Pengisian Modal",
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
            onPressed: () {
              notifier.resetForm();
              scaffoldKey.currentState?.openEndDrawer();
            },
            icon: const Icon(Icons.add),
            label: const Text("Pengisian Modal", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormDrawer(PengisianModalNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: colorPrimary,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Form Pengisian Modal',
                  style: TextStyle(color: colortextwhite, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: colortextwhite),
                onPressed: () {
                  notifier.resetForm();
                  scaffoldKey.currentState?.closeEndDrawer();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Form(
            key: notifier.formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Nama Petugas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                _buildSearchableDropdown(notifier),
                const SizedBox(height: 16),
                const Text('No HP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: notifier.noHpCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'No HP akan muncul setelah pilih petugas',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                    filled: true,
                    fillColor: const Color(0xffF8FAF9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Nominal Modal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: notifier.nominalCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Masukkan nominal (kelipatan 100)',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                    prefixText: 'Rp ',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (value) => notifier.onNominalChanged(value),
                  validator: (_) => notifier.validateNominal(notifier.nominalCtrl.text),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    notifier.resetForm();
                    scaffoldKey.currentState?.closeEndDrawer();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colortextwhite,
                    backgroundColor: colorcancel,
                    side: const BorderSide(color: Colors.transparent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: notifier.isSaving ? null : notifier.simpan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorPrimary,
                    foregroundColor: colortextwhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: notifier.isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite))
                      : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdown(PengisianModalNotifier notifier) {
    final suggestions = notifier.getSuggestions(notifier.namaPetugasCtrl.text);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: notifier.namaPetugasCtrl,
          focusNode: _focusNode,
          onTap: () {
            if (notifier.namaPetugasCtrl.text.isNotEmpty && suggestions.isNotEmpty) {
              notifier.toggleDropdown(true);
            }
          },
          onChanged: (value) {
            notifier.selectedPetugasId = null;
            notifier.selectedPetugasNoHp = null;
            notifier.noHpCtrl.clear();
            
            if (value.isNotEmpty) {
              notifier.toggleDropdown(true);
            } else {
              notifier.toggleDropdown(false);
            }
          },
          decoration: InputDecoration(
            hintText: 'Ketik nama petugas...',
            hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: suggestions.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      notifier.namaPetugasCtrl.clear();
                      notifier.selectedPetugasId = null;
                      notifier.selectedPetugasNoHp = null;
                      notifier.noHpCtrl.clear();
                      notifier.toggleDropdown(false);
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: (_) => notifier.validateNamaPetugas(notifier.namaPetugasCtrl.text),
        ),
        if (notifier.showDropdown && suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return InkWell(
                  onTap: () {
                    notifier.namaPetugasCtrl.text = suggestion;
                    notifier.onPetugasSelected(suggestion);
                    notifier.toggleDropdown(false);
                    FocusScope.of(context).unfocus();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}