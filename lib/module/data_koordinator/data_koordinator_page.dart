import 'package:cis_menu/repository/koordinator_repository.dart';
import 'package:cis_menu/utils/colors.dart';
import 'package:flutter/material.dart';

/// Master Data Koordinator (per BPR) + kelola member (rekening tabungan) lewat inquiry rekening.
class DataKoordinatorPage extends StatefulWidget {
  const DataKoordinatorPage({super.key});

  @override
  State<DataKoordinatorPage> createState() => _DataKoordinatorPageState();
}

class _DataKoordinatorPageState extends State<DataKoordinatorPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await KoordinatorRepository.inquiry(q: _searchCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r['value'] == 1) {
        _items = List<Map<String, dynamic>>.from((r['data'] as List).map((e) => Map<String, dynamic>.from(e)));
      } else {
        _error = r['message']?.toString();
      }
    });
  }

  void _snack(String m, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? Colors.red : Colors.green));
  }

  Future<bool> _confirm(String title, String body, {String ok = 'Ya'}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(ok)),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _form([Map<String, dynamic>? edit]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _KoordinatorForm(edit: edit));
    if (saved == true) {
      _snack('Data koordinator tersimpan');
      _load();
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> k) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reset password ${k['kd_koord']}'),
        content: TextField(controller: ctrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password baru (min 6 karakter)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    if (ctrl.text.length < 6) {
      _snack('Password minimal 6 karakter', error: true);
      return;
    }
    final r = await KoordinatorRepository.resetPassword(k['id'] as int, ctrl.text);
    _snack(r['value'] == 1 ? 'Password direset' : (r['message'] ?? 'Gagal'), error: r['value'] != 1);
  }

  Future<void> _toggleBlokir(Map<String, dynamic> k) async {
    final blok = k['stsaktif'] == 'B';
    if (!await _confirm(blok ? 'Buka blokir' : 'Blokir', '${blok ? 'Buka blokir' : 'Blokir'} koordinator ${k['nama']}?')) return;
    final r = blok ? await KoordinatorRepository.unblokir(k['id'] as int) : await KoordinatorRepository.blokir(k['id'] as int);
    _snack(r['value'] == 1 ? 'Berhasil' : (r['message'] ?? 'Gagal'), error: r['value'] != 1);
    _load();
  }

  Future<void> _hapus(Map<String, dynamic> k) async {
    if (!await _confirm('Hapus koordinator', 'Hapus ${k['kd_koord']} - ${k['nama']}? Koordinator tidak bisa login lagi.', ok: 'Hapus')) return;
    final r = await KoordinatorRepository.delete(k['id'] as int);
    _snack(r['value'] == 1 ? 'Dihapus' : (r['message'] ?? 'Gagal'), error: r['value'] != 1);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF3F5F4),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          color: colorPrimary,
          child: Row(children: [
            const Text('Data Koordinator', style: TextStyle(color: colortextwhite, fontSize: 24, fontWeight: FontWeight.w700)),
            const Spacer(),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _load(),
                style: const TextStyle(color: colortextwhite),
                decoration: InputDecoration(
                  hintText: 'Cari nama koordinator',
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  isDense: true,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white54)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colortextwhite,
                foregroundColor: colortextblack,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _form(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
        else if (_items.isEmpty)
          const Expanded(child: Center(child: Text('Belum ada data koordinator', style: TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _items.length,
                itemBuilder: (_, i) => _card(_items[i]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> k) {
    final blok = k['stsaktif'] == 'B';
    final alamat = [k['jalan'], k['kelurahan'], k['kecamatan'], k['kota']].where((e) => (e ?? '').toString().isNotEmpty).join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffDCE3DF))),
      child: Row(children: [
        CircleAvatar(backgroundColor: colorPrimary.withValues(alpha: 0.1), child: const Icon(Icons.groups, color: colorPrimary)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${k['kd_koord']} — ${k['nama']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
              if (blok) _chip('Diblokir', Colors.red),
            ]),
            const SizedBox(height: 4),
            Text('HP ${k['no_hp'] ?? '-'}  ·  SBB Perantara ${k['sbb_perantara'] ?? '-'}${(k['nama_sbb'] ?? '').toString().isEmpty ? '' : ' (${k['nama_sbb']})'}',
                style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            if (alamat.isNotEmpty) Text(alamat, style: const TextStyle(fontSize: 12.5, color: Colors.black45)),
          ]),
        ),
        _chip('${k['jml_member'] ?? 0} member', colorPrimary),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Kelola member', icon: const Icon(Icons.people_alt_outlined, color: colorPrimary), onPressed: () => showDialog(context: context, builder: (_) => _MemberDialog(koord: k)).then((_) => _load())),
        IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, color: colorPrimary), onPressed: () => _form(k)),
        IconButton(tooltip: 'Reset password', icon: const Icon(Icons.lock_reset, color: Colors.orange), onPressed: () => _resetPassword(k)),
        IconButton(tooltip: blok ? 'Buka blokir' : 'Blokir', icon: Icon(blok ? Icons.lock_open : Icons.block, color: Colors.blueGrey), onPressed: () => _toggleBlokir(k)),
        IconButton(tooltip: 'Hapus', icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _hapus(k)),
      ]),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

