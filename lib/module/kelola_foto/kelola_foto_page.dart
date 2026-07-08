import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../../utils/colors.dart';
import '../../utils/button_custom.dart';
import '../../utils/widgets/app_data_grid.dart';
import '../../repository/kelola_foto_repository.dart';

/// ====================================================================
/// KELOLA FOTO — halaman kelola foto tanda tangan & KTP nasabah.
/// List & pencarian terhubung ke API `account_search`. Baris tampil di
/// tabel list kalau `foto_ktp_path` sudah terisi (foto_ttd_path boleh
/// kosong) — lihat _KelolaFotoNotifier.loadData/_applyFilter.
/// NOTE (FIXED): `account_search` tidak mengembalikan field cif
/// terpisah, jadi setiap baris hasil account_search di-resolve ULANG
/// lewat `inquiryAccount(noRek)` (endpoint yang sama dipakai di flow
/// "Cari No Rekening" pada Tambah Foto) untuk dapat `nocif` yang asli.
/// `cif` TIDAK LAGI dipetakan dari `no_rek` — lihat
/// _KelolaFotoNotifier._resolveCifFromNoRek.
/// Slot foto kedua tadinya "Selfie", sekarang jadi "Foto KTP" —
/// variabel internal (fotoSelfie/tambahSelfie/dst) masih pakai nama
/// lama sementara, cuma label yang user lihat yang sudah diubah.
/// Struktur & flow mengikuti mockup `kelola_foto_mockup_v2.html`.
/// ====================================================================

enum _ViewMode { list, form }

enum _FormMode { tambah, ubah }

enum _TambahStage { pilihNasabah, signature, selfie, done }

// ==================== MODEL (account_search) ====================
class _DummyNasabahFoto {
  final String nama;
  final String noRek;
  // NOTE (FIXED): account_search tidak punya field cif terpisah, jadi ini
  // TIDAK LAGI diisi dari no_rek. Nilai asli didapat belakangan lewat
  // inquiryAccount(noRek) — lihat _KelolaFotoNotifier._resolveCifFromNoRek.
  // Sengaja non-final supaya bisa diisi ulang setelah resolve tanpa perlu
  // rebuild seluruh objek.
  String cif;
  final String noIdentitas;
  final String noHp;
  final String tglLahir;
  final String kdKantor;
  final String bprId;
  final String status;

  // URL foto dari server (ktp/selfie), dipakai untuk preview.
  final String fhoto1;
  final String fhoto2;
  final String fhoto3;

  // Foto baru yang diambil/diupload user di flow tambah/ubah (belum
  // terhubung ke endpoint simpan — masih state lokal).
  Uint8List? fotoTtd;
  Uint8List? fotoSelfie;

  // Hasil cek ke nasabah-photo-bridge (action: inquiry): true kalau
  // nasabah ini sudah punya foto_ktp_path tersimpan di server (foto_ttd_path
  // boleh kosong). Dipakai untuk menentukan apakah baris ini tampil di
  // tabel list Kelola Foto (lihat _KelolaFotoNotifier.loadData/_applyFilter).
  bool hasFotoKtp = false;

  _DummyNasabahFoto({
    required this.nama,
    required this.noRek,
    required this.cif,
    required this.noIdentitas,
    required this.noHp,
    required this.tglLahir,
    this.kdKantor = '',
    this.bprId = '',
    this.status = '',
    this.fhoto1 = '',
    this.fhoto2 = '',
    this.fhoto3 = '',
    this.fotoTtd,
    this.fotoSelfie,
  });

  factory _DummyNasabahFoto.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => (v ?? '').toString();
    return _DummyNasabahFoto(
      nama: s(json['nama']).isNotEmpty ? s(json['nama']) : s(json['nama_rek']),
      noRek: s(json['no_rek']),
      // Kosong dulu — diisi belakangan lewat _resolveCifFromNoRek setelah
      // lookup ke inquiryAccount(noRek). BUKAN no_rek lagi (lihat NOTE di atas).
      cif: '',
      noIdentitas: s(json['no_ktp']),
      noHp: s(json['no_hp']),
      tglLahir: _formatTglLahir(s(json['tgl_lahir'])),
      kdKantor: s(json['kd_kantor']),
      bprId: s(json['bpr_id']),
      status: s(json['status']),
      fhoto1: s(json['fhoto_1']),
      fhoto2: s(json['fhoto_2']),
      fhoto3: s(json['fhoto_3']),
    );
  }

  // Dari response inquiry_account (dipakai di flow Tambah Foto). Endpoint
  // ini punya field `nocif` sendiri (beda dari account_search yang belum
  // punya field cif terpisah) — jadi di sini cif diambil dari `nocif`.
  // `enrichFrom` opsional: dipakai buat isi no_hp/no_ktp/tgl_lahir dari
  // data account_search yang sudah ke-load duluan (kalau ada match by
  // no_rek), karena inquiry_account sendiri tidak mengembalikan field itu.
  factory _DummyNasabahFoto.fromInquiryAccount(
    Map<String, dynamic> json, {
    _DummyNasabahFoto? enrichFrom,
  }) {
    String s(dynamic v) => (v ?? '').toString();
    return _DummyNasabahFoto(
      nama: s(json['nama']),
      noRek: s(json['no_rek']),
      cif: s(json['nocif']),
      noIdentitas: enrichFrom?.noIdentitas ?? '',
      noHp: enrichFrom?.noHp ?? '',
      tglLahir: enrichFrom?.tglLahir ?? '-',
      kdKantor: s(json['kode_kantor']),
      bprId: s(json['bpr_id']),
      status: s(json['status_rek']),
      fhoto1: enrichFrom?.fhoto1 ?? '',
      fhoto2: enrichFrom?.fhoto2 ?? '',
      fhoto3: enrichFrom?.fhoto3 ?? '',
    );
  }

  static String _formatTglLahir(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(raw);
      return DateFormat('dd-MM-yyyy').format(parsed);
    } catch (_) {
      return raw;
    }
  }

  bool get sudahTtd => fotoTtd != null || fhoto1.isNotEmpty;
  bool get sudahSelfie => fotoSelfie != null || fhoto2.isNotEmpty;
}

// ==================== MODEL (nasabah-foto/inquiry) ====================
// List TERPISAH dari _DummyNasabahFoto (account_search) — sumber datanya
// endpoint baru $url_go3/cis/nasabah-foto/inquiry. Response asli pakai
// PascalCase (NoCIF, Nama) di dalam data.items — BUKAN snake_case seperti
// endpoint lain di project ini. Fallback ke snake_case tetap disediakan
// jaga-jaga kalau backend berubah suatu saat.
class _NasabahFotoItem {
  final String noCif;
  final String nama;

