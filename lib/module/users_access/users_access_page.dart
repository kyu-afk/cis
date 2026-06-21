import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../utils/colors.dart';
import '../../utils/widgets/app_data_grid.dart';
import 'users_access_notifier.dart';
import 'users_access_stsrec.dart';

class UsersAccessPage extends StatelessWidget {
  const UsersAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UsersAccessNotifier(context: context),
      child: Consumer<UsersAccessNotifier>(
        builder: (context, notifier, child) => Scaffold(
          key: notifier.scaffoldKey,
          backgroundColor: const Color(0xffF3F5F4),
          endDrawer: Drawer(
            width: 600,
            child: _buildDrawerContent(notifier, context),
          ),
          body: Column(
            children: [
              _buildHeader(notifier),
              Expanded(
                child: notifier.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => notifier.loadAll(),
                        child: _buildTable(notifier),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UsersAccessNotifier notifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      color: colorPrimary,
      child: Row(
        children: [
          const Text('Users Access',
              style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700)),
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
            label: const Text('Tambah User Access', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(UsersAccessNotifier notifier) {
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

  List<AppGridColumn> _buildColumns(UsersAccessNotifier notifier) => [
    const AppGridColumn('no', 'No', width: 60, align: Alignment.center),
    const AppGridColumn('namauser', 'Nama Users', width: 250),
    const AppGridColumn('userid', 'User ID', width: 230),
    const AppGridColumn('kantor', 'Kantor', width: 250),
    AppGridColumn('tglexp', 'Tanggal Kadaluarsa',
        width: 200, align: Alignment.centerRight, format: _formatDate),
    AppGridColumn('stsrec', 'Status', width: 150, align: Alignment.center, cellBuilder: (value) => _statusBadge(value)),
    AppGridColumn(
      'aksi',
      'Aksi',
      width: 100,
      align: Alignment.center,
      isAction: true,
      cellBuilder: (_) => const Icon(Icons.edit_note, size: 30, color: Colors.grey),
      onActionTap: (rowData) {
        final user = UsersAccessModel.fromJson({
          ...rowData,
          'stsrec': rowData['_stsrec_raw'] ?? rowData['stsrec'],
        });
        notifier.openDrawerForAction(user);
      },
    ),
  ];

  List<Map<String, dynamic>> _buildRows(UsersAccessNotifier notifier) {
    int no = 0;
    return notifier.filteredList.map((u) => {
      ...u.toJson(),
      'no': ++no,
      'namauser': u.namauser ?? '-',
      'userid': u.userid ?? '-',
      'kantor': notifier.getNamaKantor(u.kdkantor),
      'tglexp': u.tglexp ?? '',
      'stsrec': UsersAccessStsrec.label(UsersAccessStsrec.code(u)),
      '_stsrec_raw': u.stsrec ?? 'A',
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
    late final Color color;
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
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  // ==================== DRAWER ====================
  Widget _buildDrawerContent(UsersAccessNotifier notifier, BuildContext context) {
    if (notifier.drawerMode == 'aksi') {
      return _buildActionMenu(notifier, context);
    }
    return _buildFormPanel(notifier, context);
  }

  Widget _buildActionMenu(UsersAccessNotifier notifier, BuildContext context) {
    if (notifier.selectedUser == null) {
      return const Center(child: Text('Pilih data user terlebih dahulu'));
    }

    final isAktif = UsersAccessStsrec.isAktif(notifier.selectedUser);
    final isBlokir = UsersAccessStsrec.isBlokir(notifier.selectedUser);
    final stsLabel = UsersAccessStsrec.labelFor(notifier.selectedUser);
    final stsCode = UsersAccessStsrec.code(notifier.selectedUser);

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
                    Text(notifier.selectedUser!.namauser ?? '-',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('User ID: ${notifier.selectedUser!.userid ?? '-'}',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Kantor: ${notifier.getNamaKantor(notifier.selectedUser?.kdkantor)}',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: UsersAccessStsrec.badgeColor(stsCode).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(stsLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: UsersAccessStsrec.badgeColor(stsCode))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Pilih aksi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _actionTile(Icons.edit, 'Edit', colorPrimary, notifier.openDrawerForEdit),
              if (isAktif) ...[
                _actionTile(Icons.lock_reset, 'Reset Password', Colors.blue, notifier.openDrawerForResetPassword), // TAMBAHKAN INI
                _actionTile(Icons.block, 'Blokir', Colors.orange, notifier.openDrawerForBlokir),
                _actionTile(Icons.logout, 'Force Logout', Colors.deepOrange, notifier.openDrawerForForceLogout),
              ],
              if (isBlokir)
                _actionTile(Icons.lock_open, 'Buka Blokir', Colors.green, notifier.openDrawerForBukaBlokir),
              _actionTile(Icons.delete_outline, 'Hapus', Colors.red, notifier.openDrawerForHapus),
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
  Widget _buildFormPanel(UsersAccessNotifier notifier, BuildContext context) {
    final isReadOnly = notifier.isReadOnly;
    final isFormMode = notifier.drawerMode == 'tambah' || notifier.drawerMode == 'edit';

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
                if (notifier.selectedUser != null && notifier.drawerMode != 'tambah') ...[
                  _statusBadge(UsersAccessStsrec.label(UsersAccessStsrec.code(notifier.selectedUser))),
                  const SizedBox(height: 16),
                ],

                // ── User ID ──
                _fieldLabel('User ID'),
                TextFormField(
                  controller: notifier.ctrlUserId,
                  readOnly: notifier.drawerMode != 'tambah',
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration(
                    'User ID',
                    fillColor: notifier.drawerMode != 'tambah' ? Colors.grey.shade100 : Colors.white,
                  ).copyWith(
                    errorText: notifier.manualErrors['userid'],
                  ),
                  validator: null,
                ),
                _fieldNote('* User ID tidak boleh menggunakan spasi, wajib mengandung huruf dan angka'),
                const SizedBox(height: 16),

                // ── Nama Users ──
                _fieldLabel('Nama Users'),
                TextFormField(
                  controller: notifier.ctrlNama,
                  readOnly: isReadOnly,
                  decoration: _inputDecoration(
                    'Nama lengkap user',
                    fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
                  ).copyWith(
                    errorText: notifier.manualErrors['nama'],
                  ),
                  validator: null,
                ),
                _fieldNote('* Nama Users tidak boleh mengandung karakter spesial (!@#\$%^&* dll)'),
                const SizedBox(height: 16),

                // ── Password (hanya pada form mode) ──
                if (isFormMode) ...[
                  if (notifier.drawerMode == 'edit') ...[
                    Row(
                      children: [
                        Checkbox(
                          value: notifier.isChangePassword,
                          onChanged: notifier.toggleChangePassword,
                          activeColor: colorPrimary,
                        ),
                        const Text('Ganti Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (notifier.drawerMode == 'tambah' || notifier.isChangePassword) ...[
                    _fieldLabel('Password'),
                    TextFormField(
                      controller: notifier.ctrlPass,
                      obscureText: notifier.obscurePass,
                      readOnly: isReadOnly,
                      decoration: _inputDecoration(
                        notifier.drawerMode == 'edit' ? 'Password baru (min. 6 karakter)' : 'Min. 6 karakter',
                        fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
                        suffix: !isReadOnly
                            ? IconButton(
                                onPressed: notifier.toggleObscure,
                                icon: Icon(notifier.obscurePass ? Icons.visibility : Icons.visibility_off, size: 20),
                              )
                            : null,
                      ).copyWith(
                        errorText: notifier.manualErrors['password'],
                      ),
                      validator: null,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],

                // ── Tanggal Kadaluarsa ──
                _fieldLabel('Tanggal Kadaluarsa'),
                TextFormField(
                  controller: notifier.ctrlTgl,
                  readOnly: true,
                  onTap: isReadOnly ? null : notifier.pilihTanggal,
                  decoration: _inputDecoration(
                    'yyyy-mm-dd',
                    fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
                    suffix: Icon(Icons.calendar_today, size: 18, color: isReadOnly ? Colors.grey : colorPrimary),
                  ).copyWith(
                    errorText: notifier.manualErrors['tgl'],
                  ),
                  validator: null,
                ),
                const SizedBox(height: 16),

                // ── Kantor ──
                _fieldLabel('Kantor'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<KantorItem>(
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
                      onChanged: isReadOnly ? null : (v) => notifier.setSelectedKantor(v),
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

                // ── Fasilitas (hanya form mode) ──
                if (isFormMode) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('Fasilitas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${notifier.selectedFasilitas.length} dipilih',
                              style: const TextStyle(fontSize: 11, color: colorPrimary, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: notifier.manualErrors['fasilitas'] != null ? Colors.red : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: notifier.listFasilitas.length,
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemBuilder: (_, i) {
                            final f = notifier.listFasilitas[i];
                            final selected = notifier.selectedFasilitas.contains(f);
                            return InkWell(
                              onTap: isReadOnly ? null : () => notifier.toggleFasilitas(f),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected ? colorPrimary.withOpacity(0.05) : null,
                                  border: i > 0 ? const Border(top: BorderSide(color: Color(0xffEEEEEE))) : null,
                                ),
                                child: Row(children: [
                                  Checkbox(
                                    activeColor: colorPrimary,
                                    value: selected,
                                    onChanged: isReadOnly ? null : (_) => notifier.toggleFasilitas(f),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${f.menu}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        if ((f.submenu ?? '').isNotEmpty)
                                          Text(f.submenu!, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                                      ],
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                      if (notifier.manualErrors['fasilitas'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 12),
                          child: Text(
                            notifier.manualErrors['fasilitas']!,
                            style: const TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Bottom buttons ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
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
                  child: Text(notifier.drawerMode == 'tambah' ? 'Batal' : 'Kembali',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: notifier.isSaving ? null : () => _executeAction(notifier, context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tombolColor(notifier.drawerMode),
                    foregroundColor: colortextwhite,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: notifier.isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite))
                      : Text(notifier.tombolLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Color _tombolColor(String? mode) {
    return colorPrimary;
  }

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

  // ==================== EXECUTE ACTION ====================
  Future<void> _executeAction(UsersAccessNotifier notifier, BuildContext context) async {
    switch (notifier.drawerMode) {
      case 'tambah':
      case 'edit':
        if (!await _validateBeforeSave(notifier, context)) {
          return;
        }
        await notifier.simpan();
        break;
      case 'hapus':
        await _confirmAndRun(notifier, context, 'hapus');
        break;
      case 'blokir':
        await _confirmAndRun(notifier, context, 'blokir');
        break;
      case 'bukaBlokir':
        await _confirmAndRun(notifier, context, 'bukaBlokir');
        break;
      case 'forceLogout':
        await notifier.forceLogout();
        break;
      case 'resetPassword':
        await notifier.executeAction();
        break;
    }
  }

  Future<bool> _validateBeforeSave(UsersAccessNotifier notifier, BuildContext context) async {
    final isValid = notifier.validateAllFieldsManually();
    
    if (!isValid) {
      await notifier.scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    color: colorPrimary,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Validasi Gagal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Lengkapi semua field yang wajib diisi dengan benar.',
                        style: TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorPrimary,
                            foregroundColor: colortextwhite,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
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

  // ==================== CONFIRM DIALOG ====================
  Future<bool> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String verb,
    required Color color,
    required IconData icon,
    required String namaUser,
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
                    Text('User Access', style: const TextStyle(fontSize: 12, color: colortextwhite)),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Apakah Anda yakin ingin $verb akun ini?', style: const TextStyle(fontSize: 14)),
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
                          _konfirmasiRow('Nama', namaUser),
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

  Future<void> _confirmAndRun(UsersAccessNotifier notifier, BuildContext context, String action) async {
    final user = notifier.selectedUser;
    if (user == null) return;

    final Map<String, dynamic> config = {
      'hapus': {'title': 'Konfirmasi Hapus', 'verb': 'menghapus', 'color': colorPrimary, 'icon': Icons.delete_outline},
      'blokir': {'title': 'Konfirmasi Blokir', 'verb': 'memblokir', 'color': colorPrimary, 'icon': Icons.block},
      'bukaBlokir': {'title': 'Konfirmasi Buka Blokir', 'verb': 'membuka blokir', 'color': colorPrimary, 'icon': Icons.lock_open},
    };

    final cfg = config[action]!;
    final confirmed = await _showConfirmDialog(
      context: context,
      title: cfg['title'],
      verb: cfg['verb'],
      color: cfg['color'],
      icon: cfg['icon'],
      namaUser: user.namauser ?? '-',
      userId: user.userid ?? '-',
      kantor: notifier.getNamaKantor(user.kdkantor),
      status: UsersAccessStsrec.labelFor(user),
    );

    if (!confirmed) return;

    switch (action) {
      case 'hapus': await notifier.hapus(); break;
      case 'blokir': await notifier.blokir(); break;
      case 'bukaBlokir': await notifier.bukaBlokir(); break;
    }
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
}