InputDecoration _dec(String label, {String? hint, bool ro = false}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: ro ? const Color(0xffF3F5F4) : Colors.white,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );

class _KoordinatorForm extends StatefulWidget {
  final Map<String, dynamic>? edit;
  const _KoordinatorForm({this.edit});

  @override
  State<_KoordinatorForm> createState() => _KoordinatorFormState();
}

class _KoordinatorFormState extends State<_KoordinatorForm> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> c;
  bool _saving = false, _searching = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit ?? {};
    c = {
      for (final f in ['kd_koord', 'nama', 'jalan', 'kelurahan', 'kecamatan', 'kota', 'no_hp', 'sbb_perantara', 'nama_sbb'])
        f: TextEditingController(text: (e[f] ?? '').toString()),
      'password': TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _cariSbb() async {
    final no = c['sbb_perantara']!.text.trim();
    if (no.isEmpty) return;
    setState(() => _searching = true);
    final r = await KoordinatorRepository.inquiryRekening(no, glJns: '1');
    if (!mounted) return;
    setState(() => _searching = false);
    if (r['value'] == 1) {
      c['nama_sbb']!.text = r['nama'];
    } else {
      c['nama_sbb']!.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['message'] ?? 'SBB tidak ditemukan'), backgroundColor: Colors.red));
    }
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (c['nama_sbb']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Klik Cari untuk verifikasi SBB Perantara'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    final r = await KoordinatorRepository.save(
      id: widget.edit?['id'] as int?,
      kdKoord: c['kd_koord']!.text.trim(),
      nama: c['nama']!.text.trim(),
      jalan: c['jalan']!.text.trim(),
      kelurahan: c['kelurahan']!.text.trim(),
      kecamatan: c['kecamatan']!.text.trim(),
      kota: c['kota']!.text.trim(),
      noHp: c['no_hp']!.text.trim(),
      sbbPerantara: c['sbb_perantara']!.text.trim(),
      namaSbb: c['nama_sbb']!.text.trim(),
      password: c['password']!.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r['value'] == 1) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['message'] ?? 'Gagal menyimpan'), backgroundColor: Colors.red));
    }
  }

  Widget _f(String key, String label, {bool ro = false, bool req = true, String? hint, bool obscure = false, TextInputType? kt}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c[key],
          readOnly: ro,
          obscureText: obscure,
          keyboardType: kt,
          decoration: _dec(label, hint: hint, ro: ro),
          validator: (v) => req && (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Koordinator' : 'Tambah Koordinator'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 4),
              _f('kd_koord', 'Kode Koordinator', ro: _isEdit, hint: 'mis. kd01'),
              _f('nama', 'Nama Koordinator'),
              _f('jalan', 'Jalan', req: false),
              _f('kelurahan', 'Kelurahan', req: false),
              _f('kecamatan', 'Kecamatan', req: false),
              _f('kota', 'Kota', req: false),
              _f('no_hp', 'No HP', kt: TextInputType.phone),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _f('sbb_perantara', 'SBB Perantara', kt: TextInputType.number)),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(onPressed: _searching ? null : _cariSbb, child: _searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Cari')),
                ),
              ]),
              _f('nama_sbb', 'Nama SBB', ro: true, req: false, hint: 'Otomatis dari pencarian'),
              if (!_isEdit) _f('password', 'Password awal (min 6 karakter)', obscure: true),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan')),
      ],
    );
  }
}