  _NasabahFotoItem({required this.noCif, required this.nama});

  factory _NasabahFotoItem.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => (v ?? '').toString();
    return _NasabahFotoItem(
      noCif: s(json['NoCIF'] ?? json['no_cif']),
      nama: s(json['Nama'] ?? json['nama']),
    );
  }
}

// ==================== NOTIFIER ====================
class _KelolaFotoNotifier extends ChangeNotifier {
  _KelolaFotoNotifier() {
    _initLoad();
  }

  // Urutan sengaja sequential (bukan Future.wait paralel):
  // 1. inquiry lama (account_search) dulu lewat loadData()
  // 2. baru inquiry baru (nasabah-foto/inquiry) & merge ke tabel yang sama
  // isLoading sengaja dipegang manual di sini (bukan dilepas ke loadData)
  // supaya tabel baru dirender kalau KEDUA tahap sudah selesai — user tidak
  // lagi melihat 5 data nongol duluan baru nambah jadi 7 beberapa saat
  // kemudian, cukup satu kali loading lalu langsung tampil lengkap.
  Future<void> _initLoad() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    await loadData(silent: true);
    await _mergeNasabahFoto();

    isLoading = false;
    notifyListeners();
  }

  // Ambil data dari nasabah-foto/inquiry (inquiry baru), lalu gabung ke
  // _list yang sudah ada dari account_search (inquiry lama) supaya cuma
  // ada SATU tabel. no_cif yang sudah ada di inquiry lama TIDAK dipakai
  // lagi dari inquiry baru (skip, hindari duplikat).
  Future<void> _mergeNasabahFoto() async {
    try {
      final result = await KelolaFotoRepository.nasabahFotoInquiry(
        search: '',
        page: 1,
        size: 100,
      );

      if (result['value'] != 1) {
        if (kDebugMode) {
          print('MERGE NASABAH FOTO: inquiry gagal/value=0, skip merge. '
              'message=${result['message']}');
        }
        return;
      }

      final rawList = (result['data'] as List?) ?? [];
      if (kDebugMode) {
        print('MERGE NASABAH FOTO: result[data].runtimeType='
            '${result['data'].runtimeType}, rawList (pre-filter) '
            'length=${rawList.length}');
      }
      // no_cif yang sudah ada dari inquiry lama.
      final existingCifs = _list.map((d) => d.cif).toSet();

      final newItems = rawList
          .whereType<Map>()
          .map((e) => _NasabahFotoItem.fromJson(Map<String, dynamic>.from(e)))
          .where((item) =>
              item.noCif.isNotEmpty && !existingCifs.contains(item.noCif))
          .map((item) => _DummyNasabahFoto(
                nama: item.nama,
                noRek: '',
                cif: item.noCif,
                noIdentitas: '',
                noHp: '',
                tglLahir: '-',
              ))
          .toList();

      if (kDebugMode) {
        print('MERGE NASABAH FOTO: existingCifs=$existingCifs');
        print('MERGE NASABAH FOTO: rawList.length=${rawList.length}, '
            'newItems.length=${newItems.length}');
      }

      if (newItems.isEmpty) return;

      _list.addAll(newItems);
      _applyFilter();
      notifyListeners();

      if (kDebugMode) {
        print('MERGE NASABAH FOTO: _list.length=${_list.length}, '
            '_filtered.length=${_filtered.length}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('ERROR MERGE NASABAH FOTO: $e');
        print(st);
      }
    }
  }

  final List<_DummyNasabahFoto> _list = [];
  List<_DummyNasabahFoto> get list => _list;

  List<_DummyNasabahFoto> _filtered = [];
  List<_DummyNasabahFoto> get filtered => _filtered;

  bool isLoading = false;
  String? errorMessage;

  final searchCtrl = TextEditingController();
  String _keyword = '';

  _ViewMode viewMode = _ViewMode.list;
  _FormMode? formMode;

  // ---------- Tambah state ----------
  _DummyNasabahFoto? tambahNasabah;
  _TambahStage tambahStage = _TambahStage.pilihNasabah;
  Uint8List? tambahSignature;
  Uint8List? tambahSelfie;
  final searchNasabahCtrl = TextEditingController();
  String searchNasabahKeyword = '';

  // No HP untuk flow Tambah Foto tidak lagi diisi manual — field-nya
  // dihapus dari form, request ke nasabahPhotoBridge selalu mengirim
  // placeholder '-' (lihat simpanTambah).

  // True selagi mengecek ke nasabah-photo-bridge (action: inquiry) apakah
  // nasabah yang baru dipilih di flow Tambah Foto sudah punya
  // foto_ktp_path tersimpan (lihat checkFotoKtpExisting).
  bool isCheckingFotoExisting = false;

  bool isSavingTambah = false;
  String? tambahSaveError;

  // ---------- Ubah state ----------
  _DummyNasabahFoto? ubahNasabah;
  Uint8List? ubahSignature;
  Uint8List? ubahSelfie;
  bool isLoadingUbahFoto = false;
  String? ubahFotoError;

  // Path asli dari server (hasil inquiry) — dipakai ulang kalau foto
  // yang bersangkutan TIDAK diganti user, supaya tidak perlu upload ulang.
  String? ubahSignaturePath;
  String? ubahSelfiePath;
  // True kalau user mengambil/memilih foto baru di slot itu (artinya path
  // lama sudah tidak valid lagi dan butuh upload ulang).
  bool ubahSignatureChanged = false;
  bool ubahSelfieChanged = false;

  bool isSavingUbah = false;
  String? simpanUbahError;

  final ImagePicker _picker = ImagePicker();

  // ---------- Load & search (account_search) ----------
  // Backend account_search tidak punya field keyword pencarian (lihat
  // catatan di KelolaFotoRepository.accountSearch) — jadi di sini kita
  // ambil daftar penuh dari server lalu filter sendiri di client
  // berdasarkan nama/CIF/no identitas/no HP.
  // `silent`: true kalau dipanggil dari _initLoad, yang sudah pegang
  // isLoading sendiri (biar tidak flicker jadi false sesaat sebelum
  // _mergeNasabahFoto lanjut jalan). Pemanggil lain (search/retry) tetap
  // pakai default false supaya spinner tampil normal per aksi mereka.
  Future<void> loadData({String term = '', bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }

    final result = await KelolaFotoRepository.accountSearch();

    if (result['value'] == 1) {
      final rawList = (result['data'] as List?) ?? [];
      _list
        ..clear()
        ..addAll(rawList
            .whereType<Map>()
            .map((e) => _DummyNasabahFoto.fromJson(Map<String, dynamic>.from(e))));

      // Resolve CIF asli per baris lewat inquiryAccount(noRek) — account_search
      // sendiri tidak punya field cif terpisah (lihat NOTE di _DummyNasabahFoto).
      // Dilakukan SEBELUM _applyFilter supaya pencarian by-CIF & tabel yang
      // ditampilkan sudah pakai nilai yang benar, bukan no_rek.
      await _resolveCifFromNoRek();

      // NOTE: pengecekan foto_ktp_path lewat nasabah-photo-bridge per baris
      // (dulu di sini) sudah DIMATIKAN — tabel ini sekarang menampilkan
      // semua hasil account_search apa adanya, tidak lagi disaring
      // berdasarkan hasFotoKtp. Data dari nasabah-foto/inquiry digabung ke
      // tabel yang sama setelah ini (lihat _mergeNasabahFoto), no_cif yang
      // sudah ada di sini tidak dipakai lagi dari inquiry baru.
      _keyword = term;
      _applyFilter();
      errorMessage = null;
    } else {
      errorMessage = (result['message'] as String?)?.isNotEmpty == true
          ? result['message'] as String
          : 'Gagal memuat data.';
    }

    if (!silent) {
      isLoading = false;
      notifyListeners();
    }
    // Kalau silent: sengaja TIDAK notifyListeners di sini. Pemanggil
    // (_initLoad / refresh setelah simpan) yang pegang isLoading sendiri
    // dan akan notify sekali di akhir, setelah _mergeNasabahFoto juga
    // selesai — supaya tabel tidak sempat kelihatan render 5 data duluan
    // sebelum nambah jadi 7.
  }

  // ---------- Resolve CIF asli dari no_rek ----------
  // account_search TIDAK mengembalikan field cif terpisah, jadi tiap baris
  // di-lookup ulang ke inquiryAccount(noRek) — endpoint yang sama dipakai di
  // flow "Cari No Rekening" pada Tambah Foto (lihat searchNasabah) — untuk
  // dapat `nocif` yang asli. Hasilnya ditulis ke d.cif (bukan lagi diisi
  // dari no_rek).
  //
  // Dijalankan dengan concurrency dibatasi (_kResolveCifBatchSize baris
  // sekaligus), BUKAN Future.wait semua baris sekaligus — inquiryAccount
  // memanggil core banking (trx_code 0200) per baris, jadi menembak semua
  // baris berbarengan berisiko membebani gateway core banking kalau
  // datanya banyak.
  //
  // Kalau lookup gagal atau nocif kosong untuk suatu baris, cif dibiarkan
  // kosong ('') — BUKAN fallback ke no_rek — supaya tidak lagi salah
  // tampil seolah no_rek adalah CIF. Baris begini akan tampil '-' di
  // kolom No CIF (lihat _buildRows).
  static const int _kResolveCifBatchSize = 5;

  Future<void> _resolveCifFromNoRek() async {
    final targets = _list.where((d) => d.noRek.isNotEmpty).toList();
    if (targets.isEmpty) return;

    for (var i = 0; i < targets.length; i += _kResolveCifBatchSize) {
      final batch = targets.skip(i).take(_kResolveCifBatchSize);
      await Future.wait(batch.map((d) async {
        try {
          final result =
              await KelolaFotoRepository.inquiryAccount(noRek: d.noRek);
          if (result['value'] == 1) {
            final data = result['data'] as Map<String, dynamic>?;
            d.cif = (data?['nocif'] ?? '').toString();
          } else {
            d.cif = '';
          }
        } catch (e) {
          if (kDebugMode) {
            print('ERROR RESOLVE CIF (no_rek=${d.noRek}): $e');
          }
          d.cif = '';
        }
      }));
    }
  }

  void _applyFilter() {
    final keyword = _keyword.trim().toLowerCase();
    // Pengecekan hasFotoKtp sudah dimatikan (lihat loadData) — tabel ini
    // sekarang menampilkan semua hasil account_search, hanya disaring
    // berdasarkan keyword pencarian.
    final base = _list;
    if (keyword.isEmpty) {
      _filtered = base.toList();
      return;
    }
    _filtered = base.where((d) {
      return d.nama.toLowerCase().contains(keyword) ||
          d.cif.toLowerCase().contains(keyword) ||
          d.noRek.toLowerCase().contains(keyword) ||
          d.noIdentitas.toLowerCase().contains(keyword) ||
          d.noHp.toLowerCase().contains(keyword);
    }).toList();
  }

  void onSearchChanged(String v) {
    _keyword = v;
  }

  Future<void> search() async {
    // Sudah ada data penuh di _list -> tidak perlu hit server lagi,
    // cukup filter ulang di client dengan keyword terbaru.
    if (_list.isNotEmpty) {
      _applyFilter();
      notifyListeners();
      return;
    }
    await loadData(term: _keyword.trim());
  }

  bool isSearchingNasabah = false;
  String? nasabahSearchError;
  _DummyNasabahFoto? nasabahFound;

  Future<void> searchNasabahByRekening() async {
    final noRek = searchNasabahKeyword.trim();
    if (noRek.isEmpty) {
      nasabahFound = null;
      nasabahSearchError = null;
      notifyListeners();
      return;
    }

    isSearchingNasabah = true;
    nasabahSearchError = null;
    nasabahFound = null;
    notifyListeners();

    final result = await KelolaFotoRepository.inquiryAccount(noRek: noRek);

    if (result['value'] == 1 && result['data'] != null) {
      final data = Map<String, dynamic>.from(result['data'] as Map);
      // Coba lengkapi no_hp/no_ktp/tgl_lahir dari data account_search yang
      // sudah ke-load duluan, karena inquiry_account tidak punya field itu.
      _DummyNasabahFoto? enrichFrom;
      for (final d in _list) {
        if (d.noRek == data['no_rek']) {
          enrichFrom = d;
          break;
        }
      }
      nasabahFound = _DummyNasabahFoto.fromInquiryAccount(data, enrichFrom: enrichFrom);
    } else {
      nasabahSearchError = (result['message'] as String?)?.isNotEmpty == true
          ? result['message'] as String
          : 'Rekening tidak ditemukan.';
    }

    isSearchingNasabah = false;
    notifyListeners();
  }

  // ---------- navigation ----------
  void openTambah() {
    formMode = _FormMode.tambah;
    tambahNasabah = null;
    tambahStage = _TambahStage.pilihNasabah;
    tambahSignature = null;
    tambahSelfie = null;
    searchNasabahKeyword = '';
    searchNasabahCtrl.clear();
    nasabahFound = null;
    nasabahSearchError = null;
    isSearchingNasabah = false;
    isCheckingFotoExisting = false;
    isSavingTambah = false;
    tambahSaveError = null;
    viewMode = _ViewMode.form;
    notifyListeners();
  }

  Future<void> openUbah(_DummyNasabahFoto d) async {
    formMode = _FormMode.ubah;
    ubahNasabah = d;
    ubahSignature = d.fotoTtd;
    ubahSelfie = d.fotoSelfie;
    ubahFotoError = null;
    ubahSignaturePath = null;
    ubahSelfiePath = null;
    ubahSignatureChanged = false;
    ubahSelfieChanged = false;
    simpanUbahError = null;
    isLoadingUbahFoto = false;
    viewMode = _ViewMode.form;

    // CIF gagal di-resolve dari no_rek (lihat _resolveCifFromNoRek) — jangan
    // lanjut panggil inquiryNasabahPhoto dengan no_cif kosong, itu bisa balik
    // data nasabah yang salah/tidak relevan.
    if (d.cif.isEmpty) {
      ubahFotoError =
          'CIF nasabah ini belum berhasil ditemukan. Coba muat ulang halaman.';
      notifyListeners();
      return;
    }

    isLoadingUbahFoto = true;
    notifyListeners();

    // Ambil path foto tanda tangan & KTP yang sudah tersimpan di server
    // (action: inquiry), lalu unduh isinya sebagai bytes untuk preview.
    // Kalau nasabah belum punya foto tersimpan, slot dibiarkan kosong
    // seperti semula (bukan dianggap error).
    //
    // NOTE: slot kedua di UI ini label-nya "Foto KTP" dan datanya memang
    // ada di field `foto_ktp_path` — BUKAN `foto_selfie_path` (field itu
    // legacy/tidak dipakai lagi, sering kosong meski foto KTP-nya ada).
    final result = await KelolaFotoRepository.inquiryNasabahPhoto(
      noCif: d.cif,
      bprId: d.bprId.isNotEmpty ? d.bprId : null,
    );

    // Kalau user sudah pindah ke nasabah lain / tutup form sebelum
    // request ini selesai, jangan timpa state yang sekarang.
    if (ubahNasabah != d) return;

    if (result['value'] == 1 && result['data'] != null) {
      final data = Map<String, dynamic>.from(result['data'] as Map);
      final ttdPath = (data['foto_ttd_path'] ?? '').toString();
      final ktpPath = (data['foto_ktp_path'] ?? '').toString();

      final downloaded = await Future.wait([
        KelolaFotoRepository.downloadPhotoBytes(ttdPath),
        KelolaFotoRepository.downloadPhotoBytes(ktpPath),
      ]);

      if (ubahNasabah != d) return;

      ubahSignature = downloaded[0];
      ubahSelfie = downloaded[1];
      ubahSignaturePath = ttdPath.isNotEmpty ? ttdPath : null;
      ubahSelfiePath = ktpPath.isNotEmpty ? ktpPath : null;

      final gagalTtd = ttdPath.isNotEmpty && ubahSignature == null;
      final gagalKtp = ktpPath.isNotEmpty && ubahSelfie == null;
      if (gagalTtd || gagalKtp) {
        ubahFotoError = 'Sebagian foto gagal dimuat, silakan coba lagi.';
      }
    } else {
      final msg = (result['message'] as String?)?.trim() ?? '';
      final belumAda = msg.toLowerCase().contains('tidak ditemukan');
      if (!belumAda && msg.isNotEmpty) {
        ubahFotoError = msg;
      }
    }

    isLoadingUbahFoto = false;
    notifyListeners();
  }

  void closeForm() {
    viewMode = _ViewMode.list;
    formMode = null;
    ubahNasabah = null;
    isLoadingUbahFoto = false;
    ubahFotoError = null;
    ubahSignaturePath = null;
    ubahSelfiePath = null;
    ubahSignatureChanged = false;
    ubahSelfieChanged = false;
    isSavingUbah = false;
    simpanUbahError = null;
    isSavingTambah = false;
    tambahSaveError = null;
    notifyListeners();
  }

  void updateSearchNasabahKeyword(String v) {
    searchNasabahKeyword = v;
    // Keyword berubah -> hasil pencarian sebelumnya sudah tidak relevan.
    nasabahFound = null;
    nasabahSearchError = null;
    notifyListeners();
  }

  void pickNasabah(_DummyNasabahFoto d) {
    tambahNasabah = d;
    tambahStage = _TambahStage.signature;
    tambahSignature = null;
    tambahSelfie = null;
    tambahSaveError = null;
    notifyListeners();
  }

  // Cek ke nasabah-photo-bridge (action: inquiry) apakah nasabah ini sudah
  // punya foto_ktp_path tersimpan. Dipanggil sebelum lanjut ke tahap ambil
  // foto di flow Tambah Foto, supaya user tidak menambahkan foto duplikat
  // untuk akun yang fotonya sudah ada (harusnya lewat fitur Ubah).
  Future<bool> checkFotoKtpExisting(_DummyNasabahFoto d) async {
    if (d.cif.isEmpty) return false;

    isCheckingFotoExisting = true;
    notifyListeners();

    final result = await KelolaFotoRepository.inquiryNasabahPhoto(
      noCif: d.cif,
      bprId: d.bprId.isNotEmpty ? d.bprId : null,
    );

    isCheckingFotoExisting = false;
    notifyListeners();

    if (result['value'] == 1 && result['data'] != null) {
      final data = Map<String, dynamic>.from(result['data'] as Map);
      final ktpPath = (data['foto_ktp_path'] ?? '').toString();
      return ktpPath.isNotEmpty;
    }
    return false;
  }

  void gantiNasabah() {
    tambahNasabah = null;
    tambahStage = _TambahStage.pilihNasabah;
    searchNasabahKeyword = '';
    searchNasabahCtrl.clear();
    nasabahFound = null;
    nasabahSearchError = null;
    isSearchingNasabah = false;
    tambahSaveError = null;
    notifyListeners();
  }

  void lanjutkanTambah() {
    tambahStage = _TambahStage.selfie;
    notifyListeners();
  }

  void selesaiTambah() {
    tambahStage = _TambahStage.done;
    notifyListeners();
  }

  void retakeTambahStage(_TambahStage stage) {
    tambahStage = stage;
    notifyListeners();
  }

  Future<void> pickPhoto({
    required bool isTambah,
    required bool isSignature,
    required ImageSource source,
  }) async {
    try {
      final XFile? file =
          await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (isTambah) {
        if (isSignature) {
          tambahSignature = bytes;
        } else {
          tambahSelfie = bytes;
        }
      } else {
        if (isSignature) {
          ubahSignature = bytes;
          ubahSignatureChanged = true;
        } else {
          ubahSelfie = bytes;
          ubahSelfieChanged = true;
        }
      }
      notifyListeners();
    } catch (_) {
      // dummy: abaikan error picker (mis. dibatalkan / tidak didukung platform)
    }
  }

  void setPhotoBytes({
    required bool isTambah,
    required bool isSignature,
    required Uint8List bytes,
  }) {
    if (isTambah) {
      if (isSignature) {
        tambahSignature = bytes;
      } else {
        tambahSelfie = bytes;
      }
    } else {
      if (isSignature) {
        ubahSignature = bytes;
        ubahSignatureChanged = true;
      } else {
        ubahSelfie = bytes;
        ubahSelfieChanged = true;
      }
    }
    notifyListeners();
  }

  Future<void> simpanTambah() async {
    final c = tambahNasabah;
    if (c == null || isSavingTambah) return;

    // Field No HP sudah dihapus dari form Tambah Foto — request ke
    // nasabahPhotoBridge selalu mengirim placeholder '-'.
    const noHp = '-';

    isSavingTambah = true;
    tambahSaveError = null;
    notifyListeners();

    // Hit /cis/nasabah-foto/save DULUAN, sebelum flow upload foto +
    // nasabah-photo-bridge yang lama. Kalau ini gagal, proses simpan
    // dihentikan di sini.
    final fotoSaveResult = await KelolaFotoRepository.nasabahFotoSave(
      noCif: c.cif,
      nama: c.nama,
    );

    if (fotoSaveResult['value'] != 1) {
      isSavingTambah = false;
      tambahSaveError = (fotoSaveResult['message'] as String?)?.isNotEmpty == true
          ? fotoSaveResult['message'] as String
          : 'Gagal menyimpan data nasabah foto.';
      notifyListeners();
      return;
    }

    // Upload foto tanda tangan/KTP dulu ke /photo/upload-collme untuk
    // dapat path server, baru kirim ke nasabah-photo-bridge (action: upsert)
    // beserta No HP yang diisi manual.
    final uploadResult = await KelolaFotoRepository.uploadFotoCollme(
      ttdBytes: tambahSignature,
      ktpBytes: tambahSelfie,
    );

    if (uploadResult['value'] != 1) {
      isSavingTambah = false;
      tambahSaveError = (uploadResult['message'] as String?)?.isNotEmpty == true
          ? uploadResult['message'] as String
          : 'Gagal mengupload foto.';
      notifyListeners();
      return;
    }

    final result = await KelolaFotoRepository.nasabahPhotoBridge(
      noCif: c.cif,
      noHp: noHp,
      bprId: c.bprId.isNotEmpty ? c.bprId : null,
      fotoTtdPath: uploadResult['ttdPath'] as String?,
      fotoKtpPath: uploadResult['ktpPath'] as String?,
    );

    isSavingTambah = false;

    if (result['value'] == 1) {
      c.fotoTtd = tambahSignature;
      c.fotoSelfie = tambahSelfie;
      closeForm();
      // Refresh list supaya nasabah yang baru ditambahkan fotonya muncul,
      // lalu gabung ulang dengan nasabah-foto/inquiry (skip yang sudah ada).
      // Sama seperti _initLoad: isLoading dipegang manual biar tabel tidak
      // flicker (nampilin data lama/parsial dulu baru nambah).
      isLoading = true;
      notifyListeners();
      await loadData(term: _keyword, silent: true);
      await _mergeNasabahFoto();
      isLoading = false;
      notifyListeners();
    } else {
      tambahSaveError = (result['message'] as String?)?.isNotEmpty == true
          ? result['message'] as String
          : 'Gagal menyimpan foto.';
      notifyListeners();
    }
  }

  // Return value: true kalau ternyata TIDAK ADA foto yang berubah sama
  // sekali (ttdPath & ktpPath dua-duanya null) — dipakai UI pemanggil untuk
  // menampilkan info popup "Tidak ada perubahan yang disimpan.". False
  // untuk kasus lain (berhasil simpan / gagal / sedang menyimpan).
  Future<bool> simpanUbah() async {
    final c = ubahNasabah;
    if (c == null || isSavingUbah) return false;

    isSavingUbah = true;
    simpanUbahError = null;
    notifyListeners();

    // Hit /cis/nasabah-foto/save DULUAN, sebelum flow upload foto +
    // nasabah-photo-bridge yang lama. Kalau ini gagal, proses simpan
    // dihentikan di sini.
    final fotoSaveResult = await KelolaFotoRepository.nasabahFotoSave(
      noCif: c.cif,
      nama: c.nama,
    );

    if (fotoSaveResult['value'] != 1) {
      isSavingUbah = false;
      simpanUbahError = (fotoSaveResult['message'] as String?)?.isNotEmpty == true
          ? fotoSaveResult['message'] as String
          : 'Gagal menyimpan data nasabah foto.';
      notifyListeners();
      return false;
    }

    String? ttdPath = ubahSignaturePath;
    String? ktpPath = ubahSelfiePath;

    // Kalau ada foto yang baru diambil/diganti, upload dulu ke
    // /photo/upload-collme untuk dapat path server yang baru, baru
    // kirim ke nasabah-photo-bridge.
    //
    // PENTING: endpoint /photo/upload-collme mewajibkan KEDUA field (ttd &
    // ktp) ada di request kalau salah satunya mau diproses ulang — kalau
    // cuma kirim foto yang berubah saja, backend menolak dengan pesan
    // "file ktp is required" (atau sebaliknya "file ttd is required").
    // Jadi kalau cuma 1 foto yang diganti tapi foto satunya sudah ada
    // (sudah ke-download dari server saat buka form Ubah), foto lama itu
    // ikut dikirim ulang apa adanya supaya request tetap lengkap.
    if (ubahSignatureChanged || ubahSelfieChanged) {
      final uploadResult = await KelolaFotoRepository.uploadFotoCollme(
        ttdBytes: ubahSignature,
        ktpBytes: ubahSelfie,
      );

      if (uploadResult['value'] != 1) {
        isSavingUbah = false;
        simpanUbahError = (uploadResult['message'] as String?)?.isNotEmpty == true
            ? uploadResult['message'] as String
            : 'Gagal mengupload foto.';
        notifyListeners();
        return false;
      }

      // Kedua path dipakai dari hasil upload ini karena kedua file memang
      // ikut dikirim ulang di atas (baik yang berubah maupun yang lama).
      if (ubahSignature != null) ttdPath = uploadResult['ttdPath'] as String?;
      if (ubahSelfie != null) ktpPath = uploadResult['ktpPath'] as String?;
    }

    if (ttdPath == null && ktpPath == null) {
      isSavingUbah = false;
      notifyListeners();
      return true;
    }

    final result = await KelolaFotoRepository.nasabahPhotoBridge(
      noCif: c.cif,
      noHp: c.noHp,
      bprId: c.bprId.isNotEmpty ? c.bprId : null,
      fotoTtdPath: ttdPath,
      fotoKtpPath: ktpPath,
    );

    isSavingUbah = false;

    if (result['value'] == 1) {
      c.fotoTtd = ubahSignature;
      c.fotoSelfie = ubahSelfie;
      ubahSignaturePath = ttdPath;
      ubahSelfiePath = ktpPath;
      ubahSignatureChanged = false;
      ubahSelfieChanged = false;
      closeForm();
      return false;
    } else {
      simpanUbahError = (result['message'] as String?)?.isNotEmpty == true
          ? result['message'] as String
          : 'Gagal menyimpan foto.';
      notifyListeners();
      return false;
    }
  }

  bool get canSimpan {
    if (formMode == _FormMode.tambah) {
      return tambahNasabah != null &&
          tambahStage == _TambahStage.done &&
          !isSavingTambah;
    } else if (formMode == _FormMode.ubah) {
      return !isSavingUbah;
    }
    return false;
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    searchNasabahCtrl.dispose();
    super.dispose();
  }
}

