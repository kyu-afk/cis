import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../models/index.dart';
import '../../repository/collector_repository.dart';
import '../../repository/users_access_repository.dart';
import '../../repository/setup_transaksi_repository.dart';
import '../../network/network.dart';
import '../../pref/pref.dart';
import '../../utils/colors.dart';
import '../../utils/user_level.dart';
import 'data_petugas_stsrec.dart';
import 'package:flutter/foundation.dart';

// ==================== MODEL ====================
class DataPetugasModel {
  String? id;
  String? userId;
  String? nama;
  String? noHp;
  String? nip;
  String? kdKantor;
  String? namaKantor;
  String? kodePetugas;
  String? noSbb;
  String? namaSbb;
  String? status;
  bool? isTransaksiDibuka;
  String? limitSetorMin, limitSetorMax, limitSetorPending;
  String? limitTarikMin, limitTarikMax, limitTarikPending;
  String? limitTransferMin, limitTransferMax, limitTransferPending;
  String? limitPpobMin, limitPpobMax, limitPpobPending;
  String? limitKreditMin, limitKreditMax, limitKreditPending;
  bool aksesSetor = false;
  bool aksesTarik = false;
  bool aksesTransfer = false;
  bool aksesPpob = false;
  bool aksesKredit = false;
  bool? transaksiKolektor;
  String? mpin;
  String? mpinLock;
  String? mpinCetak;

  DataPetugasModel({
    this.id,
    this.userId,
    this.nama,
    this.noHp,
    this.nip,
    this.kdKantor,
    this.namaKantor,
    this.kodePetugas,
    this.noSbb,
    this.namaSbb,
    this.status,
    this.isTransaksiDibuka,
    this.limitSetorMin,
    this.limitSetorMax,
    this.limitSetorPending,
    this.limitTarikMin,
    this.limitTarikMax,
    this.limitTarikPending,
    this.limitTransferMin,
    this.limitTransferMax,
    this.limitTransferPending,
    this.limitPpobMin,
    this.limitPpobMax,
    this.limitPpobPending,
    this.limitKreditMin,
    this.limitKreditMax,
    this.limitKreditPending,
    this.aksesSetor = false,
    this.aksesTarik = false,
    this.aksesTransfer = false,
    this.aksesPpob = false,
    this.aksesKredit = false,
    this.transaksiKolektor,
    this.mpin,
    this.mpinLock,
    this.mpinCetak,
  });

  factory DataPetugasModel.fromJson(Map<String, dynamic> json) {
    return DataPetugasModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['userid'] ?? json['user_id'] ?? '').toString(),
      nama: (json['nama'] ?? '').toString(),
      noHp: (json['nohp'] ?? '').toString(),
      nip: (json['nip'] ?? '').toString(),
      kdKantor: (json['kd_kantor'] ?? '').toString(),
      namaKantor: (json['nama_kantor'] ?? '').toString(),
      kodePetugas: (json['kd_collector'] ?? '').toString(),
      noSbb: (json['nosbb'] ?? '').toString(),
      namaSbb: (json['nama_sbb'] ?? '').toString(),
      status: (json['status'] ?? 'aktif').toString().trim().toLowerCase(),
      limitSetorMin: (json['limit_setor_tunai_trx_min'] ?? 0).toString(),
      limitSetorMax: (json['limit_setor_tunai_trx_max'] ?? 0).toString(),
      limitSetorPending: (json['limit_pending_setor'] ?? 0).toString(),
      limitTarikMin: (json['limit_tarik_tunai_trx_min'] ?? 0).toString(),
      limitTarikMax: (json['limit_tarik_tunai_trx_max'] ?? 0).toString(),
      limitTarikPending: (json['limit_pending_tarik_tunai'] ?? 0).toString(),
      limitTransferMin: (json['limit_transfer_trx_min'] ?? 0).toString(),
      limitTransferMax: (json['limit_transfer_trx_max'] ?? 0).toString(),
      limitTransferPending: (json['limit_pending_trf'] ?? 0).toString(),
      limitPpobMin: (json['limit_ppob_trx_min'] ?? 0).toString(),
      limitPpobMax: (json['limit_ppob_trx_max'] ?? 0).toString(),
      limitPpobPending: (json['limit_pending_ppob'] ?? 0).toString(),
      limitKreditMin: (json['limit_byrloan_trx_min'] ?? 0).toString(),
      limitKreditMax: (json['limit_byrloan_trx_max'] ?? 0).toString(),
      limitKreditPending: (json['limit_pending_kredit'] ?? 0).toString(),
      aksesSetor: (json['akses_setor'] ?? 'N').toString().toUpperCase() == 'Y',
      aksesTarik: (json['akses_tartun'] ?? 'N').toString().toUpperCase() == 'Y',
      aksesTransfer: (json['akses_transfer'] ?? 'N').toString().toUpperCase() == 'Y',
      aksesPpob: (json['akses_ppob'] ?? 'N').toString().toUpperCase() == 'Y',
      aksesKredit: (json['akses_kredit'] ?? 'N').toString().toUpperCase() == 'Y',
      transaksiKolektor: json['transaksi_kolektor'] == true,
      mpin: (json['mpin'] ?? '').toString(),
      mpinLock: (json['mpin_lock'] ?? '').toString(),
      mpinCetak: (json['mpin_cetak'] ?? 'N').toString(),
    );
  }
}

class KantorDummy {
  final String kdKantor;
  final String namaKantor;
  final String bprId;
  KantorDummy(this.kdKantor, this.namaKantor, this.bprId);

  @override
  bool operator ==(Object other) =>
      other is KantorDummy && other.kdKantor == kdKantor;
  @override
  int get hashCode => kdKantor.hashCode;
}

// ==================== NOTIFIER ====================
class DataPetugasNotifier extends ChangeNotifier {
  static String _fmtCtrl(String? raw) => RupiahInputFormatter.formatValue(raw);
  final BuildContext context;

  DataPetugasNotifier({required this.context}) {
    _init();
  }

  // ==================== KEYS ====================
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();
  final scrollController = ScrollController();

  // ==================== DATA ====================
  List<DataPetugasModel> _list = [];
  List<DataPetugasModel> get list => _list;

  List<DataPetugasModel> _filteredList = [];
  List<DataPetugasModel> get filteredList => _filteredList;

  List<KantorDummy> _listKantor = [];
  List<KantorDummy> get listKantor => _listKantor;

  // ==================== SEARCH ====================
  final searchCtrl = TextEditingController();
  String _searchKeyword = '';
  Timer? _debounceTimer;

  // ==================== STATE ====================
  bool isLoading = true;
  bool isSaving = false;
  bool isLoadingVerifikasi = false;
  bool obscure = true;
  bool isChangePassword = false;

  DataPetugasModel? selectedPetugas;
  KantorDummy? selectedKantor;

  // Manual errors
  Map<String, String> _manualErrors = {};
  Map<String, String> get manualErrors => _manualErrors;

  // ==================== FORM CONTROLLERS ====================
  final userIdCtrl = TextEditingController();
  final namaCtrl = TextEditingController();
  final noHpCtrl = TextEditingController();
  final nipCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final kodePetugasCtrl = TextEditingController();
  final noSbbCtrl = TextEditingController();
  final namaSbbCtrl = TextEditingController();
  final alasanCtrl = TextEditingController();

  // Limit controllers
  final limitSetorMinCtrl = TextEditingController();
  final limitSetorMaxCtrl = TextEditingController();
  final limitSetorPendingCtrl = TextEditingController();
  final limitTarikMinCtrl = TextEditingController();
  final limitTarikMaxCtrl = TextEditingController();
  final limitTarikPendingCtrl = TextEditingController();
  final limitTransferMinCtrl = TextEditingController();
  final limitTransferMaxCtrl = TextEditingController();
  final limitTransferPendingCtrl = TextEditingController();
  final limitPpobMinCtrl = TextEditingController();
  final limitPpobMaxCtrl = TextEditingController();
  final limitPpobPendingCtrl = TextEditingController();
  final limitKreditMinCtrl = TextEditingController();
  final limitKreditMaxCtrl = TextEditingController();
  final limitKreditPendingCtrl = TextEditingController();

