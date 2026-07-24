import 'dart:convert';
import 'dart:typed_data';
import 'package:cis_menu/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../network/network.dart';
import '../pref/pref.dart';
import '../utils/inquiry_filter.dart';

class KelolaFotoRepository {
  static Future<Dio> _dioWithToken() => ApiClient.buildProtected();

  static dynamic _safeDecode(dynamic data) {
    if (data is String) return jsonDecode(data);
    return data;
  }

  static String _dioErrorMessage(dynamic e) {
    if (e is DioException && e.response?.data != null) {
      try {
        final d = _safeDecode(e.response!.data);
        if (d is Map) {
          final msg = (d['message'] ?? '').toString().trim();
          if (msg.isNotEmpty) return msg;
        }
      } catch (_) {}
    }
    return 'Terjadi kesalahan, silakan coba lagi.';
  }

  // ==================== INQUIRY & SEARCH (account_search) ====================
  // Dipakai untuk list awal (term kosong) maupun pencarian (term diisi
  // keyword nama/no rekening/dsb). `type` mengikuti kontrak backend,
  // default "all".
  //
  // NOTE PENTING: field `term` di endpoint-endpoint legacy CMS (url_go)
  // BUKAN keyword pencarian — ini identifier asal client, selalu "WEB",
  // sama seperti dipakai di getListKantor/user_search dkk (lihat
  // users_access_repository.dart). Backend mewajibkan field ini terisi,
  // makanya request dengan term:"" ditolak ("term is required").
  // Endpoint ini sendiri tidak punya field keyword terpisah, jadi
  // pencarian berdasarkan kata kunci dilakukan di sisi client
  // (lihat _KelolaFotoNotifier._applyFilter).
  static Future<Map<String, dynamic>> accountSearch({
    String type = 'all',
    String? bprId,
    String? userLogin,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'bpr_id': bprId ?? session.bprId,
        'term': 'WEB',
        'type': type,
        'userlogin': userLogin ?? session.usersId,
      };

      if (kDebugMode) {
        print('ACCOUNT SEARCH URL : ${NetworkURL.accountSearch()}');
        print('ACCOUNT SEARCH BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.accountSearch(), data: body);
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('ACCOUNT SEARCH RESP: $decoded');

      final code = (decoded['code'] ?? '').toString();
      final rawData = decoded['data'];
      final dataList = InquiryFilter.applyWithSession(
        rawData is List ? rawData : <dynamic>[],
        sessionBprId: session.bprId,
        sessionKodeKantor: session.kodeKantor,
        sentBprId: true,
      );

      return {
        'value': code == '000' ? 1 : 0,
        'message': (decoded['message'] ?? '').toString(),
        'data': dataList,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR ACCOUNT SEARCH: $e');
      return {'value': 0, 'message': _dioErrorMessage(e), 'data': <dynamic>[]};
    }
  }

  // ==================== INQUIRY ACCOUNT (by no_rek, exact) ====================
  // Dipakai di flow Tambah Foto untuk memvalidasi & mengambil data
  // rekening (termasuk nocif) langsung dari core banking. Endpoint ini
  // hanya menerima no_rek persis, bukan pencarian nama sebagian.
  static Future<Map<String, dynamic>> inquiryAccount({
    required String noRek,
    String? bprId,
    String? userLogin,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();

      final now = DateTime.now();
      final tglTrans = '${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}.0';
      final rrn = now.millisecondsSinceEpoch.toString();

      final body = {
        'bpr_id': bprId ?? session.bprId,
        'gl_jns': '2',
        'no_rek': noRek,
        'rrn': rrn,
        'tgl_trans': tglTrans,
        'tgl_transmis': tglTrans,
        'trx_code': '0200',
        'trx_type': 'TRX',
        'userlogin': userLogin ?? session.usersId,
      };

      if (kDebugMode) {
        print('INQUIRY ACCOUNT (nasabah) URL : ${NetworkURL.inquiryAccount()}');
        print('INQUIRY ACCOUNT (nasabah) BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.inquiryAccount(), data: body);
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('INQUIRY ACCOUNT (nasabah) RESP: $decoded');

      final code = (decoded['code'] ?? '').toString();
      final data = decoded['data'];

      return {
        'value': code == '000' && data is Map ? 1 : 0,
        'message': (decoded['message'] ?? '').toString(),
        'data': data is Map ? Map<String, dynamic>.from(data) : null,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR INQUIRY ACCOUNT (nasabah): $e');
      return {'value': 0, 'message': _dioErrorMessage(e), 'data': null};
    }
  }

  // ==================== NASABAH PHOTO BRIDGE (inquiry) ====================
  // Dipakai di layar "Ubah Foto" untuk mengambil path foto tanda tangan &
  // selfie/KTP yang sudah tersimpan di server, sebelum foto tersebut
  // ditampilkan sebagai preview.
  static Future<Map<String, dynamic>> inquiryNasabahPhoto({
    required String noCif,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'action': 'inquiry',
        'bpr_id': bprId ?? session.bprId,
        'no_cif': noCif,
      };

      if (kDebugMode) {
        print('NASABAH PHOTO BRIDGE (inquiry) URL : ${NetworkURL.nasabahPhotoBridge()}');
        print('NASABAH PHOTO BRIDGE (inquiry) BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.nasabahPhotoBridge(), data: body);
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('NASABAH PHOTO BRIDGE (inquiry) RESP: $decoded');

      final code = (decoded['code'] ?? '').toString();
      final data = decoded['data'];

      return {
        'value': code == '000' && data is Map ? 1 : 0,
        'message': (decoded['message'] ?? '').toString(),
        'data': data is Map ? Map<String, dynamic>.from(data) : null,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR NASABAH PHOTO BRIDGE (inquiry): $e');
      return {'value': 0, 'message': _dioErrorMessage(e), 'data': null};
    }
  }

  // ==================== DOWNLOAD FOTO (by path dari inquiry) ====================
  // `path` adalah path relatif yang dikembalikan backend, mis.
  // "/assets/foto_ttd/ttd_20260620_151030_123456.jpg". Foto WAJIB diunduh
  // sebagai bytes MENTAH (ResponseType.bytes) — kalau tidak, Dio akan
  // mencoba men-decode body sebagai UTF-8/JSON dan merusak data biner
  // gambar, yang berujung ImageCodecException saat dirender dengan
  // Image.memory (file header jadi tidak valid).
  static Future<Uint8List?> downloadPhotoBytes(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;

    try {
      final dio = await _dioWithToken();
      final url = trimmed.startsWith('http') ? trimmed : '$url_go$trimmed';

      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } catch (e) {
      if (kDebugMode) print('ERROR DOWNLOAD FOTO ($path): $e');
      return null;
    }
  }

  // ==================== UPLOAD FOTO (ttd & ktp) ====================
  // Upload multipart ke /photo/upload-collme untuk dapat path server dari
  // foto tanda tangan / KTP yang baru diambil/diganti user. Path hasil
  // upload ini yang dikirim ke nasabahPhotoBridge (action: upsert) sebagai
  // foto_ttd_path / foto_ktp_path. Field cukup dikirim salah satu kalau
  // yang lain tidak berubah (mis. hanya 'ttd' saja).
  //
  // Response terkonfirmasi:
  // { "code": "000", "data": { "ttd_file_name": "...", "ttd_path": "...",
  //   "ktp_file_name": "...", "ktp_path": "..." }, "message": "...",
  //   "status": "success" }
  static Future<Map<String, dynamic>> uploadFotoCollme({
    Uint8List? ttdBytes,
    Uint8List? ktpBytes,
    String ttdFilename = 'ttd.jpg',
    String ktpFilename = 'ktp.jpg',
  }) async {
    if (ttdBytes == null && ktpBytes == null) {
      return {
        'value': 0,
        'message': 'Tidak ada foto untuk diupload.',
        'ttdPath': null,
        'ktpPath': null,
      };
    }

    try {
      final dio = await _dioWithToken();

      final formData = FormData.fromMap({
        if (ttdBytes != null)
          'ttd': MultipartFile.fromBytes(ttdBytes, filename: ttdFilename),
        if (ktpBytes != null)
          'ktp': MultipartFile.fromBytes(ktpBytes, filename: ktpFilename),
      });

      if (kDebugMode) {
        print('UPLOAD FOTO COLLME URL   : ${NetworkURL.uploadFotoCollme()}');
        print('UPLOAD FOTO COLLME FIELDS: ${formData.files.map((f) => f.key).toList()}');
      }

      final response = await dio.post(
        NetworkURL.uploadFotoCollme(),
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('UPLOAD FOTO COLLME RESP  : $decoded');

      final code = (decoded['code'] ?? '').toString();
      final status = (decoded['status'] ?? '').toString();
      final success = code == '000' || status.toLowerCase() == 'success';

      final rawData = decoded['data'];
      final dataMap = rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{};

      // 'ttd_path'/'ktp_path' adalah nama field yang sudah dikonfirmasi;
      // sisanya cuma fallback jaga-jaga kalau backend berubah suatu saat.
      String? pick(List<String> keys) {
        for (final k in keys) {
          final v = dataMap[k] ?? decoded[k];
          if (v != null && v.toString().trim().isNotEmpty) return v.toString();
        }
        return null;
      }

      return {
        'value': success ? 1 : 0,
        'message': (decoded['message'] ?? '').toString(),
        'ttdPath': pick(['ttd_path', 'foto_ttd_path', 'ttd']),
        'ktpPath': pick(['ktp_path', 'foto_ktp_path', 'ktp']),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR UPLOAD FOTO COLLME: $e');
      return {'value': 0, 'message': _dioErrorMessage(e), 'ttdPath': null, 'ktpPath': null};
    }
  }

  // ==================== NASABAH PHOTO BRIDGE (upsert) ====================
  // Simpan/update path foto (tanda tangan & KTP) yang sudah ke-upload ke
  // storage server. `foto_ttd_path` / `foto_ktp_path` bersifat opsional
  // per panggilan — kirim null kalau foto itu tidak sedang diubah.
  static Future<Map<String, dynamic>> nasabahPhotoBridge({
    required String noCif,
    required String noHp,
    String action = 'upsert',
    String source = 'collme',
    String? bprId,
    String? fotoTtdPath,
    String? fotoKtpPath,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = <String, dynamic>{
        'action': action,
        'source': source,
        'bpr_id': bprId ?? session.bprId,
        'no_cif': noCif,
        'no_hp': noHp,
        if (fotoTtdPath != null) 'foto_ttd_path': fotoTtdPath,
        if (fotoKtpPath != null) 'foto_ktp_path': fotoKtpPath,
      };

      if (kDebugMode) {
        print('NASABAH PHOTO BRIDGE URL : ${NetworkURL.nasabahPhotoBridge()}');
        print('NASABAH PHOTO BRIDGE BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.nasabahPhotoBridge(), data: body);
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('NASABAH PHOTO BRIDGE RESP: $decoded');

      final code = (decoded['code'] ?? '').toString();
      final status = (decoded['status'] ?? '').toString();

      return {
        'value': (code == '000' || status == 'success') ? 1 : 0,
        'message': (decoded['message'] ?? '').toString(),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR NASABAH PHOTO BRIDGE: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== NASABAH FOTO SAVE (baru) ====================
  // Endpoint terpisah dari nasabahPhotoBridge, di $url_go3 (web_service),
  // bukan $url_go (legacy CMS). Dipanggil DULUAN di simpanTambah &
  // simpanUbah, sebelum flow upload foto + nasabahPhotoBridge yang lama —
  // kalau ini gagal, proses simpan dihentikan dan flow lama tidak jalan.
  static Future<Map<String, dynamic>> nasabahFotoSave({
    required String noCif,
    required String nama,
  }) async {
    try {
      final dio = await _dioWithToken();

      final body = {
        'no_cif': noCif,
        'nama': nama,
      };

      if (kDebugMode) {
        print('NASABAH FOTO SAVE URL : ${NetworkURL.nasabahFotoSave()}');
        print('NASABAH FOTO SAVE BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.nasabahFotoSave(), data: body);
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('NASABAH FOTO SAVE RESP: $decoded');

      final code = (decoded['code'] ?? '').toString();
      final status = (decoded['status'] ?? '').toString();

      return {
        'value': (code == '000' || status.toLowerCase() == 'success') ? 1 : 0,
        'message': (decoded['message'] ?? '').toString(),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR NASABAH FOTO SAVE: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== NASABAH FOTO INQUIRY (baru, list terpisah) ====================
  // List terpisah dari account_search — endpoint & sumber data beda
  // (di $url_go3/cis/nasabah-foto/inquiry), paginated pakai search/page/size.
  // Dipakai untuk tabel "Daftar Nasabah Foto" yang tampil terpisah dari
  // tabel account_search di halaman Kelola Foto.
  static Future<Map<String, dynamic>> nasabahFotoInquiry({
    required String search,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final dio = await _dioWithToken();

      final body = {
        'search': search,
        'page': page,
        'size': size,
      };

      if (kDebugMode) {
        print('NASABAH FOTO INQUIRY URL : ${NetworkURL.nasabahFotoInquiry()}');
        print('NASABAH FOTO INQUIRY BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.nasabahFotoInquiry(), data: body);
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('NASABAH FOTO INQUIRY RESP: $decoded');

      final code = (decoded['code'] ?? '').toString();
      final rawData = decoded['data'];
      // List-nya ada di data.items (paginated), bukan langsung di data.
      final itemsRaw = rawData is Map ? rawData['items'] : null;
      final dataList = itemsRaw is List ? itemsRaw : <dynamic>[];

      if (kDebugMode) {
        print('NASABAH FOTO INQUIRY PARSE: code=$code, '
            'rawData.runtimeType=${rawData.runtimeType}, '
            'itemsRaw.runtimeType=${itemsRaw.runtimeType}, '
            'dataList.length=${dataList.length}');
      }

      return {
        'value': code == '000' ? 1 : 0,
        'message': (decoded['message'] ?? '').toString(),
        'data': dataList,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR NASABAH FOTO INQUIRY: $e');
      return {'value': 0, 'message': _dioErrorMessage(e), 'data': <dynamic>[]};
    }
  }
}