// ==================== PAGE ====================
class KelolaFotoPage extends StatelessWidget {
  const KelolaFotoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _KelolaFotoNotifier(),
      child: Consumer<_KelolaFotoNotifier>(
        builder: (context, notifier, _) => Scaffold(
          backgroundColor: colorSurfaceTint,
          body: notifier.viewMode == _ViewMode.list
              ? _KelolaFotoListView(notifier: notifier)
              : _KelolaFotoFormView(notifier: notifier),
        ),
      ),
    );
  }
}

// ==================== LIST VIEW ====================
class _KelolaFotoListView extends StatelessWidget {
  final _KelolaFotoNotifier notifier;
  const _KelolaFotoListView({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      color: colorPrimary,
      child: Row(
        children: [
          const Text(
            'Kelola Foto',
            style: TextStyle(
              color: colortextwhite,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: notifier.openTambah,
            style: ElevatedButton.styleFrom(
              backgroundColor: colortextwhite,
              foregroundColor: colorPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Tambah Foto',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 520,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: notifier.searchCtrl,
                    onChanged: notifier.onSearchChanged,
                    onSubmitted: (_) => notifier.search(),
                    decoration: InputDecoration(
                      hintText: 'Cari nama / phone / CIF',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: colortextwhite,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xffD5DBD8)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xffD5DBD8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: colorPrimary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: notifier.isLoading ? null : () => notifier.search(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorPrimary,
                    foregroundColor: colortextwhite,
                    disabledBackgroundColor: const Color(0xffB9C4BF),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: notifier.isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colortextwhite,
                          ),
                        )
                      : const Icon(Icons.search, size: 16),
                  label: const Text('Cari'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _badge(
                notifier.searchCtrl.text.trim().isEmpty
                    ? 'Total Data: ${notifier.filtered.length}'
                    : 'Hasil Pencarian: ${notifier.filtered.length}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _buildListBody(notifier),
          ),
        ],
      ),
    );
  }


  Widget _buildListBody(_KelolaFotoNotifier notifier) {
    if (notifier.isLoading && notifier.filtered.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notifier.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(height: 10),
            Text(
              notifier.errorMessage!,
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => notifier.loadData(term: notifier.searchCtrl.text.trim()),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    if (notifier.filtered.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada nasabah dengan foto',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return AppDataGrid(
      margin: EdgeInsets.zero,
      pageSize: 7,
      columns: _buildColumns(),
      rows: _buildRows(notifier),
      onActionTap: (row) {
        final d = notifier.filtered[row['__index__'] as int];
        notifier.openUbah(d);
      },
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: colorPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: colorPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  List<AppGridColumn> _buildColumns() => [
        const AppGridColumn('nama', 'Nama', width: 250),
        const AppGridColumn('cif', 'No CIF', width: 220),
        const AppGridColumn('noIdentitas', 'No Identitas', width: 200),
        const AppGridColumn('noHp', 'No HP', width: 200),
        const AppGridColumn('tglLahir', 'Tgl Lahir', width: 200),
        AppGridColumn(
          'aksi',
          'Aksi',
          width: 160,
          align: Alignment.center,
          isAction: true,
          cellBuilder: (value) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '✎ Ubah Foto',
              style: TextStyle(
                color: colorPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ];

  List<Map<String, dynamic>> _buildRows(_KelolaFotoNotifier notifier) {
    return notifier.filtered.asMap().entries.map((e) {
      final i = e.key;
      final d = e.value;
      return {
        '__index__': i,
        'nama': d.nama,
        'cif': d.cif.isNotEmpty ? d.cif : '-',
        'noIdentitas': d.noIdentitas.isNotEmpty ? d.noIdentitas : '-',
        'noHp': d.noHp.isNotEmpty ? d.noHp : '-',
        'tglLahir': d.tglLahir,
        'aksi': '',
      };
    }).toList();
  }
}

// ==================== FORM VIEW ====================
class _KelolaFotoFormView extends StatelessWidget {
  final _KelolaFotoNotifier notifier;
  const _KelolaFotoFormView({required this.notifier});

  bool get isTambah => notifier.formMode == _FormMode.tambah;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFormHeader(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: colortextwhite,
                    border: Border(
                      right: BorderSide(color: Color(0xffDCE3DF)),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child:
                        isTambah ? _buildTambahLeft(context) : _buildUbahLeft(),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  color: const Color(0xffFBFCFB),
                  child: isTambah
                      ? _buildTambahRight(context)
                      : _buildUbahRight(context),
                ),
              ),
            ],
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  Widget _buildFormHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: colorPrimary,
      child: Row(
        children: [
          InkWell(
            onTap: notifier.closeForm,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colortextwhite.withOpacity(0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.arrow_back, color: colortextwhite, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            isTambah ? 'Tambah Foto' : 'Ubah Foto',
            style: const TextStyle(
              color: colortextwhite,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: colortextwhite,
        border: Border(top: BorderSide(color: Color(0xffDCE3DF))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: notifier.closeForm,
            style: TextButton.styleFrom(
              backgroundColor: colorcancel,
              foregroundColor: colortextwhite,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: notifier.canSimpan
                ? () {
                    if (isTambah) {
                      notifier.simpanTambah();
                    } else {
                      notifier.simpanUbah();
                    }
                  }
                : null,
            style: TextButton.styleFrom(
              backgroundColor: notifier.canSimpan ? colorPrimary : const Color(0xffB9C4BF),
              foregroundColor: colortextwhite,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: notifier.isSavingUbah
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite),
                  )
                : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Sebelum lanjut ke tahap ambil foto, cek dulu apakah nasabah ini sudah
  // punya foto_ktp_path tersimpan. Kalau sudah, tawarkan pindah ke fitur
  // Ubah alih-alih lanjut menambah foto baru.
  Future<void> _handlePilihNasabah(
    BuildContext context,
    _DummyNasabahFoto d,
  ) async {
    final sudahAda = await notifier.checkFotoKtpExisting(d);
    if (!context.mounted) return;

    if (sudahAda) {
      // Dipakai showModalBottomSheet + styling manual (bukan AlertDialog
      // bawaan) supaya modelnya sama kayak popup lain di app — lihat
      // CustomDialog di utils/dialog_custom.dart (rounded 16, header
      // ikon+judul, tombol ButtonPrimary/ButtonPrimaryNoRounded).
      final keUbah = await showModalBottomSheet<bool>(
        backgroundColor: Colors.transparent,
        context: context,
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colortextwhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF8B5CF6), size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Foto Sudah Ada',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Akun ini sudah memiliki foto, gunakan fitur ubah untuk menambah/mengubah foto. Apa anda ingin ke fitur ubah?',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ButtonPrimaryNoRounded(
                          onTap: () => Navigator.of(ctx).pop(false),
                          name: 'Tidak',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ButtonPrimary(
                          onTap: () => Navigator.of(ctx).pop(true),
                          name: 'Ya',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (keUbah == true) {
        await notifier.openUbah(d);
      }
      return;
    }

    notifier.pickNasabah(d);
  }

  // ---------------- TAMBAH: LEFT ----------------
  Widget _buildTambahLeft(BuildContext context) {
    if (notifier.tambahNasabah == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Cari No Rekening'),
          TextField(
            controller: notifier.searchNasabahCtrl,
            onChanged: notifier.updateSearchNasabahKeyword,
            onSubmitted: (_) => notifier.searchNasabahByRekening(),
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('Ketik no rekening...').copyWith(
              suffixIcon: IconButton(
                icon: notifier.isSearchingNasabah
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search, size: 20),
                onPressed: notifier.isSearchingNasabah
                    ? null
                    : notifier.searchNasabahByRekening,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (notifier.isSearchingNasabah ||
              notifier.nasabahSearchError != null ||
              notifier.nasabahFound != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: colortextwhite,
                border: Border.all(color: const Color(0xffDCE3DF)),
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(maxHeight: 230),
              child: notifier.isSearchingNasabah
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : notifier.nasabahSearchError != null
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            notifier.nasabahSearchError!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListTile(
                          dense: true,
                          title: Text(
                            '${notifier.nasabahFound!.nama} - ${notifier.nasabahFound!.noRek}',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'CIF: ${notifier.nasabahFound!.cif}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          onTap: notifier.isCheckingFotoExisting
                              ? null
                              : () => _handlePilihNasabah(
                                  context, notifier.nasabahFound!),
                          trailing: notifier.isCheckingFotoExisting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : null,
                        ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Ketik no rekening lalu tekan Enter/ikon cari, pilih nasabah dari hasil untuk melanjutkan.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey),
          ),
        ],
      );
    }

    final c = notifier.tambahNasabah!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('No CIF'),
        Row(
          children: [
            Expanded(child: _readonlyField(c.cif)),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: notifier.gantiNasabah,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff555555),
                side: const BorderSide(color: Color(0xffC8CDC9)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Ganti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Nama'),
        _readonlyField(c.nama),
      ],
    );
  }

  // ---------------- TAMBAH: RIGHT ----------------
  Widget _buildTambahRight(BuildContext context) {
    if (notifier.tambahNasabah == null) {
      return _emptyState('Pilih nasabah terlebih dahulu di sebelah kiri');
    }

    if (notifier.tambahStage == _TambahStage.done) {
      return _doneStageWidget(
        context: context,
        isTambah: true,
        signature: notifier.tambahSignature,
        selfie: notifier.tambahSelfie,
      );
    }

    final isSig = notifier.tambahStage == _TambahStage.signature;
    final label = isSig ? 'Ambil Foto Tanda Tangan' : 'Ambil Foto KTP';
    final photo = isSig ? notifier.tambahSignature : notifier.tambahSelfie;
    final nextLabel = isSig ? 'Lanjutkan' : 'Selesai';
    final nextFn = isSig ? notifier.lanjutkanTambah : notifier.selesaiTambah;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: colorPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _photoPreview(photo),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _ambilFotoButton(
              context: context,
              onGaleri: () => notifier.pickPhoto(
                isTambah: true,
                isSignature: isSig,
                source: ImageSource.gallery,
              ),
              onKamera: () async {
                final bytes = await _captureFromCamera(context);
                if (bytes != null) {
                  notifier.setPhotoBytes(
                    isTambah: true,
                    isSignature: isSig,
                    bytes: bytes,
                  );
                }
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: photo != null ? nextFn : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrimary,
                  foregroundColor: colortextwhite,
                  disabledBackgroundColor: const Color(0xffB9C4BF),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(nextLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Pilih foto dari galeri (folder laptop) atau ambil langsung dari kamera.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey),
        ),
      ],
    );
  }

  // ---------------- UBAH: LEFT ----------------
  Widget _buildUbahLeft() {
    final c = notifier.ubahNasabah!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('No CIF'),
        _readonlyField(c.cif),
        const SizedBox(height: 16),
        const _FieldLabel('Nama'),
        _readonlyField(c.nama),
        const SizedBox(height: 16),
        const _FieldLabel('No HP'),
        _readonlyField(c.noHp),
        const SizedBox(height: 16),
        const _FieldLabel('No Identitas'),
        _readonlyField(c.noIdentitas),
        const SizedBox(height: 16),
        const _FieldLabel('Tgl Lahir'),
        _readonlyField(c.tglLahir),
      ],
    );
  }

  // ---------------- UBAH: RIGHT ----------------
  Widget _buildUbahRight(BuildContext context) {
    if (notifier.isLoadingUbahFoto) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Memuat foto tersimpan...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Tanda Tangan & KTP',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: colorPrimary,
          ),
        ),
        if (notifier.ubahFotoError != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            ),
            child: Text(
              notifier.ubahFotoError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
            ),
          ),
        ],
        if (notifier.simpanUbahError != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            ),
            child: Text(
              notifier.simpanUbahError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _ubahSlot(
                  context: context,
                  label: 'Tanda Tangan',
                  photo: notifier.ubahSignature,
                  onGaleri: () => notifier.pickPhoto(
                    isTambah: false,
                    isSignature: true,
                    source: ImageSource.gallery,
                  ),
                  onKamera: () async {
                    final bytes = await _captureFromCamera(context);
                    if (bytes != null) {
                      notifier.setPhotoBytes(
                        isTambah: false,
                        isSignature: true,
                        bytes: bytes,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _ubahSlot(
                  context: context,
                  label: 'Foto KTP',
                  photo: notifier.ubahSelfie,
                  onGaleri: () => notifier.pickPhoto(
                    isTambah: false,
                    isSignature: false,
                    source: ImageSource.gallery,
                  ),
                  onKamera: () async {
                    final bytes = await _captureFromCamera(context);
                    if (bytes != null) {
                      notifier.setPhotoBytes(
                        isTambah: false,
                        isSignature: false,
                        bytes: bytes,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Klik salah satu foto untuk melihat tampilan penuh, atau "Ganti Foto" untuk mengambil ulang.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey),
        ),
      ],
    );
  }

  // ---------------- shared widgets ----------------
  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_search, size: 40, color: Color(0xff9AA6A0)),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Color(0xff9AA6A0))),
        ],
      ),
    );
  }

  Widget _photoPreview(Uint8List? photo) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: photo != null ? const Color(0xffDCE3DF) : const Color(0xffC7CFCA),
          width: photo != null ? 1 : 1.5,
          style: BorderStyle.solid,
        ),
        color: colortextwhite,
      ),
      child: photo == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 36, color: Color(0xff9AA6A0)),
                  SizedBox(height: 8),
                  Text('Belum ada foto diambil', style: TextStyle(color: Color(0xff9AA6A0))),
                ],
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.memory(photo, fit: BoxFit.contain),
            ),
    );
  }

  Widget _doneStageWidget({
    required BuildContext context,
    required bool isTambah,
    required Uint8List? signature,
    required Uint8List? selfie,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Tersimpan',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colorPrimary),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _doneSlot(
                  context: context,
                  label: 'Tanda Tangan',
                  photo: signature,
                  onGantiFoto: () => notifier.retakeTambahStage(_TambahStage.signature),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _doneSlot(
                  context: context,
                  label: 'Foto KTP',
                  photo: selfie,
                  onGantiFoto: () => notifier.retakeTambahStage(_TambahStage.selfie),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Klik salah satu foto untuk melihat tampilan penuh.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _doneSlot({
    required BuildContext context,
    required String label,
    required Uint8List? photo,
    required VoidCallback onGantiFoto,
  }) {
    return GestureDetector(
      onTap: photo != null ? () => _openLightbox(context, photo) : null,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffDCE3DF)),
          color: colortextwhite,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xffF3F5F4)),
            if (photo != null)
              Image.memory(photo, fit: BoxFit.contain)
            else
              const Center(child: Text('Belum ada foto', style: TextStyle(color: Colors.grey))),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colorPrimary.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label, style: const TextStyle(color: colortextwhite, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: TextButton.icon(
                onPressed: onGantiFoto,
                style: TextButton.styleFrom(
                  backgroundColor: colorPrimary,
                  foregroundColor: colortextwhite,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 2,
                  shadowColor: Colors.black45,
                ),
                icon: const Icon(Icons.camera_alt, size: 14),
                label: const Text('Ganti Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ubahSlot({
    required BuildContext context,
    required String label,
    required Uint8List? photo,
    required VoidCallback onGaleri,
    required VoidCallback onKamera,
  }) {
    return GestureDetector(
      onTap: photo != null ? () => _openLightbox(context, photo) : null,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffDCE3DF)),
          color: colortextwhite,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xffF3F5F4)),
            if (photo != null)
              Image.memory(photo, fit: BoxFit.contain)
            else
              const Center(child: Text('Belum ada foto', style: TextStyle(color: Colors.grey))),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colorPrimary.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label, style: const TextStyle(color: colortextwhite, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: _ambilFotoButton(
                context: context,
                onGaleri: onGaleri,
                onKamera: onKamera,
                label: 'Ganti Foto',
                filled: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ambilFotoButton({
    required BuildContext context,
    required VoidCallback onGaleri,
    required VoidCallback onKamera,
    String label = 'Ambil Foto',
    bool filled = false,
  }) {
    return filled
        ? TextButton.icon(
            onPressed: () => _showAmbilFotoSheet(context, onGaleri, onKamera),
            style: TextButton.styleFrom(
              backgroundColor: colorPrimary,
              foregroundColor: colortextwhite,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 2,
              shadowColor: Colors.black45,
            ),
            icon: const Icon(Icons.camera_alt, size: 14),
            label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          )
        : OutlinedButton.icon(
            onPressed: () => _showAmbilFotoSheet(context, onGaleri, onKamera),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorPrimary,
              side: const BorderSide(color: colorPrimary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.photo_camera_outlined, size: 17),
            label: const Text('Ambil Foto', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          );
  }

  void _showAmbilFotoSheet(BuildContext context, VoidCallback onGaleri, VoidCallback onKamera) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xffDCE3DF),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open, color: colorPrimary),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                onGaleri();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: colorPrimary),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(context);
                onKamera();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _captureFromCamera(BuildContext context) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (context) => const _CameraCaptureDialog(),
    );
  }

  void _openLightbox(BuildContext context, Uint8List photo) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82,
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: colortextwhite,
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.hardEdge,
                child: InteractiveViewer(
                  child: Image.memory(photo, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: colortextwhite, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readonlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xffF0F0F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffC8CDC9)),
      ),
      child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xff555555))),
    );
  }

  InputDecoration _inputDecoration(String hint, {bool readonly = false}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: readonly ? const Color(0xffF0F0F0) : colortextwhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xffC8CDC9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xffC8CDC9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: colorPrimary, width: 1.5),
      ),
    );
  }
}