  // Akses checkboxes
  bool aksesSetor = false;
  bool aksesTarik = false;
  bool aksesTransfer = false;
  bool aksesPpob = false;
  bool aksesKredit = false;

  // Enable/disable limit fields
  bool enableLimitSetor = false;
  bool enableLimitTarik = false;
  bool enableLimitTransfer = false;
  bool enableLimitPpob = false;
  bool enableLimitKredit = false;

  // ==================== AKSES TCODE (DINAMIS, GANTI 5 AKSES HARDCODE DI ATAS) ====================
  // Disimpan ke cis_limit_petugas via _saveTcodeAksesLimit() setelah insert/update sukses.
  // Centang = is_aktif Y; uncentang = is_aktif N dan semua limit direset ke 0.
  bool isLoadingTcodeAkses = false;
  int _tcodeAksesLoadGen = 0;
  List<Map<String, dynamic>> tcodeAksesList = [];
  // tiap item: {tcode, keterangan, checked, minCtrl, maxCtrl, pendingCtrl}

  // Cache lookup userid dari web service DB (key: nohp / backend_id)
  final Map<String, String> _userIdByNoHp = {};
  final Map<String, String> _userIdByBackendId = {};

  String _resolvePetugasUserId() {
    if (drawerMode == 'edit') {
      final fromSelected = selectedPetugas?.userId?.trim() ?? '';
      if (fromSelected.isNotEmpty) return fromSelected;
    }
    final fromCtrl = userIdCtrl.text.trim();
    if (fromCtrl.isNotEmpty) return fromCtrl;

    final noHp = noHpCtrl.text.trim();
    if (noHp.isNotEmpty && _userIdByNoHp.containsKey(noHp)) {
      return _userIdByNoHp[noHp]!;
    }
    final backendId = selectedPetugas?.id?.trim() ?? '';
    if (backendId.isNotEmpty && _userIdByBackendId.containsKey(backendId)) {
      return _userIdByBackendId[backendId]!;
    }
    return '';
  }

  Future<String> _resolvePetugasUserIdAsync() async {
    final cached = _resolvePetugasUserId();
    if (cached.isNotEmpty) return cached;

    final result = await CollectorRepository.resolveUserIdCollector(
      userId: userIdCtrl.text.trim().isNotEmpty ? userIdCtrl.text.trim() : null,
      noHp: noHpCtrl.text.trim().isNotEmpty ? noHpCtrl.text.trim() : null,
      backendId: selectedPetugas?.id,
    );
    if (result['value'] == 1) {
      final resolved = (result['userid'] ?? '').toString();
      if (resolved.isNotEmpty) {
        _cacheResolvedUserId(resolved);
        if (selectedPetugas != null) selectedPetugas!.userId = resolved;
        if (userIdCtrl.text.trim().isEmpty) userIdCtrl.text = resolved;
        return resolved;
      }
    }
    return '';
  }

  void _cacheResolvedUserId(String userId) {
    final noHp = noHpCtrl.text.trim();
    if (noHp.isNotEmpty) _userIdByNoHp[noHp] = userId;
    final backendId = selectedPetugas?.id?.trim() ?? '';
    if (backendId.isNotEmpty) _userIdByBackendId[backendId] = userId;
  }

  void _buildUserIdLookupFromEnrichedList(List<DataPetugasModel> list) {
    _userIdByNoHp.clear();
    _userIdByBackendId.clear();
    for (final p in list) {
      final userId = p.userId?.trim() ?? '';
      if (userId.isEmpty) continue;
      final noHp = (p.noHp ?? '').trim();
      if (noHp.isNotEmpty) _userIdByNoHp[noHp] = userId;
      final backendId = (p.id ?? '').trim();
      if (backendId.isNotEmpty) _userIdByBackendId[backendId] = userId;
    }
  }

  /// Sinkronkan tcode dinamis ke field akses/limit lama middleware (1000=setor, 1100=tarik, 2300=transfer).
  ({Map<String, dynamic> limitData, Map<String, bool> aksesData}) _buildMiddlewarePayloadFromTcode() {
    final limitData = <String, dynamic>{
      'limit_setor_tunai_trx_min': 0,
      'limit_setor_tunai_trx_max': 0,
      'limit_pending_setor': 0,
      'limit_tarik_tunai_trx_min': 0,
      'limit_tarik_tunai_trx_max': 0,
      'limit_pending_tarik_tunai': 0,
      'limit_transfer_trx_min': 0,
      'limit_transfer_trx_max': 0,
      'limit_pending_trf': 0,
      'limit_ppob_trx_min': 0,
      'limit_ppob_trx_max': 0,
      'limit_pending_ppob': 0,
      'limit_byrloan_trx_min': 0,
      'limit_byrloan_trx_max': 0,
      'limit_pending_kredit': 0,
    };
    final aksesData = <String, bool>{
      'akses_setor': false,
      'akses_tartun': false,
      'akses_transfer': false,
      'akses_ppob': false,
      'akses_kredit': false,
    };

    const tcodeMap = {
      '1000': {
        'akses': 'akses_setor',
        'min': 'limit_setor_tunai_trx_min',
        'max': 'limit_setor_tunai_trx_max',
        'pending': 'limit_pending_setor',
      },
      '1100': {
        'akses': 'akses_tartun',
        'min': 'limit_tarik_tunai_trx_min',
        'max': 'limit_tarik_tunai_trx_max',
        'pending': 'limit_pending_tarik_tunai',
      },
      '2300': {
        'akses': 'akses_transfer',
        'min': 'limit_transfer_trx_min',
        'max': 'limit_transfer_trx_max',
        'pending': 'limit_pending_trf',
      },
    };

    for (final item in tcodeAksesList) {
      final tcode = item['tcode']?.toString() ?? '';
      final cfg = tcodeMap[tcode];
      if (cfg == null) continue;
      final checked = item['checked'] == true;
      aksesData[cfg['akses']!] = checked;
      if (!checked) continue;
      limitData[cfg['min']!] = _parseNominal((item['minCtrl'] as TextEditingController).text);
      limitData[cfg['max']!] = _parseNominal((item['maxCtrl'] as TextEditingController).text);
      limitData[cfg['pending']!] = _parseNominal((item['pendingCtrl'] as TextEditingController).text);
    }

    return (limitData: limitData, aksesData: aksesData);
  }

  /// Cek apakah item hasil inquiry setup-transaksi benar-benar punya konfigurasi
  /// (jenis debit/kredit terisi), bukan cuma row kosong/null hasil dari "Tutup".
  static bool _isTcodeItemConfigured(dynamic item) {
    if (item is! Map) return false;
    final jnsDr = (item['jns_acc_dr'] ?? '').toString().trim();
    final jnsCr = (item['jns_acc_cr'] ?? '').toString().trim();
    return jnsDr.isNotEmpty || jnsCr.isNotEmpty;
  }

