import 'package:cis_menu/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'modal_kolektor_notifier.dart';

class ModalKolektorPage extends StatefulWidget {
  const ModalKolektorPage({super.key});

  @override
  State<ModalKolektorPage> createState() => _ModalKolektorPageState();
}

class _ModalKolektorPageState extends State<ModalKolektorPage> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        context.read<ModalKolektorNotifier?>()?.toggleDropdown(false);
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
      create: (_) => ModalKolektorNotifier(context: context),
      child: Consumer<ModalKolektorNotifier>(
        builder: (context, n, _) => Scaffold(
          key: n.scaffoldKey,
          backgroundColor: const Color(0xffF3F5F4),
          endDrawer: Drawer(
            width: 480,
            child: n.selectedItem != null ? _buildActionDrawer(n) : _buildFormDrawer(n),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(n),
              if (n.isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (n.errorMsg != null)
                Expanded(child: Center(child: Text(n.errorMsg!, style: const TextStyle(color: Colors.red))))
              else
                Expanded(child: _list(n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ModalKolektorNotifier n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      color: colorPrimary,
      child: Row(
        children: [
          const Text('Modal Kolektor', style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colortextwhite,
              foregroundColor: colortextblack,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: n.openAdd,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Modal', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _list(ModalKolektorNotifier n) {
    if (n.items.isEmpty) {
      return const Center(child: Text('Belum ada data modal kolektor', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: n.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: n.items.length,
        itemBuilder: (_, i) {
          final item = n.items[i];
          final isDiberikan = item['status'] == 'DIBERIKAN';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDiberikan ? Colors.green.shade200 : const Color(0xffDCE3DF)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: isDiberikan ? Colors.green.shade50 : colorPrimary.withValues(alpha: 0.1),
                child: Icon(isDiberikan ? Icons.check_circle : Icons.account_balance_wallet,
                    color: isDiberikan ? Colors.green : colorPrimary, size: 20),
              ),
              title: Text(item['petugas_nama'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['petugas_hp'] ?? '-', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(n.fmtNominal(item['nominal']),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorPrimary)),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDiberikan ? Colors.green.shade100 : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(n.fmtStatus(item['status']),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: isDiberikan ? Colors.green.shade800 : Colors.amber.shade800)),
                  ),
                  if (!isDiberikan) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => n.openActionDrawer(item),
                      child: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormDrawer(ModalKolektorNotifier n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: colorPrimary,
          child: Row(
            children: [
              const Expanded(
                child: Text('Tambah Modal Kolektor',
                    style: TextStyle(color: colortextwhite, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(icon: const Icon(Icons.close, color: colortextwhite), onPressed: n.closeDrawer),
            ],
          ),
        ),
        Expanded(
          child: Form(
            key: n.formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Cari Petugas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                _buildTypeAhead(n),
                const SizedBox(height: 16),
                const Text('No HP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: n.noHpCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Otomatis dari pilihan petugas',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                    filled: true,
                    fillColor: const Color(0xffF3F5F4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Nominal Modal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: n.nominalCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Masukkan nominal',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                    prefixText: 'Rp ',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: n.onNominalChanged,
                  validator: (_) => n.nominalValue <= 0 ? 'Nominal wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                const Text('Keterangan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: n.keteranganCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Opsional',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: n.closeDrawer,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colortextwhite,
                    backgroundColor: colorcancel,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: n.isSaving ? null : n.simpan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorPrimary,
                    foregroundColor: colortextwhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: n.isSaving
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

  Widget _buildActionDrawer(ModalKolektorNotifier n) {
    final item = n.selectedItem!;
    final isDiberikan = item['status'] == 'DIBERIKAN';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: colorPrimary,
          child: Row(
            children: [
              const Expanded(
                child: Text('Detail Modal', style: TextStyle(color: colortextwhite, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(icon: const Icon(Icons.close, color: colortextwhite), onPressed: n.closeDrawer),
            ],
          ),
        ),
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
                    Text(item['petugas_nama'] ?? '-',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _infoRow('No HP', item['petugas_hp'] ?? '-'),
                    _infoRow('Nominal', n.fmtNominal(item['nominal'])),
                    _infoRow('Status', n.fmtStatus(item['status'])),
                    if ((item['teller_nama'] ?? '').isNotEmpty)
                      _infoRow('Diberikan oleh', item['teller_nama']),
                    if ((item['diberikan_at'] ?? '').isNotEmpty)
                      _infoRow('Tanggal', item['diberikan_at']),
                  ],
                ),
              ),
              if (!isDiberikan) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: n.hapus,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Hapus Modal', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeAhead(ModalKolektorNotifier n) {
    final suggestions = n.getSuggestions(n.searchCtrl.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: n.searchCtrl,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Ketik nama atau nomor HP...',
            hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: n.searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      n.searchCtrl.clear();
                      n.selectedPetugasHp = null;
                      n.noHpCtrl.clear();
                      n.toggleDropdown(false);
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (v) {
            n.selectedPetugasHp = null;
            n.noHpCtrl.clear();
            n.toggleDropdown(v.isNotEmpty);
          },
          validator: (_) => n.selectedPetugasHp == null ? 'Pilih petugas dari daftar' : null,
        ),
        if (n.showDropdown && suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (_, i) => InkWell(
                onTap: () {
                  n.onPetugasSelected(suggestions[i]);
                  FocusScope.of(context).unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(suggestions[i], style: const TextStyle(fontSize: 14)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          const Text(': ', style: TextStyle(color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
