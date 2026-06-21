import 'package:cis_menu/utils/button_custom.dart';
import 'package:cis_menu/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'limit_transaksi_notifier.dart';

class LimitTransaksiPage extends StatelessWidget {
  const LimitTransaksiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LimitTransaksiNotifier(context: context),
      child: Consumer<LimitTransaksiNotifier>(
        builder: (context, notifier, child) => Scaffold(
          key: notifier.scaffoldKey,
          backgroundColor: const Color(0xffF3F5F4),
          endDrawer: Drawer(
            width: 480,
            child: _buildDrawer(notifier),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(notifier),
              Expanded(child: _buildContent(notifier)),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader(LimitTransaksiNotifier notifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      color: colorPrimary,
      child: Row(
        children: [
          const Text(
            'Limit Transaksi',
            style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (notifier.isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite),
              ),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colortextwhite,
              foregroundColor: colortextblack,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: notifier.isLoading ? null : notifier.openDrawer,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Limit', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ==================== CONTENT ====================
  Widget _buildContent(LimitTransaksiNotifier notifier) {
    if (notifier.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notifier.errorMsg != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(notifier.errorMsg!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: notifier.refreshList,
              style: ElevatedButton.styleFrom(backgroundColor: colorPrimary),
              child: const Text('Coba Lagi', style: TextStyle(color: colortextwhite)),
            ),
          ],
        ),
      );
    }

    final aktifCount = notifier.aktifKategoriList.length;
    final nonaktifCount = notifier.nonaktifKategoriList.length;
    final totalCount = notifier.kategoriList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge ringkasan
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge('Total Kategori: $totalCount', Colors.black),
              _badge('Aktif: $aktifCount', Colors.green),
              _badge('Tidak Aktif: $nonaktifCount', Colors.red),
            ],
          ),
        ),
        // Container tabel dengan header freeze
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            decoration: BoxDecoration(
              color: colortextwhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffDCE3DF)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  // Header tabel (sticky / tetap di atas)
                  Container(
                    decoration: const BoxDecoration(
                      color: colorPrimaryLight,
                      border: Border(bottom: BorderSide(color: Color(0xffE3E8E5))),
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FixedColumnWidth(60),
                        1: FixedColumnWidth(240),
                        2: FlexColumnWidth(),
                        3: FixedColumnWidth(220),
                      },
                      children: [
                        TableRow(
                          children: [
                            _thCell('No', align: TextAlign.center),
                            _thCell('Jenis Transaksi', align: TextAlign.left),
                            _thCell('Keterangan', align: TextAlign.left),
                            _thCell('Nilai', align: TextAlign.left),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Body tabel (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(60),
                          1: FixedColumnWidth(240),
                          2: FlexColumnWidth(),
                          3: FixedColumnWidth(220),
                        },
                        border: TableBorder(
                          horizontalInside: BorderSide(color: const Color(0xffDCE3DF), width: .5),
                        ),
                        children: [
                          for (final kategori in notifier.kategoriList) ...[
                            _groupHeaderRow(notifier, kategori),
                            ..._dataRows(notifier, kategori),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
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
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  TableRow _groupHeaderRow(LimitTransaksiNotifier notifier, String kategori) {
    final aktif = notifier.isKategoriAktif(kategori);
    final label = notifier.getKategoriLabel(kategori);

    return TableRow(
      decoration: const BoxDecoration(color: Color(0xffF3F5F4)),
      children: [
        Container(height: 36, child: const SizedBox()),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              const SizedBox(width: 8),
              _aksesBadge(aktif),
            ]),
          ),
        ),
        const SizedBox(),
        const SizedBox(),
      ],
    );
  }

  List<TableRow> _dataRows(LimitTransaksiNotifier notifier, String kategori) {
    final aktif = notifier.isKategoriAktif(kategori);
    final limits = notifier.getByKategori(kategori);
    final label = notifier.getKategoriLabel(kategori);

    int globalOffset = 0;
    for (final k in notifier.kategoriList) {
      if (k == kategori) break;
      globalOffset += notifier.getByKategori(k).length;
    }

    int localNo = 0;
    return limits.map((l) {
      localNo++;
      final no = globalOffset + localNo;
      final textColor = aktif ? Colors.black87 : const Color(0xFFAAAAAA);
      final nominalColor = aktif ? Colors.black87 : const Color(0xFFCCCCCC);

      return TableRow(
        children: [
          _tdCell(no.toString(), align: TextAlign.center, color: textColor),
          _tdCell(label, color: textColor),
          _tdCell(l.keterangan, color: textColor),
          _tdCell(notifier.formatRupiah(l.nilai), align: TextAlign.right, color: nominalColor),
        ],
      );
    }).toList();
  }

  // ==================== DRAWER (menggunakan WIP state) ====================
  Widget _buildDrawer(LimitTransaksiNotifier notifier) {
    if (!notifier.isEditing) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: notifier.formKey,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: colorPrimary,
            child: Row(children: [
              const Expanded(
                child: Text(
                  'Edit Limit Transaksi',
                  style: TextStyle(color: colortextwhite, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: colortextwhite),
                onPressed: notifier.closeDrawer,
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final kategori in notifier.kategoriList)
                  _kategoriBlockWip(notifier, kategori),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: colortextwhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(children: [
              Expanded(
                child: ButtonDelete(
                  name: 'Batal',
                  onTap: notifier.closeDrawer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ButtonPrimary(
                  name: notifier.isSaving ? 'Menyimpan...' : 'Simpan',
                  onTap: notifier.isSaving ? () {} : notifier.saveAll,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _kategoriBlockWip(LimitTransaksiNotifier notifier, String kategori) {
    final label = notifier.getKategoriLabel(kategori);
    final limits = notifier.getWipByKategori(kategori);
    final isAktif = notifier.isWipKategoriAktif(kategori);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffDCE3DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                _aksesBadge(isAktif),
              ]),
              Switch(
                value: isAktif,
                onChanged: (value) {
                  notifier.toggleAkses(kategori, value);
                },
                activeColor: colorPrimary,
                inactiveThumbColor: Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...limits.map((l) => _limitField(
                l,
                wajib: isAktif,
                enabled: isAktif,
                allLimits: limits,
              )),
        ],
      ),
    );
  }

  Widget _limitField(LimitData l, {required bool wajib, bool enabled = true, List<LimitData> allLimits = const []}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(l.keterangan, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            if (wajib && l.fieldType != 'pending')
              const Text(' *wajib', style: TextStyle(fontSize: 11, color: Color(0xFFA32D2D)))
            else
              const Text(' (opsional)', style: TextStyle(fontSize: 11, color: Colors.black45)),
          ]),
          const SizedBox(height: 4),
          TextFormField(
            controller: l.ctrl,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: InputDecoration(
              prefixText: 'Rp.',
              hintText: '0',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            validator: (wajib && enabled)
                ? (v) {
                    final raw = (v ?? '').replaceAll(RegExp(r'[^\d]'), '').trim();
                    final val = double.tryParse(raw) ?? 0;
                    if (l.fieldType == 'pending') return null; // pending always optional
                    if (raw.isEmpty || val <= 0) {
                      return '${l.keterangan} tidak boleh nol';
                    }
                    if (l.fieldType == 'max') {
                      final minData = allLimits.firstWhere(
                        (x) => x.kategori == l.kategori && x.fieldType == 'min',
                        orElse: () => l,
                      );
                      final minRaw = minData.ctrl.text.replaceAll(RegExp(r'[^\d]'), '').trim();
                      final minVal = double.tryParse(minRaw) ?? 0;
                      if (val < minVal) return '${l.keterangan} tidak boleh lebih kecil dari Min';
                    }
                    return null;
                  }
                : null,
          ),
        ],
      ),
    );
  }

  // ==================== TABLE HELPERS ====================
  Widget _thCell(String text, {TextAlign align = TextAlign.left}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(
          text,
          textAlign: align,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colortextwhite),
        ),
      ),
    );
  }

  Widget _tdCell(String text,
      {TextAlign align = TextAlign.left, Color color = Colors.black87}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(fontSize: 13, color: color),
        ),
      ),
    );
  }

  Widget _aksesBadge(bool aktif) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: aktif ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: aktif ? const Color(0xFFC0DD97) : const Color(0xFFF7C1C1),
        ),
      ),
      child: Text(
        aktif ? 'Aktif' : 'Tidak aktif',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: aktif ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D),
        ),
      ),
    );
  }
}