  Future<void> _loadTcodeAksesAktif() async {
    final loadGen = ++_tcodeAksesLoadGen;
    _disposeTcodeAksesControllers();
    tcodeAksesList = [];
    isLoadingTcodeAkses = true;
    notifyListeners();

    final result = await SetupTransaksiRepository.listTcode();
    if (loadGen != _tcodeAksesLoadGen) return;
    if (result['value'] != 1) {
      isLoadingTcodeAkses = false;
      notifyListeners();
      return;
    }

    final List<dynamic> raw = result['data'] ?? [];
    final loadedItems = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (loadGen != _tcodeAksesLoadGen) return;
      final tcode = (e['tcode'] ?? '').toString();
      final keterangan = (e['keterangan'] ?? '').toString();
      if (tcode.isEmpty) continue;

      // Cek status di Transaksi Collector: Y kalau sudah ada konfigurasi tersimpan
      final checkResult = await SetupTransaksiRepository.inquirySetupTransaksi(trxCode: tcode);
      bool isConfigured = false;
      if (checkResult['value'] == 1 && checkResult['data'] != null) {
        final data = checkResult['data'];
        final List<dynamic> items = data is List ? data : (data['items'] ?? data['data'] ?? []);
        isConfigured = items.isNotEmpty && _isTcodeItemConfigured(items.first);
      }

      // Hanya tampilkan tcode yang statusnya "Y" di Transaksi Collector
      if (isConfigured) {
        loadedItems.add({
          'tcode': tcode,
          'keterangan': keterangan,
          'checked': false,
          'minCtrl': TextEditingController(text: '0'),
          'maxCtrl': TextEditingController(text: '0'),
          'pendingCtrl': TextEditingController(text: '0'),
          // Snapshot nilai ASLI (sebelum user ubah apa pun), dipakai buat
          // deteksi perubahan & tampilan "Sebelum -> Sesudah" di konfirmasi.
          'origChecked': false,
          'origMin': '0',
          'origMax': '0',
          'origPending': '0',
        });
      }
    }

    if (loadGen != _tcodeAksesLoadGen) return;
    tcodeAksesList = loadedItems;

    // Kalau lagi edit petugas yang sudah ada, timpa nilai default di atas
    // dengan limit yang sudah pernah disimpan sebelumnya (kalau ada).
    final existingUserId = await _resolvePetugasUserIdAsync();
    if (existingUserId.isNotEmpty) {
      final limitResult = await CollectorRepository.getLimitPetugas(
        userId: existingUserId,
        noHp: noHpCtrl.text.trim().isNotEmpty ? noHpCtrl.text.trim() : null,
        backendId: selectedPetugas?.id,
      );
      if (loadGen != _tcodeAksesLoadGen) return;
      if (limitResult['value'] == 1) {
        final savedLimits = limitResult['limits'] as List<dynamic>;
        final rupiahFmt = NumberFormat('#,###', 'id_ID');
        for (final saved in savedLimits) {
          final tcode = saved['tcode']?.toString() ?? '';
          final idx = tcodeAksesList.indexWhere((item) => item['tcode'] == tcode);
          if (idx == -1) continue;
          final isAktif = saved['is_aktif'] == true;
          final min = isAktif ? ((saved['min_nominal'] as num?)?.toDouble() ?? 0.0) : 0.0;
          final max = isAktif ? ((saved['limit_nominal'] as num?)?.toDouble() ?? 0.0) : 0.0;
          final pending = isAktif ? ((saved['pending_nominal'] as num?)?.toDouble() ?? 0.0) : 0.0;
          tcodeAksesList[idx]['checked'] = isAktif;
          (tcodeAksesList[idx]['minCtrl'] as TextEditingController).text =
              min == 0 ? '0' : rupiahFmt.format(min.toInt());
          (tcodeAksesList[idx]['maxCtrl'] as TextEditingController).text =
              max == 0 ? '0' : rupiahFmt.format(max.toInt());
          (tcodeAksesList[idx]['pendingCtrl'] as TextEditingController).text =
              pending == 0 ? '0' : rupiahFmt.format(pending.toInt());

          // Snapshot setelah keisi nilai dari server, BUKAN sebelum.
          tcodeAksesList[idx]['origChecked'] = isAktif;
          tcodeAksesList[idx]['origMin'] = (tcodeAksesList[idx]['minCtrl'] as TextEditingController).text;
          tcodeAksesList[idx]['origMax'] = (tcodeAksesList[idx]['maxCtrl'] as TextEditingController).text;
          tcodeAksesList[idx]['origPending'] = (tcodeAksesList[idx]['pendingCtrl'] as TextEditingController).text;
        }
      }
    }