class _MemberDialog extends StatefulWidget {
  final Map<String, dynamic> koord;
  const _MemberDialog({required this.koord});

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  final _rekCtrl = TextEditingController();
  String _nama = '';
  bool _loading = true, _searching = false, _saving = false;
  List<Map<String, dynamic>> _members = [];

  String get _kd => widget.koord['kd_koord'].toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rekCtrl.dispose();
    super.dispose();
  }

  void _snack(String m, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? Colors.red : Colors.green));

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await KoordinatorRepository.members(_kd);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _members = List<Map<String, dynamic>>.from((r['data'] as List).map((e) => Map<String, dynamic>.from(e)));
    });
  }

  Future<void> _cari() async {
    final no = _rekCtrl.text.trim();
    if (no.isEmpty) return;
    setState(() {
      _searching = true;
      _nama = '';
    });
    final r = await KoordinatorRepository.inquiryRekening(no);
    if (!mounted) return;
    setState(() {
      _searching = false;
      if (r['value'] == 1) _nama = r['nama'];
    });
    if (r['value'] != 1) _snack(r['message'] ?? 'Rekening tidak ditemukan', error: true);
  }

  Future<void> _tambah() async {
    if (_nama.isEmpty) return;
    setState(() => _saving = true);
    final r = await KoordinatorRepository.addMember(_kd, _rekCtrl.text.trim(), _nama);
    if (!mounted) return;
    setState(() => _saving = false);
    if (r['value'] == 1) {
      _snack('Member ditambahkan');
      _rekCtrl.clear();
      setState(() => _nama = '');
      _load();
    } else {
      _snack(r['message'] ?? 'Gagal menambah member', error: true);
    }
  }

  Future<void> _hapus(Map<String, dynamic> m) async {
    final r = await KoordinatorRepository.deleteMember(m['id'] as int);
    _snack(r['value'] == 1 ? 'Member dihapus' : (r['message'] ?? 'Gagal'), error: r['value'] != 1);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Member — ${widget.koord['kd_koord']} ${widget.koord['nama']}'),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: TextField(controller: _rekCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() => _nama = ''), onSubmitted: (_) => _cari(), decoration: _dec('No Rekening Tabungan'))),
            const SizedBox(width: 8),
            SizedBox(height: 44, child: ElevatedButton(onPressed: _searching ? null : _cari, child: _searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Inquiry'))),
          ]),
          const SizedBox(height: 10),
          TextField(readOnly: true, controller: TextEditingController(text: _nama), decoration: _dec('Nama Rekening', hint: 'Otomatis dari inquiry', ro: true)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _nama.isEmpty || _saving ? null : _tambah,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Tambahkan ke Member'),
          ),
          const Divider(height: 24),
          Text('Member terdaftar (${_members.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                    ? const Center(child: Text('Belum ada member', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _members.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          title: Text(_members[i]['no_rek'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(_members[i]['nama_rek'].toString()),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _hapus(_members[i])),
                        ),
                      ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
    );
  }
}
