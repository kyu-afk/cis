import 'package:cis_menu/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sbb_perantara_notifier.dart';

class SbbPerantaraPage extends StatelessWidget {
  const SbbPerantaraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SbbPerantaraNotifier(context: context),
      child: Consumer<SbbPerantaraNotifier>(
        builder: (context, n, _) => Scaffold(
          key: n.scaffoldKey,
          backgroundColor: const Color(0xffF3F5F4),
          endDrawer: Drawer(width: 420, child: _buildDrawer(n)),
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

  Widget _header(SbbPerantaraNotifier n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      color: colorPrimary,
      child: Row(
        children: [
          const Text('SBB Perantara', style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700)),
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
            label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _list(SbbPerantaraNotifier n) {
    if (n.items.isEmpty) {
      return const Center(child: Text('Belum ada data SBB Perantara', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: n.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: n.items.length,
        itemBuilder: (_, i) {
          final item = n.items[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffDCE3DF)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: colorPrimary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.account_balance, color: colorPrimary, size: 20),
              ),
              title: Text(item['no_sbb'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(item['nama_sbb'] ?? '-', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: colorPrimary, size: 20),
                    onPressed: () => n.openEdit(item),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => n.hapus(item),
                    tooltip: 'Hapus',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(SbbPerantaraNotifier n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: colorPrimary,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  n.editingId != null ? 'Edit SBB Perantara' : 'Tambah SBB Perantara',
                  style: const TextStyle(color: colortextwhite, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: colortextwhite),
                onPressed: n.closeDrawer,
              ),
            ],
          ),
        ),
        Expanded(
          child: Form(
            key: n.formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('No SBB', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: n.noSbbCtrl,
                        readOnly: n.editingId != null,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Contoh: 001',
                          hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                          filled: true,
                          fillColor: n.editingId != null ? const Color(0xffF3F5F4) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) {
                          if (n.editingId == null) n.clearNamaSbb();
                        },
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'No SBB wajib diisi' : null,
                      ),
                    ),
                    if (n.editingId == null) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: n.isSearching ? null : n.cariSbb,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: n.isSearching
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Cari', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _field('Nama SBB', n.namaSbbCtrl,
                    hint: n.editingId != null ? 'Nama SBB Perantara' : 'Otomatis dari pencarian',
                    readOnly: n.editingId == null),
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

  Widget _field(String label, TextEditingController ctrl, {String? hint, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
            filled: true,
            fillColor: readOnly ? const Color(0xffF3F5F4) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null,
        ),
      ],
    );
  }
}