// ==================== LIVE CAMERA CAPTURE DIALOG ====================
// Membuka kamera perangkat (webcam laptop / kamera eksternal) secara
// langsung menggunakan package `camera`, lengkap dengan permintaan izin
// akses kamera dari browser/OS.
class _CameraCaptureDialog extends StatefulWidget {
  const _CameraCaptureDialog();

  @override
  State<_CameraCaptureDialog> createState() => _CameraCaptureDialogState();
}

class _CameraCaptureDialogState extends State<_CameraCaptureDialog> {
  CameraController? _controller;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'Kamera tidak ditemukan pada perangkat ini.');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'Tidak dapat mengakses kamera. Pastikan izin kamera sudah diberikan pada browser/perangkat ini.';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final XFile file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (e) {
      setState(() => _capturing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil foto dari kamera.')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colortextwhite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ambil Foto dari Kamera',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 320,
                  width: double.infinity,
                  color: Colors.black,
                  child: _buildPreviewArea(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pastikan wajah/objek terlihat jelas di dalam bingkai sebelum mengambil foto.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff555555),
                        side: const BorderSide(color: Color(0xffC8CDC9)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_controller != null && _controller!.value.isInitialized && !_capturing)
                              ? _capture
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorPrimary,
                        foregroundColor: colortextwhite,
                        disabledBackgroundColor: const Color(0xffB9C4BF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: _capturing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colortextwhite,
                              ),
                            )
                          : const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Ambil Foto', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: colortextwhite),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}