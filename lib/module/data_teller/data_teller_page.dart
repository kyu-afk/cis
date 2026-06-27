import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../utils/widgets/app_data_grid.dart';
import 'data_teller_notifier.dart';
import 'data_teller_stsrec.dart';
import 'package:flutter/services.dart';
import '../setup/limit_transaksi/limit_transaksi_notifier.dart' show CurrencyInputFormatter;

class DataTellerPage extends StatelessWidget {
  const DataTellerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DataTellerNotifier(context: context),
      child: Consumer<DataTellerNotifier>(
        builder: (context, notifier, child) => Scaffold(
          key: notifier.scaffoldKey,
          backgroundColor: const Color(0xffF3F5F4),
          endDrawer: Drawer(
            width: 600,
            child: _buildDrawer(notifier, context),
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

  Widget _buildHeader(DataTellerNotifier notifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      color: colorPrimary,
      child: Row(
        children: [
          const Text('Data Teller',
              style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colortextwhite,
              foregroundColor: colortextblack,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: notifier.tambahTeller,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Data Teller', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(DataTellerNotifier notifier) {
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
                    hintText: 'Cari Nama atau User ID',
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
            columns: _buildGridColumns(notifier),
            rows: _buildGridRows(notifier),
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

  List<AppGridColumn> _buildGridColumns(DataTellerNotifier notifier) => [
    const AppGridColumn('no', 'No', width: 60, align: Alignment.center),
    const AppGridColumn('namaTeller', 'Nama Teller', width: 160),
    const AppGridColumn('userId', 'User ID', width: 150),
    const AppGridColumn('noSbb', 'No SBB', width: 150),
    const AppGridColumn('namasbb', 'Nama SBB', width: 180),
    const AppGridColumn('kantor', 'Kantor', width: 160),
    AppGridColumn('tglKadaluarsa', 'Tgl Kadaluarsa', width: 140, align: Alignment.centerRight, format: _formatDate),
    AppGridColumn('status', 'Status', width: 140, align: Alignment.center, cellBuilder: (value) => _statusBadge(value)),
    AppGridColumn(
      'aksi',
      'Aksi',
      width: 100,
      align: Alignment.center,
      isAction: true,
      cellBuilder: (_) => const Icon(Icons.edit_note, size: 30, color: Colors.grey),
      onActionTap: (rowData) {
        final teller = DataTellerModel(
          id: rowData['id']?.toString(),
          userId: rowData['userId']?.toString(),
          namaTeller: rowData['namaTeller']?.toString(),
          noSbb: rowData['noSbb']?.toString(),
          namasbb: rowData['namasbb']?.toString(),
          tglKadaluarsa: rowData['tglKadaluarsa']?.toString(),
          kdKantor: rowData['kdKantor']?.toString(),
          namaKantor: rowData['kantor']?.toString(),
          status: rowData['status_raw']?.toString(),
          batch: rowData['batch']?.toString(),
        );
        notifier.openDrawerForAction(teller);
      },
    ),
  ];

  List<Map<String, dynamic>> _buildGridRows(DataTellerNotifier notifier) {
    int no = 0;
    return notifier.filteredList.map((t) => {
      'no': ++no,
      'namaTeller': t.namaTeller ?? '-',
      'userId': t.userId ?? '-',
      'noSbb': t.noSbb ?? '-',
      'namasbb': t.namasbb ?? '-',
      'batch': t.batch ?? '-',
      'kantor': notifier.getNamaKantor(t.kdKantor),
      'tglKadaluarsa': t.tglKadaluarsa ?? '',
      'status': DataTellerStsrec.statusFor(t),
      'status_raw': t.status,
      'id': t.id,
      'kdKantor': t.kdKantor,
    }).toList();
  }

  String _formatDate(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  Widget _statusBadge(dynamic value) {
    final label = value.toString();
    final code = DataTellerStsrec.codeFromLabel(label);
    final color = DataTellerStsrec.badgeColor(code);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  // ==================== DRAWER ====================
  Widget _buildDrawer(DataTellerNotifier notifier, BuildContext context) {
    if (notifier.drawerMode == 'aksi') {
      return _buildActionMenu(notifier, context);
    }
    return _buildFormPanel(notifier, context);
  }

  // ---- Action menu ----
  Widget _buildActionMenu(DataTellerNotifier notifier, BuildContext context) {
    if (notifier.selectedTeller == null) {
      return const Center(child: Text('Pilih data teller terlebih dahulu'));
    }

    final isAktif = DataTellerStsrec.isAktif(notifier.selectedTeller);
    final isBlokir = DataTellerStsrec.isBlokir(notifier.selectedTeller);
    final stsCode = DataTellerStsrec.code(notifier.selectedTeller);

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
                    Text(notifier.selectedTeller!.namaTeller ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('User ID: ${notifier.selectedTeller!.userId ?? '-'}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('No SBB: ${notifier.selectedTeller!.noSbb ?? '-'}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Nama SBB: ${notifier.selectedTeller!.namasbb ?? '-'}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: DataTellerStsrec.badgeColor(stsCode).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        DataTellerStsrec.statusFor(notifier.selectedTeller),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DataTellerStsrec.badgeColor(stsCode)),
                      ),
                    ),
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
                _actionTile(Icons.delete_outline, 'Hapus', Colors.red, () => notifier.pilihAksi('hapus')),
              ] 
              else if (isBlokir) ...[
                _actionTile(Icons.lock_open, 'Unblokir', Colors.green, () => notifier.pilihAksi('unblokir')),
                _actionTile(Icons.delete_outline, 'Hapus', Colors.red, () => notifier.pilihAksi('hapus')),
              ] 
              else ...[
                _actionTile(Icons.delete_outline, 'Hapus', Colors.red, () => notifier.pilihAksi('hapus')),
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

  // ---- Form panel ----
  Widget _buildFormPanel(DataTellerNotifier notifier, BuildContext context) {
    final isReadOnly = notifier.isReadOnly;
    final isFormMode = notifier.isFormMode;
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
                if (notifier.selectedTeller != null && !isTambah) ...[
                  _statusBadge(DataTellerStsrec.statusFor(notifier.selectedTeller)),
                  const SizedBox(height: 16),
                ],

                // User ID (hanya untuk tambah)
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

                // Nama Teller
                _fieldLabel('Nama Teller'),
                TextFormField(
                  controller: notifier.namaTellerCtrl,
                  readOnly: isReadOnly,
                  decoration: _inputDecoration(
                    'Nama Teller',
                    fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
                  ).copyWith(
                    errorText: notifier.manualErrors['namaTeller'],
                  ),
                  validator: null,
                ),
                _fieldNote('* Nama tidak boleh mengandung karakter spesial (!@#\$%^&* dll)'),
                const SizedBox(height: 16),

                // Password (tambah mode)
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
                  const SizedBox(height: 16),
                ],

                // Password (edit mode: dengan checkbox)
                if (isEdit) ...[
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
                  if (notifier.isChangePassword) ...[
                    TextFormField(
                      controller: notifier.passwordCtrl,
                      obscureText: notifier.obscure,
                      decoration: _inputDecoration(
                        'Password baru (min. 6 karakter)',
                        suffix: IconButton(
                          onPressed: notifier.toggleObscure,
                          icon: Icon(notifier.obscure ? Icons.visibility : Icons.visibility_off, size: 20),
                        ),
                      ).copyWith(
                        errorText: notifier.manualErrors['password'],
                      ),
                      validator: null,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],

                // No SBB + tombol verifikasi
                _fieldLabel('No SBB'),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: notifier.noSbbCtrl,
                      readOnly: isReadOnly,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration('No SBB (hanya angka)',
                          fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white).copyWith(
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

                // Nama SBB (readonly dengan validator)
                _fieldLabel('Nama SBB'),
                TextFormField(
                  controller: notifier.namaSbbCtrl,
                  readOnly: true,
                  decoration: _inputDecoration('Nama SBB (otomatis dari pencarian)', filled: true, fillColor: Colors.grey.shade100).copyWith(
                    errorText: notifier.manualErrors['namaSbb'],
                  ),
                  validator: null,
                ),
                const SizedBox(height: 16),

                // Tanggal Kadaluarsa
                _fieldLabel('Tanggal Kadaluarsa'),
                TextFormField(
                  controller: notifier.tglCtrl,
                  readOnly: true,
                  onTap: isReadOnly ? null : notifier.pilihTanggal,
                  decoration: _inputDecoration(
                    'yyyy-mm-dd',
                    suffix: Icon(Icons.calendar_today, size: 18, color: isReadOnly ? Colors.grey : colorPrimary),
                    filled: true,
                    fillColor: isReadOnly ? Colors.grey.shade100 : colortextwhite,
                  ).copyWith(
                    errorText: notifier.manualErrors['tgl'],
                  ),
                  validator: null,
                ),
                const SizedBox(height: 16),

                // Kantor
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

                // BATCH (untuk tambah dan edit)
                if (isFormMode) ...[
                  _fieldLabel('Batch'),
                  TextFormField(
                    controller: notifier.batchCtrl,
                    readOnly: isReadOnly,
                    decoration: _inputDecoration('Batch',
                        fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white).copyWith(
                      errorText: notifier.manualErrors['batch'],
                    ),
                    validator: null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Limit Transaksi (hanya form mode)
                if (isFormMode) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 16, color: colorPrimary),
                      SizedBox(width: 6),
                      Text('Limit Transaksi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorPrimary)),
                    ]),
                  ),
                  _limitTcodeRow(
                    label: 'Setor Tunai (1000)',
                    minCtrl: notifier.limitMinSetorTunaiCtrl,
                    maxCtrl: notifier.limitSetorTunaiCtrl,
                    errorText: notifier.manualErrors['limitSetor'],
                  ),
                  const SizedBox(height: 12),
                  _limitTcodeRow(
                    label: 'Tarik Tunai (1100)',
                    minCtrl: notifier.limitMinTarikTunaiCtrl,
                    maxCtrl: notifier.limitTarikTunaiCtrl,
                    errorText: notifier.manualErrors['limitTarik'],
                  ),
                  const SizedBox(height: 12),
                  _limitTcodeRow(
                    label: 'Pindah Buku (2300)',
                    minCtrl: notifier.limitMinPindahBukuCtrl,
                    maxCtrl: notifier.limitPindahBukuCtrl,
                    errorText: notifier.manualErrors['limitPindah'],
                  ),
                  const SizedBox(height: 16),
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
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: notifier.isSaving ? null : () {
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
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isTambah ? 'Batal' : 'Kembali',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: notifier.isSaving ? null : () => _executeAction(notifier, context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorPrimary,
                    foregroundColor: colortextwhite,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: notifier.isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite))
                      : Text(notifier.tombolUtama, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ==================== EXECUTE ACTION ====================
  Future<void> _executeAction(DataTellerNotifier notifier, BuildContext context) async {
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
    
    await notifier.executeAction();
  }

  Future<bool> _validateBeforeSave(DataTellerNotifier notifier, BuildContext context) async {
    final validationResult = notifier.validateAllFieldsManually();
    final isValid = validationResult['isValid'] as bool;
    final firstErrorKey = validationResult['firstErrorKey'] as String?;
    
    if (!isValid) {
      // Scroll ke field error pertama
      if (firstErrorKey != null) {
        await _scrollToError(notifier, firstErrorKey);
      }
      
      await _showValidationErrorDialog(context);
      return false;
    }
    
    return true;
  }

  Future<void> _scrollToError(DataTellerNotifier notifier, String errorKey) async {
    // Beri waktu sejenak untuk rebuild
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Scroll ke posisi error berdasarkan key
    double targetOffset = 0;
    switch (errorKey) {
      case 'userId':
      case 'namaTeller':
      case 'password':
        targetOffset = 0;
        break;
      case 'noSbb':
        targetOffset = 400;
        break;
      case 'namaSbb':
        targetOffset = 500;
        break;
      case 'tgl':
        targetOffset = 600;
        break;
      case 'kantor':
        targetOffset = 700;
        break;
      case 'batch':
        targetOffset = 800;
        break;
      default:
        targetOffset = 0;
    }
    
    await notifier.scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _showValidationErrorDialog(BuildContext context) async {
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
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: Colors.red,
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
  }

  Future<bool> _showResetPasswordConfirmDialog(DataTellerNotifier notifier, BuildContext context) async {
    final teller = notifier.selectedTeller;
    if (teller == null) return false;

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
                    Text('Data Teller', style: TextStyle(fontSize: 12, color: colortextwhite)),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Apakah Anda yakin ingin mereset password teller ini?',
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
                          _konfirmasiRow('Nama', teller.namaTeller ?? '-'),
                          const SizedBox(height: 6),
                          _konfirmasiRow('User ID', teller.userId ?? '-'),
                          const SizedBox(height: 6),
                          _konfirmasiRow('No SBB', teller.noSbb ?? '-'),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Status', DataTellerStsrec.statusFor(teller)),
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

  Widget _konfirmasiRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _fieldNote(String note) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(note, style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
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

  Widget _limitTcodeRow({
    required String label,
    required TextEditingController minCtrl,
    required TextEditingController maxCtrl,
    String? errorText,
  }) {
    final rpStyle = const TextStyle(fontSize: 13, color: Colors.black54);
    final formatter = [CurrencyInputFormatter()];
    final dec = _inputDecoration('0', fillColor: Colors.white).copyWith(
      prefixText: 'Rp ',
      prefixStyle: rpStyle,
      isDense: true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorPrimary)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Min', style: TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 4),
              TextFormField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: formatter,
                decoration: dec.copyWith(hintText: '0 = tanpa min'),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Max (pending jika lebih)', style: TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 4),
              TextFormField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: formatter,
                decoration: dec.copyWith(hintText: '0 = tanpa max', errorText: errorText),
              ),
            ]),
          ),
        ]),
      ],
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
class _CurrencyInputFormatter extends TextInputFormatter {
  final _formatter = NumberFormat('#,###', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final number = int.tryParse(digitsOnly) ?? 0;
    final formatted = _formatter.format(number);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}