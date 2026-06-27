import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../utils/widgets/app_data_grid.dart';
import 'data_petugas_notifier.dart';
import 'data_petugas_stsrec.dart';

class DataPetugasPage extends StatelessWidget {
  const DataPetugasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DataPetugasNotifier(context: context),
      child: Consumer<DataPetugasNotifier>(
        builder: (context, notifier, child) => Scaffold(
          key: notifier.scaffoldKey,
          backgroundColor: const Color(0xffF3F5F4),
          endDrawer: Drawer(
            width: 620,
            child: _buildDrawerContent(notifier, context),
          ),
          body: Column(
            children: [
              _buildHeader(notifier),
              Expanded(
                child: notifier.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => notifier.refreshList(),
                        child: _buildTable(notifier),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(DataPetugasNotifier notifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      color: colorPrimary,
      child: Row(
        children: [
          const Text('Data Petugas',
              style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colortextwhite,
              foregroundColor: colortextblack,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: notifier.tambahPetugas,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Data Petugas', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(DataPetugasNotifier notifier) {
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
                  _badge('Total: ${notifier.filteredList.length}', Colors.black),
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
                    hintText: 'Cari Nama atau NIP',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  List<AppGridColumn> _buildColumns(DataPetugasNotifier notifier) => [
    const AppGridColumn('no', 'No', width: 70, align: Alignment.center),
    const AppGridColumn('nama', 'Nama', width: 260),
    const AppGridColumn('noHp', 'No HP', width: 220),
    const AppGridColumn('nip', 'NIP', width: 220),
    const AppGridColumn('kantor', 'Kantor', width: 220),
    AppGridColumn('status', 'Status', width: 150, align: Alignment.center, cellBuilder: (value) => _statusBadge(value)),
    AppGridColumn(
      'aksi',
      'Aksi',
      width: 100,
      align: Alignment.center,
      isAction: true,
      cellBuilder: (_) => const Icon(Icons.edit_note, size: 30, color: Colors.grey),
      onActionTap: (rowData) {
        final nip = rowData['nip']?.toString();
        final petugas = notifier.filteredList.firstWhere(
          (p) => p.nip == nip,
          orElse: () => DataPetugasModel(),
        );
        if (petugas.id != null) {
          notifier.openDrawerForAction(petugas);
        }
      },
    ),
  ];

  List<Map<String, dynamic>> _buildRows(DataPetugasNotifier notifier) {
    int no = 0;
    return notifier.filteredList.map((p) => {
      'no': ++no,
      'userId': p.userId ?? '-',
      'nama': p.nama ?? '-',
      'noHp': p.noHp ?? '-',
      'nip': p.nip ?? '-',
      'kantor': notifier.getNamaKantor(p.kdKantor),
      'status': DataPetugasStsrec.statusFor(p),
      'status_raw': p.status,
      'id': p.id,
      'kode_petugas': p.kodePetugas,
      'no_sbb': p.noSbb,
      'nama_sbb': p.namaSbb,
      'kd_kantor': p.kdKantor,
      'akses_setor': p.aksesSetor,
      'akses_tartun': p.aksesTarik,
      'akses_transfer': p.aksesTransfer,
      'akses_ppob': p.aksesPpob,
      'akses_kredit': p.aksesKredit,
    }).toList();
  }

  Widget _statusBadge(dynamic value) {
    final label = value.toString();
    final code = label == 'AKTIF' ? 'aktif' : 'blokir';
    final color = DataPetugasStsrec.badgeColor(code);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  // ==================== DRAWER ====================
  Widget _buildDrawerContent(DataPetugasNotifier notifier, BuildContext context) {
    if (notifier.drawerMode == 'aksi') {
      return _buildActionMenu(notifier, context);
    }
    return _buildFormPanel(notifier, context);
  }

  Widget _buildActionMenu(DataPetugasNotifier notifier, BuildContext context) {
    if (notifier.selectedPetugas == null) {
      return const Center(child: Text('Pilih data petugas terlebih dahulu'));
    }

    final isAktif = DataPetugasStsrec.isAktif(notifier.selectedPetugas);
    final isBlokir = DataPetugasStsrec.isTidakAktif(notifier.selectedPetugas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _drawerHeader('Pilih Aksi', notifier.closeDrawer),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
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
                    Text(notifier.selectedPetugas!.userId ?? '-', style: const TextStyle(fontSize: 13)),
                    Text(notifier.selectedPetugas!.nama ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('NIP: ${notifier.selectedPetugas!.nip ?? '-'}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('No HP: ${notifier.selectedPetugas!.noHp ?? '-'}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Kantor: ${notifier.getNamaKantor(notifier.selectedPetugas?.kdKantor)}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Kode Petugas: ${notifier.selectedPetugas!.kodePetugas ?? '-'}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    _statusBadge(DataPetugasStsrec.statusFor(notifier.selectedPetugas)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Pilih aksi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (isAktif) ...[
                _actionTile(Icons.edit, 'Edit', colorPrimary, () => notifier.pilihAksi('edit')),
                _actionTile(Icons.lock_reset, 'Reset Password', Colors.blue, () => notifier.pilihAksi('resetPassword')),
                _actionTile(Icons.block, 'Blokir', Colors.orange, () => notifier.pilihAksi('blokir')),
                _actionTile(Icons.delete, 'Hapus', Colors.red, () => notifier.pilihAksi('hapus')),
              ] 
              else if (isBlokir) ...[
                _actionTile(Icons.lock_open, 'Unblokir', Colors.green, () => notifier.pilihAksi('unblokir')),
                _actionTile(Icons.delete, 'Hapus', Colors.red, () => notifier.pilihAksi('hapus')),
              ] 
              else ...[
                _actionTile(Icons.delete, 'Hapus', Colors.red, () => notifier.pilihAksi('hapus')),
              ],
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
              Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
              const Spacer(),
              Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
            ]),
          ),
        ),
      ),
    );
  }

  // ==================== FORM PANEL ====================
  Widget _buildFormPanel(DataPetugasNotifier notifier, BuildContext context) {
    final isReadOnly = notifier.isReadOnly;
    final isFormMode = notifier.drawerMode == 'tambah' || notifier.drawerMode == 'edit';
    final isTambah = notifier.drawerMode == 'tambah';
    final isEdit = notifier.drawerMode == 'edit';

    return Form(
      key: notifier.formKey,
      autovalidateMode: AutovalidateMode.always,
      child: Column(
        children: [
          _drawerHeader(notifier.drawerTitle, notifier.closeDrawer),
          Expanded(
            child: ListView(
              controller: notifier.scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                if (notifier.selectedPetugas != null && !isTambah) ...[
                  _statusBadge(DataPetugasStsrec.statusFor(notifier.selectedPetugas)),
                  const SizedBox(height: 16),
                ],

                // User ID (khusus tambah)
                if (isTambah) ...[
                  _fieldLabel('User ID'),
                  TextFormField(
                    controller: notifier.userIdCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _inputDecoration('User ID').copyWith(
                      errorText: notifier.manualErrors['userId'],
                    ),
                    validator: null,
                  ),
                  _fieldNote('* User ID tidak boleh menggunakan spasi, wajib mengandung huruf dan angka'),
                  const SizedBox(height: 16),
                ],

                // Nama (wajib untuk tambah dan edit)
                _fieldLabel('Nama'),
                TextFormField(
                  controller: notifier.namaCtrl,
                  readOnly: isReadOnly,
                  decoration: _inputDecoration(
                    'Nama Petugas',
                    fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
                  ).copyWith(
                    errorText: notifier.manualErrors['nama'],
                  ),
                  validator: null,
                ),
                _fieldNote('* Nama tidak boleh mengandung karakter spesial (!@#\$%^&* dll)'),
                const SizedBox(height: 16),

                // Password (khusus tambah)
                if (isTambah) ...[
                  _fieldLabel('Password'),
                  TextFormField(
                    controller: notifier.passwordCtrl,
                    obscureText: notifier.obscure,
                    decoration: _inputDecoration(
                      'Password (min. 6 karakter)',
                      suffix: IconButton(
                        onPressed: notifier.toggleObscure,
                        icon: Icon(notifier.obscure ? Icons.visibility : Icons.visibility_off, size: 20),
                      ),
                    ).copyWith(
                      errorText: notifier.manualErrors['password'],
                    ),
                    validator: null,
                  ),
                  _fieldNote('* Password minimal 6 karakter'),
                  const SizedBox(height: 16),
                ],

                // No HP (wajib untuk tambah dan edit)
                _fieldLabel('No HP'),
                TextFormField(
                  controller: notifier.noHpCtrl,
                  readOnly: isReadOnly,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(14),
                  ],
                  decoration: _inputDecoration(
                    'Contoh: 08xxxxxxxxxx',
                    fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
                  ).copyWith(
                    errorText: notifier.manualErrors['noHp'],
                  ),
                  validator: null,
                ),
                _fieldNote('* No HP wajib diawali 08, hanya boleh angka, min 10 dan maks 14 digit'),
                const SizedBox(height: 16),

                // NIP (tambah dan edit)
                if (isFormMode) ...[
                  _fieldLabel('NIP'),
                  TextFormField(
                    controller: notifier.nipCtrl,
                    readOnly: isReadOnly,
                    decoration: _inputDecoration(
                      'NIP',
                      fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
                    ).copyWith(
                      errorText: notifier.manualErrors['nip'],
                    ),
                    validator: null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Kode Petugas (tambah dan edit)
                if (isFormMode) ...[
                  _fieldLabel('Kode Petugas'),
                  TextFormField(
                    controller: notifier.kodePetugasCtrl,
                    readOnly: isReadOnly,
                    decoration: _inputDecoration(
                      'Kode Petugas',
                      fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
                    ).copyWith(
                      errorText: notifier.manualErrors['kodePetugas'],
                    ),
                    validator: null,
                  ),
                  _fieldNote('* Kode petugas tidak boleh mengandung spasi'),
                  const SizedBox(height: 16),
                ],

                // No SBB (wajib untuk tambah dan edit)
                _fieldLabel('No SBB'),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: notifier.noSbbCtrl,
                      readOnly: isReadOnly,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration(
                        'No SBB (hanya angka)',
                        fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
                      ).copyWith(
                        errorText: notifier.manualErrors['noSbb'],
                      ),
                      validator: null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: isReadOnly ? null : notifier.verifikasiNoSbb,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorPrimary,
                        foregroundColor: colortextwhite,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: notifier.isLoadingVerifikasi
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite))
                          : const Text('Cari', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
                if (notifier.manualErrors['noSbb'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(
                      notifier.manualErrors['noSbb']!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 8),

                // Nama SBB (wajib untuk semua mode form)
                _fieldLabel('Nama SBB'),
                TextFormField(
                  controller: notifier.namaSbbCtrl,
                  readOnly: true,
                  decoration: _inputDecoration(
                    'Nama SBB (otomatis dari pencarian)',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ).copyWith(
                    errorText: notifier.manualErrors['namaSbb'],
                  ),
                  validator: null,
                ),
                const SizedBox(height: 16),

                // Kantor (tambah dan edit)
                if (isFormMode) ...[
                  _fieldLabel('Kantor'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<KantorDummy>(
                        value: notifier.selectedKantor,
                        isExpanded: true,
                        hint: const Text('Pilih Kantor', style: TextStyle(fontSize: 13)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                        items: notifier.listKantor.map((k) => DropdownMenuItem(
                          value: k,
                          child: Text('${k.kdKantor} — ${k.namaKantor}', style: const TextStyle(fontSize: 13)),
                        )).toList(),
                        onChanged: isReadOnly ? null : notifier.setSelectedKantor,
                        validator: null,
                      ),
                      if (notifier.manualErrors['kantor'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 12),
                          child: Text(
                            notifier.manualErrors['kantor']!,
                            style: const TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Akses / Limit Transaksi (hanya tambah & edit)
                if (isFormMode) ...[
                  _sectionHeader('Akses / Limit Transaksi'),
                  const SizedBox(height: 12),
                  if (notifier.manualErrors['akses'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        notifier.manualErrors['akses']!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  if (notifier.isLoadingTcodeAkses)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (notifier.tcodeAksesList.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xfff5f5f5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xffDCE3DF)),
                      ),
                      child: const Text(
                        'Belum ada tcode dengan status aktif (Y) di Transaksi Collector.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  else
                    ...notifier.tcodeAksesList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final tcode = item['tcode'] as String;
                      final checked = item['checked'] as bool;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _LimitSection(
                          label: '${item['keterangan']} ($tcode)',
                          minCtrl: item['minCtrl'] as TextEditingController,
                          maxCtrl: item['maxCtrl'] as TextEditingController,
                          pendingCtrl: item['pendingCtrl'] as TextEditingController,
                          readOnly: isReadOnly,
                          enabled: checked,
                          aksesValue: checked,
                          onAksesChanged: (v) => notifier.toggleTcodeAkses(idx, v),
                          manualErrors: notifier.manualErrors,
                          errorPrefix: 'tcode_$tcode',
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (isTambah) {
                        notifier.closeDrawer();
                      } else {
                        notifier.goBackToActionMenu();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colortextwhite,
                      backgroundColor: colorcancel,
                      side: const BorderSide(color: Color(0xffDCE3DF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      isTambah ? 'Batal' : 'Kembali',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: notifier.tombolColor,
                      foregroundColor: colortextwhite,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: notifier.isSaving ? null : () => _executeAction(notifier, context),
                    child: notifier.isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite))
                        : Text(notifier.tombolUtama, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EXECUTE ACTION ====================
  Future<void> _executeAction(DataPetugasNotifier notifier, BuildContext context) async {
    final mode = notifier.drawerMode;

    // Reset Password - butuh konfirmasi
    if (mode == 'resetPassword') {
      final confirmed = await _showResetPasswordConfirmDialog(notifier, context);
      if (!confirmed) return;
      await notifier.executeAction();
      return;
    }

    // Tambah dan Edit - validasi manual dulu
    if (mode == 'tambah' || mode == 'edit') {
      if (!await _validateBeforeSave(notifier, context)) {
        return;
      }
      await notifier.executeAction();
      return;
    }

    // Hapus, Blokir, Unblokir - butuh alasan
    final petugas = notifier.selectedPetugas;
    if (petugas == null) return;

    final Map<String, dynamic> config = {
      'hapus': {'title': 'Konfirmasi Hapus', 'verb': 'menghapus', 'color': colorPrimary, 'icon': Icons.delete_outline},
      'blokir': {'title': 'Konfirmasi Blokir', 'verb': 'memblokir', 'color': colorPrimary, 'icon': Icons.block},
      'unblokir': {'title': 'Konfirmasi Unblokir', 'verb': 'membuka blokir', 'color': colorPrimary, 'icon': Icons.lock_open},
    };

    final cfg = config[mode];
    if (cfg == null) {
      await notifier.executeAction();
      return;
    }

    final confirmed = await _showConfirmDialog(
      context: context,
      title: cfg['title'],
      verb: cfg['verb'],
      color: cfg['color'],
      icon: cfg['icon'],
      nama: petugas.nama ?? '-',
      userId: petugas.userId ?? '-',
      kantor: notifier.getNamaKantor(petugas.kdKantor),
      status: DataPetugasStsrec.statusFor(petugas),
    );

    if (!confirmed) return;
    await notifier.executeAction();
  }

  Future<bool> _validateBeforeSave(DataPetugasNotifier notifier, BuildContext context) async {
  final isValid = notifier.validateAllFieldsManually();
  
  if (!isValid) {
    await notifier.scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    
    // Ubah dari SnackBar menjadi Dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Validasi Gagal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lengkapi semua field yang wajib diisi dengan benar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
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
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return false;
  }
  
  return true;
}

  Future<bool> _showResetPasswordConfirmDialog(DataPetugasNotifier notifier, BuildContext context) async {
    final petugas = notifier.selectedPetugas;
    if (petugas == null) return false;

    final result = await showDialog<bool>(
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: colorPrimary,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                ),
                child: Row(children: [
                  const Icon(Icons.lock_reset, color: colortextwhite, size: 20),
                  const SizedBox(width: 10),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Reset Password',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colortextwhite)),
                    Text('Data Petugas', style: TextStyle(fontSize: 12, color: colortextwhite)),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Apakah Anda yakin ingin mereset password petugas ini?',
                        style: TextStyle(fontSize: 14)),
                    const Text('Password akan direset menjadi default: 123456',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                          _konfirmasiRow('Nama', petugas.nama ?? '-'),
                          const SizedBox(height: 6),
                          _konfirmasiRow('User ID', petugas.userId ?? '-'),
                          const SizedBox(height: 6),
                          _konfirmasiRow('NIP', petugas.nip ?? '-'),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Status', DataPetugasStsrec.statusFor(petugas)),
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
                          child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
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
                          child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w600)),
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
    return result ?? false;
  }

  // ==================== CONFIRM DIALOG ====================
  Future<bool> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String verb,
    required Color color,
    required IconData icon,
    required String nama,
    required String userId,
    required String kantor,
    required String status,
  }) async {
    final result = await showDialog<bool>(
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colorPrimary,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                ),
                child: Row(children: [
                  Icon(icon, color: colortextwhite, size: 20),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colortextwhite)),
                    const Text('Data Petugas', style: TextStyle(fontSize: 12, color: colortextwhite)),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Apakah Anda yakin ingin $verb data ini?', style: const TextStyle(fontSize: 14)),
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
                          _konfirmasiRow('Nama', nama),
                          const SizedBox(height: 6),
                          _konfirmasiRow('User ID', userId),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Kantor', kantor),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Status', status),
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
                          child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: colortextwhite,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Proses', style: TextStyle(fontWeight: FontWeight.w600)),
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
    return result ?? false;
  }

  Widget _konfirmasiRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }

  // ==================== SHARED WIDGETS ====================
  Widget _drawerHeader(String title, VoidCallback onClose) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: colorPrimary,
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(color: colortextwhite, fontSize: 16, fontWeight: FontWeight.w700))),
        IconButton(icon: const Icon(Icons.close, color: colortextwhite), onPressed: onClose),
      ]),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
    );
  }

  Widget _fieldNote(String note) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(note, style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
    );
  }

  Widget _sectionHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: colorPrimary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colorPrimary)),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffix, bool filled = true, Color? fillColor}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
      suffixIcon: suffix,
      filled: filled,
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
}

// ==================== LIMIT SECTION ====================
class _LimitSection extends StatelessWidget {
  const _LimitSection({
    required this.label,
    required this.minCtrl,
    required this.maxCtrl,
    required this.pendingCtrl,
    required this.readOnly,
    required this.enabled,
    required this.aksesValue,
    required this.onAksesChanged,
    required this.manualErrors,
    required this.errorPrefix,
  });

  final String label;
  final TextEditingController minCtrl, maxCtrl, pendingCtrl;
  final bool readOnly;
  final bool enabled;
  final bool aksesValue;
  final ValueChanged<bool?> onAksesChanged;
  final Map<String, String> manualErrors;
  final String errorPrefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colortextwhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffDCE3DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Checkbox(
              activeColor: colorPrimary,
              value: aksesValue,
              onChanged: readOnly ? null : onAksesChanged,
            ),
            Text('Akses $label', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _limitField('Min', minCtrl, readOnly || !enabled, fieldType: 'min', errorKey: '${errorPrefix}_min')),
            const SizedBox(width: 8),
            Expanded(child: _limitField('Max', maxCtrl, readOnly || !enabled, fieldType: 'max', minCtrl: minCtrl, errorKey: '${errorPrefix}_max')),
            const SizedBox(width: 8),
            Expanded(child: _limitField('Pending', pendingCtrl, readOnly || !enabled, fieldType: 'pending', errorKey: '${errorPrefix}_pending')),
          ]),
        ],
      ),
    );
  }

  Widget _limitField(
    String hint,
    TextEditingController ctrl,
    bool isReadOnly, {
    String fieldType = 'min',
    TextEditingController? minCtrl,
    String? errorKey,
  }) {
    final errorText = errorKey != null ? manualErrors[errorKey] : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          readOnly: isReadOnly,
          keyboardType: TextInputType.number,
          inputFormatters: isReadOnly ? [] : [RupiahInputFormatter()],
          decoration: InputDecoration(
            hintText: '0',
            prefixText: 'Rp ',
            prefixStyle: const TextStyle(fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            isDense: true,
            filled: isReadOnly,
            fillColor: isReadOnly ? Colors.grey.shade100 : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            errorText: errorText,
          ),
          style: const TextStyle(fontSize: 12),
          validator: null,
        ),
      ],
    );
  }
}