    if (loadGen != _tcodeAksesLoadGen) return;
    isLoadingTcodeAkses = false;
    notifyListeners();
  }

  double _parseNominal(String text) {
    final clean = text.trim().replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(clean) ?? 0.0;
  }

  Future<Map<String, dynamic>> _saveTcodeAksesLimit() async {
    final uid = await _resolvePetugasUserIdAsync();
    if (uid.isEmpty) {
      return {'value': 0, 'message': 'User ID petugas tidak ditemukan'};
    }
    if (isLoadingTcodeAkses) {
      return {'value': 0, 'message': 'Data tcode masih dimuat. Tunggu sebentar lalu coba lagi.'};
    }
    if (tcodeAksesList.isEmpty) {
      return {'value': 0, 'message': 'Belum ada tcode aktif yang bisa disimpan'};
    }

    final limits = tcodeAksesList.map((item) {
      final checked = item['checked'] == true;
      return {
        'tcode': item['tcode'],
        'keterangan': item['keterangan'],
        'is_aktif': checked,
        'min_nominal': checked
            ? _parseNominal((item['minCtrl'] as TextEditingController).text)
            : 0.0,
        'limit_nominal': checked
            ? _parseNominal((item['maxCtrl'] as TextEditingController).text)
            : 0.0,
        'pending_nominal': checked
            ? _parseNominal((item['pendingCtrl'] as TextEditingController).text)
            : 0.0,
      };
    }).toList();

    return CollectorRepository.saveLimitPetugas(
      userId: uid,
      noHp: noHpCtrl.text.trim().isNotEmpty ? noHpCtrl.text.trim() : null,
      backendId: selectedPetugas?.id,
      limits: limits,
    );
  }

  void _disposeTcodeAksesControllers() {
    for (final item in tcodeAksesList) {
      (item['minCtrl'] as TextEditingController).dispose();
      (item['maxCtrl'] as TextEditingController).dispose();
      (item['pendingCtrl'] as TextEditingController).dispose();
    }
  }

  void toggleTcodeAkses(int index, bool? value) {
    if (index < 0 || index >= tcodeAksesList.length) return;
    final checked = value ?? false;
    tcodeAksesList[index]['checked'] = checked;
    if (!checked) {
      final tcode = tcodeAksesList[index]['tcode']?.toString() ?? '';
      (tcodeAksesList[index]['minCtrl'] as TextEditingController).text = '0';
      (tcodeAksesList[index]['maxCtrl'] as TextEditingController).text = '0';
      (tcodeAksesList[index]['pendingCtrl'] as TextEditingController).text = '0';
      _manualErrors.remove('tcode_${tcode}_min');
      _manualErrors.remove('tcode_${tcode}_max');
      _manualErrors.remove('tcode_${tcode}_pending');
    }
    notifyListeners();
  }

  // Drawer mode
  String? drawerMode;

  bool get isReadOnly => drawerMode == 'hapus' || drawerMode == 'blokir' || drawerMode == 'unblokir' || drawerMode == 'resetPassword';
  bool get isFormMode => drawerMode == 'tambah' || drawerMode == 'edit';

  Color get tombolColor {
    return colorPrimary;
  }

  String get drawerTitle {
    switch (drawerMode) {
      case 'tambah': return 'Tambah Data Petugas';
      case 'edit': return 'Edit Data Petugas';
      case 'hapus': return 'Hapus Data Petugas';
      case 'blokir': return 'Blokir Petugas';
      case 'unblokir': return 'Unblokir Petugas';
      case 'resetPassword': return 'Reset Password Petugas';
      default: return '';
    }
  }

  String get tombolUtama {
    switch (drawerMode) {
      case 'hapus': return 'Proses';
      case 'blokir': return 'Proses';
      case 'unblokir': return 'Proses';
      case 'resetPassword': return 'Reset';
      default: return 'Simpan';
    }
  }

  UsersModel? _sessionUser;

  // ==================== MAPPING KANTOR ====================
  String getNamaKantor(String? kdKantor) {
    if (kdKantor == null || kdKantor.isEmpty) return '-';
    final found = _listKantor.firstWhere(
      (k) => k.kdKantor == kdKantor,
      orElse: () => KantorDummy('', '', ''),
    );
    return found.namaKantor.isEmpty ? kdKantor : found.namaKantor;
  }

  int get jumlahAktif => _filteredList.where((p) => DataPetugasStsrec.isAktif(p)).length;
  int get jumlahTidakAktif => _filteredList.length - jumlahAktif;

  // ==================== INIT ====================
  Future<void> _init() async {
    _sessionUser = await Pref().getUsers();
    await _loadData();
  }

  // ==================== LOAD DATA ====================
  Future<void> _loadData() async {
    isLoading = true;
    notifyListeners();

    await _loadKantor();
    await refreshList();

    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadKantor() async {
    try {
      final session = await Pref().getUsers();
      final kantorResult = await UsersAccessRepository.getListKantor(
        url: NetworkURL.getListKantorAccess(),
        userId: session.usersId,
        bprId: session.bprId,
      );
      if (kantorResult['value'] == 1) {
        final List<dynamic> kantorData = kantorResult['kantor'] ?? [];
        _listKantor = kantorData.map((k) {
          final m = k as Map<String, dynamic>;
          return KantorDummy(
            (m['kd_kantor'] ?? m['kdkantor'] ?? '').toString(),
            (m['nama_kantor'] ?? m['namakantor'] ?? '').toString(),
            session.bprId,
          );
        }).toList();
      }
    } catch (_) {}
  }

  Future<void> refreshList() async {
    final result = await CollectorRepository.inquiryCollector(
      filterNama: _searchKeyword.isNotEmpty ? _searchKeyword : null,
    );
    if (kDebugMode) {
      print('=== INQUIRY COLLECTOR RESPONSE ===');
      print('value: ${result['value']}');
      print('data length: ${result['data']?.length}');
    }
    if (result['value'] == 1) {
      final List<dynamic> data = result['data'] ?? [];
      final allList = data.map((item) => DataPetugasModel.fromJson(item as Map<String, dynamic>)).toList();
      _buildUserIdLookupFromEnrichedList(allList);
      _list = UserLevelHelper.applyKantorFilter(
        list: allList,
        users: _sessionUser,
        getKdKantor: (p) => p.kdKantor,
      );
      _applyFilter();
    }
  }

  void _applyFilter() {
    final kw = _searchKeyword.trim().toLowerCase();
    if (kw.isEmpty) {
      _filteredList = List.from(_list);
    } else {
      _filteredList = _list.where((p) {
        return (p.nama ?? '').toLowerCase().contains(kw) ||
               (p.nip ?? '').toLowerCase().contains(kw) ||
               (p.kodePetugas ?? '').toLowerCase().contains(kw);
      }).toList();
    }
    const _statusOrder = {'aktif': 0, 'blokir': 1};
    _filteredList.sort((a, b) {
      final sa = _statusOrder[DataPetugasStsrec.code(a)] ?? 9;
      final sb = _statusOrder[DataPetugasStsrec.code(b)] ?? 9;
      if (sa != sb) return sa.compareTo(sb);
      return (a.nama ?? '').toLowerCase().compareTo((b.nama ?? '').toLowerCase());
    });
    notifyListeners();
  }

  void onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchKeyword = value;
      _applyFilter();
    });
  }

  // ==================== FUNGSI UTAMA ====================
  void tambahPetugas() {
    _resetForm();
    drawerMode = 'tambah';
    scaffoldKey.currentState?.openEndDrawer();
    notifyListeners();
    _loadTcodeAksesAktif();
  }

  void openDrawerForAction(DataPetugasModel petugas) {
    selectedPetugas = petugas;
    _isiForm(petugas);
    drawerMode = 'aksi';
    scaffoldKey.currentState?.openEndDrawer();
    notifyListeners();
  }

  void _resetForm() {
    selectedPetugas = null;
    selectedKantor = null;
    _manualErrors.clear();
    userIdCtrl.clear();
    namaCtrl.clear();
    noHpCtrl.clear();
    nipCtrl.clear();
    passwordCtrl.clear();
    kodePetugasCtrl.clear();
    noSbbCtrl.clear();
    namaSbbCtrl.clear();
    alasanCtrl.clear();
    
    limitSetorMinCtrl.text = '0';
    limitSetorMaxCtrl.text = '0';
    limitSetorPendingCtrl.text = '0';
    limitTarikMinCtrl.text = '0';
    limitTarikMaxCtrl.text = '0';
    limitTarikPendingCtrl.text = '0';
    limitTransferMinCtrl.text = '0';
    limitTransferMaxCtrl.text = '0';
    limitTransferPendingCtrl.text = '0';
    limitPpobMinCtrl.text = '0';
    limitPpobMaxCtrl.text = '0';
    limitPpobPendingCtrl.text = '0';
    limitKreditMinCtrl.text = '0';
    limitKreditMaxCtrl.text = '0';
    limitKreditPendingCtrl.text = '0';
    
    aksesSetor = false;
    aksesTarik = false;
    aksesTransfer = false;
    aksesPpob = false;
    aksesKredit = false;
    enableLimitSetor = false;
    enableLimitTarik = false;
    enableLimitTransfer = false;
    enableLimitPpob = false;
    enableLimitKredit = false;
    isChangePassword = false;
    
    notifyListeners();
  }

  void _isiForm(DataPetugasModel p) {
    userIdCtrl.text = p.userId ?? '';
    namaCtrl.text = p.nama ?? '';
    noHpCtrl.text = p.noHp ?? '';
    nipCtrl.text = p.nip ?? '';
    kodePetugasCtrl.text = p.kodePetugas ?? '';
    noSbbCtrl.text = p.noSbb ?? '';
    namaSbbCtrl.text = p.namaSbb ?? '';
    passwordCtrl.clear();
    
    aksesSetor = p.aksesSetor;
    aksesTarik = p.aksesTarik;
    aksesTransfer = p.aksesTransfer;
    aksesPpob = p.aksesPpob;
    aksesKredit = p.aksesKredit;
    
    if (aksesSetor) {
      limitSetorMinCtrl.text = _fmtCtrl(p.limitSetorMin);
      limitSetorMaxCtrl.text = _fmtCtrl(p.limitSetorMax);
      limitSetorPendingCtrl.text = _fmtCtrl(p.limitSetorPending);
    } else {
      limitSetorMinCtrl.text = '0';
      limitSetorMaxCtrl.text = '0';
      limitSetorPendingCtrl.text = '0';
    }
    
    if (aksesTarik) {
      limitTarikMinCtrl.text = _fmtCtrl(p.limitTarikMin);
      limitTarikMaxCtrl.text = _fmtCtrl(p.limitTarikMax);
      limitTarikPendingCtrl.text = _fmtCtrl(p.limitTarikPending);
    } else {
      limitTarikMinCtrl.text = '0';
      limitTarikMaxCtrl.text = '0';
      limitTarikPendingCtrl.text = '0';
    }
    
    if (aksesTransfer) {
      limitTransferMinCtrl.text = _fmtCtrl(p.limitTransferMin);
      limitTransferMaxCtrl.text = _fmtCtrl(p.limitTransferMax);
      limitTransferPendingCtrl.text = _fmtCtrl(p.limitTransferPending);
    } else {
      limitTransferMinCtrl.text = '0';
      limitTransferMaxCtrl.text = '0';
      limitTransferPendingCtrl.text = '0';
    }
    
    if (aksesPpob) {
      limitPpobMinCtrl.text = _fmtCtrl(p.limitPpobMin);
      limitPpobMaxCtrl.text = _fmtCtrl(p.limitPpobMax);
      limitPpobPendingCtrl.text = _fmtCtrl(p.limitPpobPending);
    } else {
      limitPpobMinCtrl.text = '0';
      limitPpobMaxCtrl.text = '0';
      limitPpobPendingCtrl.text = '0';
    }
    
    if (aksesKredit) {
      limitKreditMinCtrl.text = _fmtCtrl(p.limitKreditMin);
      limitKreditMaxCtrl.text = _fmtCtrl(p.limitKreditMax);
      limitKreditPendingCtrl.text = _fmtCtrl(p.limitKreditPending);
    } else {
      limitKreditMinCtrl.text = '0';
      limitKreditMaxCtrl.text = '0';
      limitKreditPendingCtrl.text = '0';
    }
    
    enableLimitSetor = aksesSetor;
    enableLimitTarik = aksesTarik;
    enableLimitTransfer = aksesTransfer;
    enableLimitPpob = aksesPpob;
    enableLimitKredit = aksesKredit;
    isChangePassword = false;

    try {
      selectedKantor = _listKantor.firstWhere((k) => k.kdKantor == p.kdKantor);
    } catch (_) {
      selectedKantor = _listKantor.isNotEmpty ? _listKantor.first : null;
    }
    notifyListeners();
  }

  void pilihAksi(String mode) {
    if (selectedPetugas != null) {
      _isiForm(selectedPetugas!);
    }
    drawerMode = mode;
    notifyListeners();
    if (mode == 'edit') {
      _loadTcodeAksesAktif();
    }
  }

  void closeDrawer() {
    drawerMode = null;
    scaffoldKey.currentState?.closeEndDrawer();
    _resetForm();
    _disposeTcodeAksesControllers();
    tcodeAksesList = [];
    notifyListeners();
  }

  void goBackToActionMenu() {
    drawerMode = 'aksi';
    if (selectedPetugas != null) {
      _isiForm(selectedPetugas!);
    }
    notifyListeners();
  }

  void toggleChangePassword(bool? value) {
    isChangePassword = value ?? false;
    if (!isChangePassword) {
      passwordCtrl.clear();
      if (_manualErrors.containsKey('password')) {
        _manualErrors.remove('password');
        notifyListeners();
      }
    }
    notifyListeners();
  }

  void toggleObscure() {
    obscure = !obscure;
    notifyListeners();
  }

  // ==================== MANUAL VALIDATION ====================
  bool validateAllFieldsManually() {
    bool allValid = true;
    final errors = <String, String>{};
    
    final isTambah = drawerMode == 'tambah';
    final isEdit = drawerMode == 'edit';
    
    if (isTambah) {
      final userIdError = _validateUserIdManual(userIdCtrl.text.trim());
      if (userIdError != null) {
        errors['userId'] = userIdError;
        allValid = false;
      }
    }
    
    if (isTambah || isEdit) {
      final namaError = _validateNamaManual(namaCtrl.text.trim());
      if (namaError != null) {
        errors['nama'] = namaError;
        allValid = false;
      }
    }
    
    if (isTambah) {
      final passError = _validatePasswordManual(passwordCtrl.text.trim(), true);
      if (passError != null) {
        errors['password'] = passError;
        allValid = false;
      }
    }
    
    if (isTambah || isEdit) {
      final noHpError = _validateNoHpManual(noHpCtrl.text.trim());
      if (noHpError != null) {
        errors['noHp'] = noHpError;
        allValid = false;
      }
    }
    
    if (isTambah || isEdit) {
      final nipError = _validateNipManual(nipCtrl.text.trim());
      if (nipError != null) {
        errors['nip'] = nipError;
        allValid = false;
      }
    }
    
    if (isTambah || isEdit) {
      final kodeError = _validateKodePetugasManual(kodePetugasCtrl.text.trim());
      if (kodeError != null) {
        errors['kodePetugas'] = kodeError;
        allValid = false;
      }
    }
    
    if (isTambah || isEdit) {
      final noSbbError = _validateNoSbbManual(noSbbCtrl.text.trim());
      if (noSbbError != null) {
        errors['noSbb'] = noSbbError;
        allValid = false;
      }
    }
    
    if (isTambah || isEdit) {
      final namaSbbError = _validateNamaSbbManual(namaSbbCtrl.text.trim());
      if (namaSbbError != null) {
        errors['namaSbb'] = namaSbbError;
        allValid = false;
      }
    }
    
    if (isTambah || isEdit) {
      if (selectedKantor == null) {
        errors['kantor'] = 'Pilih kantor terlebih dahulu';
        allValid = false;
      }
    }
    
    if (isTambah || isEdit) {
      if (isLoadingTcodeAkses) {
        errors['akses'] = 'Data tcode masih dimuat, tunggu sebentar';
        allValid = false;
      }
      // FIX: sertakan tcode dinamis (tcodeAksesList) dalam pengecekan akses,
      // karena UI sudah beralih ke tcode — aksesSetor/aksesTarik dll tidak lagi dicentang user.
      final anyAkses = aksesSetor || aksesTarik || aksesTransfer || aksesPpob || aksesKredit
          || tcodeAksesList.any((item) => item['checked'] == true);
      if (!anyAkses) {
        errors['akses'] = 'Pilih minimal 1 akses transaksi';
        allValid = false;
      }
    }

    // FIX: validasi limit lama (aksesSetor/aksesTarik/dll) dinonaktifkan karena
    // UI sudah beralih ke tcode dinamis (tcodeAksesList). Field limit lama
    // (limitSetorMinCtrl dll) tidak ditampilkan di UI, nilainya selalu 0,
    // sehingga _validateLimitFields selalu gagal dan menghalangi proses simpan.
    // Validasi limit kini hanya berlaku untuk tcode dinamis (blok di bawah).

    // Akses transaksi per-tcode (dinamis) — Min gak boleh lebih besar dari Max,
    // tapi cuma divalidasi kalau aksesnya aktif/dicentang. Beda sama
    // _validateLimitFields yang mewajibkan non-zero, di sini 0 itu valid
    // (artinya "tanpa limit"), cuma urutan min<=max yang dicek.
    for (final item in tcodeAksesList) {
      if (item['checked'] != true) continue;
      final tcode = item['tcode']?.toString() ?? '';
      final minCtrl = item['minCtrl'] as TextEditingController;
      final maxCtrl = item['maxCtrl'] as TextEditingController;
      final minStr = minCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      final maxStr = maxCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      final minVal = int.tryParse(minStr) ?? 0;
      final maxVal = int.tryParse(maxStr) ?? 0;
      if (maxVal > 0 && minVal > maxVal) {
        errors['tcode_${tcode}_max'] = 'Min tidak boleh lebih besar dari Max';
        allValid = false;
      }
    }
    
    _manualErrors = errors;
    notifyListeners();
    
    return allValid;
  }

  bool _validateLimitFields(String prefix, TextEditingController minCtrl, TextEditingController maxCtrl, TextEditingController pendingCtrl, Map<String, String> errors) {
    bool valid = true;
    final minStr = minCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final maxStr = maxCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    
    final minVal = int.tryParse(minStr) ?? 0;
    final maxVal = int.tryParse(maxStr) ?? 0;
    
    if (minVal == 0) {
      errors['${prefix}_min'] = 'Min tidak boleh 0';
      valid = false;
    }
    if (maxVal == 0) {
      errors['${prefix}_max'] = 'Max tidak boleh 0';
      valid = false;
    }
    if (maxVal > 0 && minVal > maxVal) {
      errors['${prefix}_max'] = 'Max tidak boleh lebih kecil dari Min';
      valid = false;
    }
    return valid;
  }

  String? _validateUserIdManual(String value) {
    if (value.isEmpty) return 'User ID wajib diisi';
    if (RegExp(r'\s').hasMatch(value)) return 'User ID tidak boleh mengandung spasi';
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) return 'User ID harus mengandung huruf';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'User ID harus mengandung angka';
    if (_list.any((p) => p.userId?.toUpperCase() == value.toUpperCase())) {
      return 'User ID sudah terdaftar';
    }
    return null;
  }

  String? _validateNamaManual(String value) {
    if (value.isEmpty) return 'Nama wajib diisi';
    if (RegExp(r'[!@#\$%^&*()_+={}\[\]|\\:;"<>,.?/~`]').hasMatch(value)) {
      return 'Nama tidak boleh mengandung karakter spesial';
    }
    return null;
  }

  String? _validatePasswordManual(String value, bool isRequired) {
    if (isRequired && value.isEmpty) return 'Password wajib diisi';
    if (value.isNotEmpty && value.length < 6) return 'Minimal 6 karakter';
    return null;
  }

  String? _validateNoHpManual(String value) {
    if (value.isEmpty) return 'No HP wajib diisi';
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return 'No HP hanya boleh berisi angka';
    if (!value.startsWith('08')) return 'No HP harus diawali dengan 08';
    if (value.length < 10) return 'No HP minimal 10 digit';
    if (value.length > 14) return 'No HP maksimal 14 digit';
    return null;
  }

  String? _validateNipManual(String value) {
    if (value.isEmpty) return 'NIP wajib diisi';
    return null;
  }

  String? _validateKodePetugasManual(String value) {
    if (value.isEmpty) return 'Kode petugas wajib diisi';
    if (RegExp(r'\s').hasMatch(value)) return 'Kode tidak boleh mengandung spasi';
    return null;
  }

  String? _validateNoSbbManual(String value) {
    if (value.isEmpty) return 'No SBB wajib diisi';
    return null;
  }

  String? _validateNamaSbbManual(String value) {
    if (value.isEmpty) {
      return 'Nama SBB wajib diisi. Silakan klik tombol Cari untuk verifikasi No SBB terlebih dahulu';
    }
    return null;
  }

  // ==================== VERIFIKASI SBB ====================
  Future<void> verifikasiNoSbb() async {
    final sbb = noSbbCtrl.text.trim();
    if (sbb.isEmpty) {
      _showErrorDialog('Masukkan No SBB terlebih dahulu');
      return;
    }

    isLoadingVerifikasi = true;
    notifyListeners();

    final result = await CollectorRepository.inquirySbbByAccount(noRek: sbb);
    
    if (kDebugMode) {
      print('=== VERIFIKASI SBB ===');
      print('No SBB input: $sbb');
      print('Result value: ${result['value']}');
      print('Result namaSbb: ${result['namaSbb']}');
    }
    
    final resultValue = result['value'];
    final namaSbb = result['namaSbb']?.toString() ?? '';
    final noSbbResult = result['noSbb']?.toString() ?? sbb;
    final stsrecResult = result['stsrec']?.toString() ?? 'AKTIF';
    final messageError = result['message']?.toString() ?? 'No SBB tidak ditemukan';
    
    if (resultValue == 1) {
      if (namaSbb.isEmpty) {
        namaSbbCtrl.clear();
        _showErrorDialog(
          result['message']?.toString() ?? 'No SBB ditemukan namun nama tidak tersedia.\nSilakan periksa kembali data SBB.',
        );
      } else {
        namaSbbCtrl.text = namaSbb;
        if (_manualErrors.containsKey('namaSbb')) {
          _manualErrors.remove('namaSbb');
        }
        if (_manualErrors.containsKey('noSbb')) {
          _manualErrors.remove('noSbb');
        }
        _showSbbFoundDialog(
          namaSbb: namaSbb,
          noSbb: noSbbResult,
          stsrec: stsrecResult,
        );
        notifyListeners();
      }
    } else {
      namaSbbCtrl.clear();
      _showErrorDialog(messageError);
    }

    isLoadingVerifikasi = false;
    notifyListeners();
  }

  // ==================== DIALOG ====================
  void _showSbbFoundDialog({required String namaSbb, required String noSbb, required String stsrec}) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                color: colorPrimary,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SBB ditemukan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.75),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      namaSbb,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No. SBB',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                noSbb,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              stsrec.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Proses',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
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
  }

  void _showSuccessDialog(String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PetugasResultDialog(isSuccess: true, message: message),
    );
  }

  void _showErrorDialog(String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PetugasResultDialog(isSuccess: false, message: message),
    );
  }

  void _showInDevelopmentDialog() {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
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
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.construction,
                  size: 40,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Fitur Dalam Pengembangan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fitur reset password sedang dalam tahap pengembangan.\nMohon maaf atas ketidaknyamanannya.',
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
                  onPressed: () {
                    Navigator.pop(_);
                    closeDrawer();
                  },
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showInsertConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: colorPrimary,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Konfirmasi Tambah Data',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 2),
                        Text('Data Petugas',
                            style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Periksa kembali data petugas yang akan ditambahkan:',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 14),
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
                          _konfirmasiRow('User ID', userIdCtrl.text.trim()),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Nama', namaCtrl.text.trim()),
                          const SizedBox(height: 6),
                          _konfirmasiRow('No HP', noHpCtrl.text.trim()),
                          const SizedBox(height: 6),
                          _konfirmasiRow('NIP', nipCtrl.text.trim()),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Kode Petugas', kodePetugasCtrl.text.trim()),
                          const SizedBox(height: 6),
                          _konfirmasiRow('No SBB', noSbbCtrl.text.trim()),
                          const SizedBox(height: 6),
                          _konfirmasiRow('Kantor', selectedKantor?.namaKantor ?? '-'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: colorError,
                            foregroundColor: colortextwhite,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorPrimary,
                            foregroundColor: colortextwhite,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Future<String?> showAlasanDialog() async {
    final aksiLabel = drawerMode == 'hapus' ? 'Hapus'
        : drawerMode == 'blokir' ? 'Blokir'
        : drawerMode == 'unblokir' ? 'Unblokir'
        : 'Aksi';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        String? errorText;
        final alasanLocalCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setStateDialog) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_aksiIcon(), color: tombolColor, size: 22),
                    const SizedBox(width: 10),
                    Text('Alasan $aksiLabel',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Masukkan alasan untuk melakukan $aksiLabel pada petugas ini.',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: alasanLocalCtrl,
                    maxLines: 3,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Tulis alasan di sini...',
                      errorText: errorText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    onChanged: (_) {
                      if (errorText != null) setStateDialog(() => errorText = null);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colortextwhite,
                          backgroundColor: colorcancel,
                          side: const BorderSide(color: Colors.transparent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(ctx, null),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorPrimary,
                          foregroundColor: colortextwhite,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          if (alasanLocalCtrl.text.trim().isEmpty) {
                            setStateDialog(() => errorText = 'Alasan wajib diisi');
                          } else {
                            Navigator.pop(ctx, alasanLocalCtrl.text.trim());
                          }
                        },
                        child: const Text('Proses'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> showKonfirmasiDialog(String alasan) async {
    final aksiLabel = drawerMode == 'hapus' ? 'menghapus'
        : drawerMode == 'blokir' ? 'memblokir'
        : drawerMode == 'unblokir' ? 'meng-unblokir'
        : drawerMode == 'edit' ? 'mengubah'
        : 'melakukan aksi pada';
    
    final isEditMode = drawerMode == 'edit';
    final changes = isEditMode ? _getChangesForEdit() : {};
    
    if (isEditMode && changes.isEmpty && !isChangePassword) {
      _showErrorDialog('Tidak ada perubahan data yang disimpan');
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: tombolColor,
                child: Row(
                  children: [
                    Icon(_aksiIcon(), color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditMode ? 'Konfirmasi Perubahan' : 'Konfirmasi',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        const Text('Data Petugas', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditMode
                          ? 'Periksa kembali perubahan data petugas berikut:'
                          : 'Apakah Anda yakin ingin $aksiLabel petugas ini?',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),

                    if (isEditMode && changes.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 350),
                        child: SingleChildScrollView(
                          child: Column(
                            children: changes.entries.map((entry) {
                              final label = entry.key;
                              final oldVal = entry.value['old'] ?? '-';
                              final newVal = entry.value['new'] ?? '-';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF8FAF9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xffDCE3DF)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(label,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Sebelum',
                                                  style: TextStyle(fontSize: 10, color: Colors.grey)),
                                              const SizedBox(height: 4),
                                              Text(oldVal,
                                                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Icon(Icons.arrow_forward, size: 20, color: colorPrimary),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Sesudah',
                                                  style: TextStyle(fontSize: 10, color: Colors.grey)),
                                              const SizedBox(height: 4),
                                              Text(newVal,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorPrimary)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                    if (!isEditMode)
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
                            _konfirmasiRow('Nama', selectedPetugas?.nama ?? '-'),
                            const SizedBox(height: 6),
                            _konfirmasiRow('NIP', selectedPetugas?.nip ?? '-'),
                            const SizedBox(height: 6),
                            _konfirmasiRow('No SBB', selectedPetugas?.noSbb ?? '-'),
                            const SizedBox(height: 6),
                            _konfirmasiRow('Status', DataPetugasStsrec.statusFor(selectedPetugas)),
                            if (alasan.isNotEmpty) ...[
                              const Divider(height: 16),
                              _konfirmasiRow('Alasan', alasan),
                            ],
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colortextwhite,
                            backgroundColor: colorError,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorPrimary,
                            foregroundColor: colortextwhite,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(isEditMode ? 'Simpan' : 'Proses', style: const TextStyle(fontWeight: FontWeight.w600)),
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

  IconData _aksiIcon() {
    if (drawerMode == 'hapus') return Icons.delete_outline;
    if (drawerMode == 'blokir') return Icons.block;
    if (drawerMode == 'unblokir') return Icons.lock_open;
    if (drawerMode == 'resetPassword') return Icons.lock_reset;
    return Icons.info_outline;
  }

  Map<String, Map<String, String>> _getChangesForEdit() {
    final changes = <String, Map<String, String>>{};
    
    if (selectedPetugas == null) return changes;
    
    final old = selectedPetugas!;
    
    _addChange(changes, 'Nama', old.nama, namaCtrl.text.trim());
    _addChange(changes, 'No HP', old.noHp, noHpCtrl.text.trim());
    _addChange(changes, 'NIP', old.nip, nipCtrl.text.trim());
    _addChange(changes, 'Kode Petugas', old.kodePetugas, kodePetugasCtrl.text.trim());
    _addChange(changes, 'No SBB', old.noSbb, noSbbCtrl.text.trim());
    _addChange(changes, 'Nama SBB', old.namaSbb, namaSbbCtrl.text.trim());

    final oldKantor = getNamaKantor(old.kdKantor);
    final newKantor = selectedKantor?.namaKantor ?? '-';
    if (oldKantor != newKantor) {
      changes['Kantor'] = {'old': oldKantor, 'new': newKantor};
    }
    
    _addBoolChange(changes, 'Akses Setor', old.aksesSetor, aksesSetor);
    _addBoolChange(changes, 'Akses Tarik', old.aksesTarik, aksesTarik);
    _addBoolChange(changes, 'Akses Transfer', old.aksesTransfer, aksesTransfer);
    _addBoolChange(changes, 'Akses PPOB', old.aksesPpob, aksesPpob);
    _addBoolChange(changes, 'Akses Kredit', old.aksesKredit, aksesKredit);
    
    if (isChangePassword && passwordCtrl.text.trim().isNotEmpty) {
      changes['Password'] = {'old': '********', 'new': '******** (diubah)'};
    }

    // Akses & limit per-tcode (dinamis) — sebelumnya gak pernah dicek sama
    // sekali di sini, makanya kalau yang diubah cuma ini, popup bilang
    // "Tidak ada perubahan" padahal datanya beneran berubah & disimpan
    // lewat _saveTcodeAksesLimit().
    for (final item in tcodeAksesList) {
      final tcode = item['tcode']?.toString() ?? '';
      final keterangan = item['keterangan']?.toString() ?? tcode;
      final checked = item['checked'] == true;
      final origChecked = item['origChecked'] == true;
      final minVal = (item['minCtrl'] as TextEditingController).text.trim();
      final maxVal = (item['maxCtrl'] as TextEditingController).text.trim();
      final pendingVal = (item['pendingCtrl'] as TextEditingController).text.trim();
      final origMin = (item['origMin'] ?? '0').toString();
      final origMax = (item['origMax'] ?? '0').toString();
      final origPending = (item['origPending'] ?? '0').toString();

      if (checked != origChecked) {
        changes['Akses $keterangan ($tcode)'] = {
          'old': origChecked ? 'Aktif' : 'Tidak Aktif',
          'new': checked ? 'Aktif' : 'Tidak Aktif',
        };
      }
      if (minVal != origMin) {
        changes['Min $keterangan ($tcode)'] = {'old': origMin, 'new': minVal.isEmpty ? '0' : minVal};
      }
      if (maxVal != origMax) {
        changes['Max $keterangan ($tcode)'] = {'old': origMax, 'new': maxVal.isEmpty ? '0' : maxVal};
      }
      if (pendingVal != origPending) {
        changes['Pending $keterangan ($tcode)'] = {'old': origPending, 'new': pendingVal.isEmpty ? '0' : pendingVal};
      }
    }
    
    return changes;
  }

  void _addChange(Map<String, Map<String, String>> changes, String label, String? oldValue, String newValue) {
    final oldStr = oldValue?.toString() ?? '-';
    final newStr = newValue.trim().isEmpty ? '-' : newValue.trim();
    if (oldStr != newStr) {
      changes[label] = {'old': oldStr, 'new': newStr};
    }
  }

  void _addBoolChange(Map<String, Map<String, String>> changes, String label, bool oldValue, bool newValue) {
    if (oldValue != newValue) {
      changes[label] = {
        'old': oldValue ? 'Ya' : 'Tidak',
        'new': newValue ? 'Ya' : 'Tidak',
      };
    }
  }

  // ==================== EXECUTE ACTION ====================
  Future<void> executeAction() async {
    if (drawerMode == 'tambah') {
      if (!validateAllFieldsManually()) return;
      final confirmed = await _showInsertConfirmDialog();
      if (!confirmed) return;
      await _konfirmasiAksi();
      return;
    }
    
    if (drawerMode == 'edit') {
      if (!validateAllFieldsManually()) return;
      final confirmed = await showKonfirmasiDialog('');
      if (!confirmed) return;
      await _konfirmasiAksi();
      return;
    }
    
    // RESET PASSWORD
    if (drawerMode == 'resetPassword') {
      isSaving = true;
      notifyListeners();

      final resolvedUserId = await _resolvePetugasUserIdAsync();
      final result = await CollectorRepository.resetPasswordCollector(
        userId: resolvedUserId.isNotEmpty ? resolvedUserId : null,
        noHp: selectedPetugas?.noHp ?? noHpCtrl.text.trim(),
        backendId: selectedPetugas?.id,
      );

      isSaving = false;
      notifyListeners();

      if (result['value'] == 1) {
        closeDrawer();
        await _loadData();
        _showSuccessDialog('Reset password petugas berhasil!');
      } else {
        _showErrorDialog(result['message']?.toString() ?? 'Terjadi kesalahan');
      }
      return;
    }

    final alasan = await showAlasanDialog();
    if (alasan == null) return;
    alasanCtrl.text = alasan;

    final confirmed = await showKonfirmasiDialog(alasan);
    if (confirmed) await _konfirmasiAksi();
  }

  Future<void> _konfirmasiAksi() async {
    isSaving = true;
    notifyListeners();

    final middlewarePayload = _buildMiddlewarePayloadFromTcode();
    final limitData = middlewarePayload.limitData;
    final aksesData = middlewarePayload.aksesData;

    Map<String, dynamic> result = {};
    Map<String, dynamic>? limitResult;

    switch (drawerMode) {
      case 'tambah':
        result = await CollectorRepository.insertCollector(
          userId: userIdCtrl.text.trim(),
          password: passwordCtrl.text.trim(),
          nama: namaCtrl.text.trim(),
          noHp: noHpCtrl.text.trim(),
          nip: nipCtrl.text.trim(),
          kdKantor: selectedKantor?.kdKantor ?? '',
          kodePetugas: kodePetugasCtrl.text.trim(),
          noSbb: noSbbCtrl.text.trim(),
          namaSbb: namaSbbCtrl.text.trim(),
          limitData: limitData,
          aksesData: aksesData,
        );
        if (result['value'] == 1 && tcodeAksesList.isNotEmpty) {
          limitResult = await _saveTcodeAksesLimit();
        }
        break;
      case 'edit':
        final editUserId = await _resolvePetugasUserIdAsync();
        result = await CollectorRepository.updateCollector(
          id: selectedPetugas?.id ?? '',
          userId: editUserId,
          nama: namaCtrl.text.trim(),
          noHp: noHpCtrl.text.trim(),
          nip: nipCtrl.text.trim(),
          kdKantor: selectedKantor?.kdKantor ?? selectedPetugas?.kdKantor ?? '',
          kodePetugas: kodePetugasCtrl.text.trim(),
          noSbb: noSbbCtrl.text.trim(),
          namaSbb: namaSbbCtrl.text.trim(),
          password: isChangePassword ? passwordCtrl.text.trim() : null,
          limitData: limitData,
          aksesData: aksesData,
        );
        if (result['value'] == 1 && tcodeAksesList.isNotEmpty) {
          limitResult = await _saveTcodeAksesLimit();
        }
        break;
      case 'hapus':
        result = await CollectorRepository.deleteCollector(
          id: selectedPetugas?.id ?? '',
          alasan: alasanCtrl.text.trim(),
        );
        break;
      case 'blokir':
        result = await CollectorRepository.blokirCollector(
          id: selectedPetugas?.id ?? '',
          alasan: alasanCtrl.text.trim(),
          userLogin: '',
        );
        break;
      case 'unblokir':
        result = await CollectorRepository.unblokirCollector(
          id: selectedPetugas?.id ?? '',
          alasan: alasanCtrl.text.trim(),
          userLogin: '',
        );
        break;
      default:
        result = {'value': 0, 'message': 'Aksi tidak dikenal'};
    }

    isSaving = false;
    notifyListeners();

    if (result['value'] == 1 && limitResult != null && limitResult['value'] != 1) {
      _showErrorDialog(
        limitResult['message']?.toString().isNotEmpty == true
            ? limitResult['message'].toString()
            : 'Gagal menyimpan limit transaksi per-tcode',
      );
      return;
    }

    final errorMessage = result['message']?.toString() ?? 'Gagal melakukan operasi';
    
    if (result['value'] == 1) {
      final currentMode = drawerMode;
      closeDrawer();
      await refreshList();
      String msg = '';
      switch (currentMode) {
        case 'tambah': msg = 'Data petugas berhasil ditambahkan!'; break;
        case 'edit': msg = 'Data petugas berhasil diupdate!'; break;
        case 'hapus': msg = 'Data petugas berhasil dihapus!'; break;
        case 'blokir': msg = 'Petugas berhasil diblokir!'; break;
        case 'unblokir': msg = 'Petugas berhasil di-unblokir!'; break;
        default: msg = 'Operasi berhasil!';
      }
      _showSuccessDialog(msg);
    } else {
      _showErrorDialog(errorMessage);
    }
  }

  // ==================== TOGGLE AKSES ====================
  void toggleAksesSetor(bool? v) {
    aksesSetor = v ?? false;
    enableLimitSetor = aksesSetor;
    if (!aksesSetor) {
      limitSetorMinCtrl.text = '0';
      limitSetorMaxCtrl.text = '0';
      limitSetorPendingCtrl.text = '0';
      if (_manualErrors.containsKey('setor_min')) _manualErrors.remove('setor_min');
      if (_manualErrors.containsKey('setor_max')) _manualErrors.remove('setor_max');
    }
    notifyListeners();
  }

  void toggleAksesTarik(bool? v) {
    aksesTarik = v ?? false;
    enableLimitTarik = aksesTarik;
    if (!aksesTarik) {
      limitTarikMinCtrl.text = '0';
      limitTarikMaxCtrl.text = '0';
      limitTarikPendingCtrl.text = '0';
      if (_manualErrors.containsKey('tarik_min')) _manualErrors.remove('tarik_min');
      if (_manualErrors.containsKey('tarik_max')) _manualErrors.remove('tarik_max');
    }
    notifyListeners();
  }

  void toggleAksesTransfer(bool? v) {
    aksesTransfer = v ?? false;
    enableLimitTransfer = aksesTransfer;
    if (!aksesTransfer) {
      limitTransferMinCtrl.text = '0';
      limitTransferMaxCtrl.text = '0';
      limitTransferPendingCtrl.text = '0';
      if (_manualErrors.containsKey('transfer_min')) _manualErrors.remove('transfer_min');
      if (_manualErrors.containsKey('transfer_max')) _manualErrors.remove('transfer_max');
    }
    notifyListeners();
  }

  void toggleAksesPpob(bool? v) {
    aksesPpob = v ?? false;
    enableLimitPpob = aksesPpob;
    if (!aksesPpob) {
      limitPpobMinCtrl.text = '0';
      limitPpobMaxCtrl.text = '0';
      limitPpobPendingCtrl.text = '0';
      if (_manualErrors.containsKey('ppob_min')) _manualErrors.remove('ppob_min');
      if (_manualErrors.containsKey('ppob_max')) _manualErrors.remove('ppob_max');
    }
    notifyListeners();
  }

  void toggleAksesKredit(bool? v) {
    aksesKredit = v ?? false;
    enableLimitKredit = aksesKredit;
    if (!aksesKredit) {
      limitKreditMinCtrl.text = '0';
      limitKreditMaxCtrl.text = '0';
      limitKreditPendingCtrl.text = '0';
      if (_manualErrors.containsKey('kredit_min')) _manualErrors.remove('kredit_min');
      if (_manualErrors.containsKey('kredit_max')) _manualErrors.remove('kredit_max');
    }
    notifyListeners();
  }

  void setSelectedKantor(KantorDummy? kantor) {
    selectedKantor = kantor;
    if (kantor != null && _manualErrors.containsKey('kantor')) {
      _manualErrors.remove('kantor');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposeTcodeAksesControllers();
    _debounceTimer?.cancel();
    scrollController.dispose();
    searchCtrl.dispose();
    userIdCtrl.dispose();
    namaCtrl.dispose();
    noHpCtrl.dispose();
    nipCtrl.dispose();
    passwordCtrl.dispose();
    kodePetugasCtrl.dispose();
    noSbbCtrl.dispose();
    namaSbbCtrl.dispose();
    alasanCtrl.dispose();
    limitSetorMinCtrl.dispose();
    limitSetorMaxCtrl.dispose();
    limitSetorPendingCtrl.dispose();
    limitTarikMinCtrl.dispose();
    limitTarikMaxCtrl.dispose();
    limitTarikPendingCtrl.dispose();
    limitTransferMinCtrl.dispose();
    limitTransferMaxCtrl.dispose();
    limitTransferPendingCtrl.dispose();
    limitPpobMinCtrl.dispose();
    limitPpobMaxCtrl.dispose();
    limitPpobPendingCtrl.dispose();
    limitKreditMinCtrl.dispose();
    limitKreditMaxCtrl.dispose();
    limitKreditPendingCtrl.dispose();
    super.dispose();
  }
}

// ==================== RUPIAH FORMATTER ====================
class RupiahInputFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat('#,##0', 'id_ID');
  
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    final number = int.tryParse(raw) ?? 0;
    final formatted = _fmt.format(number);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }

  static String formatValue(String? raw) {
    if (raw == null || raw.isEmpty) return '0';
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '0';
    final number = int.tryParse(digits) ?? 0;
    if (number == 0) return '0';
    return _fmt.format(number);
  }
}

// ==================== RESULT DIALOG ====================
class _PetugasResultDialog extends StatelessWidget {
  final bool isSuccess;
  final String message;

  const _PetugasResultDialog({required this.isSuccess, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D);
    final bgColor = isSuccess ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB);
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    final title = isSuccess ? 'Berhasil' : 'Gagal';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}