import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/network.dart';
import 'package:intl/intl.dart';
import '../pref/pref.dart';
import '../utils/inquiry_filter.dart';
import '../models/fasilitas_model.dart';

class TellerRepository {
  static Future<Dio> _dioWithToken() => ApiClient.buildProtected();

  static dynamic _safeDecode(dynamic data) {
    if (data is String) return jsonDecode(data);
    return data;
  }

  static int _mapCode(dynamic response) {
    final code = (response['code'] ?? '').toString();
    return code == '000' || code == '200' || code == '201' ? 1 : 0;
  }

  static String _mapMessage(dynamic response) {
    return (response['message'] ?? '').toString();
  }

  static String _dioErrorMessage(dynamic e) {
    if (e is DioException && e.response?.data != null) {
      try {
        final d = _safeDecode(e.response!.data);
        if (d is Map) {
          // Cek apakah ada field-level validation errors (dari WriteValidationError)
          final fields = d['data']?['fields'];
          if (fields is Map && fields.isNotEmpty) {
            final details = fields.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join('\n');
            final baseMsg = (d['message'] ?? '').toString().trim();
            return baseMsg.isNotEmpty ? '$baseMsg\n$details' : details;
          }
          // Fallback ke message biasa
          final msg = (d['message'] ?? '').toString().trim();
          if (msg.isNotEmpty) return msg;
        }
      } catch (_) {}
    }
    return 'Terjadi kesalahan, silakan coba lagi.';
  }

  // ==================== INQUIRY SBB VIA INQUIRY ACCOUNT ====================
static Future<Map<String, dynamic>> inquirySbbByAccount({
  required String noRek,
  String? bprId,
  String? userLogin,
}) async {
  try {
    final dio = await _dioWithToken();
    final session = await Pref().getUsers();
    
    // Generate timestamp format: ddmmyyHHMMss
    final now = DateTime.now();
    final tglTrans = DateFormat('ddMMyyHHmmss').format(now);
    
    // Generate RRN (mikrotime)
    final rrn = DateTime.now().millisecondsSinceEpoch.toString();
    
    final body = {
      "userlogin": userLogin ?? session.usersId,
      "bpr_id": bprId ?? session.bprId,
      "trx_code": "0200",
      "trx_type": "TRX",
      "tgl_trans": tglTrans,
      "tgl_transmis": tglTrans,
      "rrn": rrn,
      "no_rek": noRek,
      "gl_jns": "1",
    };
    
    if (kDebugMode) {
      print('INQUIRY ACCOUNT URL: ${NetworkURL.inquiryAccount()}');
      print('INQUIRY ACCOUNT BODY: ${jsonEncode(body)}');
    }
    
    final response = await dio.post(NetworkURL.inquiryAccount(), data: body);
    final decoded = _safeDecode(response.data);
    
    if (kDebugMode) print('INQUIRY ACCOUNT RESPONSE: $decoded');
    
    // Parse response untuk mendapatkan nama SBB
    // Asumsi response berisi data rekening dengan field nama
    if (decoded['code'] == '000' && decoded['data'] != null) {
      final data = decoded['data'];
      // Sesuaikan field nama dari response
      final namaSbb = data['nama'] ?? data['nama_rekening'] ?? data['nama_sbb'] ?? '';
      final noSbb = data['no_rek'] ?? data['nosbb'] ?? noRek;
      final stsrec = (data['stsrec'] ?? data['status'] ?? 'AKTIF').toString();
      
      return {
        "value": 1,
        "message": "Data ditemukan",
        "noSbb": noSbb,
        "namaSbb": namaSbb,
        "stsrec": stsrec,
      };
    } else {
      return {
        "value": 0,
        "message": decoded['message'] ?? "No SBB tidak ditemukan",
        "noSbb": "",
        "namaSbb": "",
      };
    }
  } catch (e) {
    if (kDebugMode) print('ERROR INQUIRY ACCOUNT: $e');
    return {"value": 0, "message": "Terjadi kesalahan: $e", "noSbb": "", "namaSbb": ""};
  }
}

  // ==================== INQUIRY ====================
  static Future<Map<String, dynamic>> resolveUserIdTeller({
    String? userId,
    String? noHp,
    String? backendId,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = <String, dynamic>{'bpr_id': bprId ?? session.bprId};
      if (userId != null && userId.trim().isNotEmpty) body['userid'] = userId.trim();
      if (noHp != null && noHp.trim().isNotEmpty) body['nohp'] = noHp.trim();
      final parsedBackendId = int.tryParse(backendId ?? '') ?? 0;
      if (parsedBackendId > 0) body['backend_id'] = parsedBackendId;

      final response = await dio.post(NetworkURL.resolveUserIdTeller(), data: jsonEncode(body));
      final decoded = _safeDecode(response.data);
      final rawData = decoded['data'];
      final resolved = rawData is Map ? (rawData['userid'] ?? '').toString() : '';
      return {'value': _mapCode(decoded), 'message': _mapMessage(decoded), 'userid': resolved};
    } catch (e) {
      return {'value': 0, 'message': _dioErrorMessage(e), 'userid': ''};
    }
  }

  static Future<Map<String, dynamic>> syncRepairTeller({String? bprId, bool autoLink = true}) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {'bpr_id': bprId ?? session.bprId, 'page': 1, 'size': 5000, 'auto_link': autoLink};
      final response = await dio.post(NetworkURL.syncRepairTeller(), data: jsonEncode(body));
      final decoded = _safeDecode(response.data);
      return {'value': _mapCode(decoded), 'message': _mapMessage(decoded), 'data': decoded['data']};
    } catch (e) {
      return {'value': 0, 'message': _dioErrorMessage(e), 'data': null};
    }
  }

  static Future<Map<String, dynamic>> syncBackfillTeller({required List<Map<String, dynamic>> items}) async {
    try {
      final dio = await _dioWithToken();
      final response = await dio.post(NetworkURL.syncBackfillTeller(), data: jsonEncode({'items': items}));
      final decoded = _safeDecode(response.data);
      return {'value': _mapCode(decoded), 'message': _mapMessage(decoded), 'data': decoded['data']};
    } catch (e) {
      return {'value': 0, 'message': _dioErrorMessage(e), 'data': null};
    }
  }

  // ==================== INQUIRY DARI DB LOKAL ====================
  // Dipakai KHUSUS untuk menu Buka/Tutup Transaksi Teller.
  // Endpoint ini baca langsung dari database lokal (kolom stsaktif), yang
  // disinkron langsung oleh bukaTransaksiTeller/tutupTransaksiTeller — jadi
  // status di sini SELALU akurat, tidak seperti field 'transaksi_teller' dari
  // inquiryTeller() biasa (yang datanya dari middleware/webservice lama).
  //
  // Status yang dikembalikan tiap item: 'stsaktif' = 'A' (terbuka) atau 'C' (tertutup).
  // ==================== RESET DEVICE ====================
  // Kosongkan login_device_id, login_device_name, & fcm_token milik teller,
  // supaya dia bisa login dari device lain.
  static Future<Map<String, dynamic>> resetDevice({required String userid}) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {
        'bpr_id': session.bprId,
        'userid': userid,
        'userlogin': session.usersId,
        'term': 'WEB',
      };
      if (kDebugMode) print('📤 RESET DEVICE TELLER BODY: ${jsonEncode(body)}');
      final response = await dio.post(NetworkURL.resetDeviceTeller(), data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print('📥 RESET DEVICE TELLER RESPONSE: $decoded');
      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('❌ ERROR RESET DEVICE TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  static Future<Map<String, dynamic>> inquiryTellerDb({
    String? filterNama,
    String? filterKdKantor,
    String? search,
    String? bprId,
    int page = 1,
    int limit = 500,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {
        "nama": filterNama ?? "",
        "search": search ?? "",
        "bpr_id": bprId ?? session.bprId,
        "kd_kantor": filterKdKantor ?? "",
        "page": page,
        "size": limit,
        "sort": "nama",
        "order": "asc",
      };
      if (kDebugMode) {
        print("INQUIRY TELLER-DB URL: ${NetworkURL.inquiryTellerDb()}");
        print("INQUIRY TELLER-DB BODY: ${jsonEncode(body)}");
      }
      final response = await dio.post(NetworkURL.inquiryTellerDb(), data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("INQUIRY TELLER-DB RESPONSE: $decoded");

      final rawData = decoded['data'];
      List<dynamic> dataList = [];
      int total = 0;
      if (rawData is Map) {
        dataList = (rawData['list'] as List?) ?? [];
        total = rawData['total'] ?? dataList.length;
      }

      dataList = InquiryFilter.applyWithSession(
        dataList,
        sessionBprId: session.bprId,
        sessionKodeKantor: session.kodeKantor,
        sentBprId: true,
        sentKodeKantor: (filterKdKantor ?? '').isNotEmpty,
      );

      return {
        "value": _mapCode(decoded),
        "message": _mapMessage(decoded),
        "data": dataList,
        "total": total,
      };
    } catch (e) {
      if (kDebugMode) print("ERROR INQUIRY TELLER-DB: $e");
      return {"value": 0, "message": _dioErrorMessage(e), "data": []};
    }
  }

  static Future<Map<String, dynamic>> inquiryTeller({
    String? filterNama,
    String? filterUserId,
    String? filterKdKantor,
    String? filterStatus,
    String? bprId,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'filter': {
          'bpr_id': bprId ?? session.bprId,
          if ((filterNama     ?? '').isNotEmpty) 'nama':      filterNama,
          if ((filterUserId   ?? '').isNotEmpty) 'userid':    filterUserId,
          if ((filterKdKantor ?? '').isNotEmpty) 'kd_kantor': filterKdKantor,
          if ((filterStatus   ?? '').isNotEmpty) 'status':    filterStatus,
        },
        'page':  page,
        'size':  size,
        'sort':  'id',
        'order': 'desc',
      };

      if (kDebugMode) {
        print('INQUIRY TELLER URL : ${NetworkURL.inquiryTeller()}');
        print('INQUIRY TELLER BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.inquiryTeller(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('INQUIRY TELLER RESP: $decoded');

      final rawData   = decoded['data'];
      List<dynamic> dataList = [];
      int total = 0;

      if (rawData is Map) {
        if (rawData['items'] is List) {
          dataList = rawData['items'] as List;
        } else if (rawData['data'] is List) {
          dataList = rawData['data'] as List;
        }
        total = rawData['pagination']?['total_items'] ?? rawData['total'] ?? 0;
      } else if (rawData is List) {
        dataList = rawData;
        total    = dataList.length;
      }

      dataList = InquiryFilter.applyWithSession(
        dataList,
        sessionBprId: session.bprId,
        sessionKodeKantor: session.kodeKantor,
        sentBprId: true,
        sentKodeKantor: (filterKdKantor ?? '').isNotEmpty,
      );

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
        'data':    dataList,
        'total':   total,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR INQUIRY TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e), 'data': [], 'total': 0};
    }
  }

  // ==================== INSERT ====================
  static Future<Map<String, dynamic>> insertTeller({
    required String userId,
    required String password,
    required String nama,
    required String noHp,
    required String nip,
    required String kdKantor,
    required String sbbTeller,
    required String namaSbb,
    required String tanggalExpired,
    required String batch, 
    String? bprId,
    String? namaKantor,
    String? hrmEmployeeId,
    bool hakOtor = false,
    List<FasilitasModel>? akses,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'userid':           userId,
        'password':         password,
        'nama':             nama,
        'nohp':             noHp,
        'nip':              nip,
        'kd_kantor':        kdKantor,
        'nama_kantor':      namaKantor ?? '',
        'hrm_employee_id':  hrmEmployeeId ?? '',
        'sbb_teller':       sbbTeller,
        'nama_sbb':         namaSbb,
        'tanggal_expired':  tanggalExpired,
        'Batch': batch,
        'hak_otor':         hakOtor ? 'Y' : 'N',
        'bpr_id':           bprId ?? session.bprId,
        'userlogin':        session.usersId,
        'term':             'WEB',
        // Fasilitas/menu akses khusus teller (type "TELLER" di master
        // fasilitas), sama pola dengan akses di User Access.
        'akses': (akses ?? []).map((f) => {
          'Modul': f.modul,
          'Menu': f.menu,
          'Submenu': f.submenu,
          'SubSubmenu': f.subsubmenu,
          'Urut': int.tryParse(f.urut) ?? 0,
          'Flag': true,
        }).toList(),
      };

      if (kDebugMode) {
        print('INSERT TELLER URL : ${NetworkURL.insertTeller()}');
        print('INSERT TELLER BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.insertTeller(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('INSERT TELLER RESP: $decoded');

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR INSERT TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== UPDATE ====================
  static Future<Map<String, dynamic>> updateTeller({
    required String id,
    required String nama,
    required String noHp,
    required String nip,
    required String kdKantor,
    required String sbbTeller,
    required String namaSbb,
    required String tanggalExpired,
    required String batch,
    String? password,
    String? bprId,
    String? namaKantor,
    String? hrmEmployeeId,
    bool hakOtor = false,
    List<FasilitasModel>? akses,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = <String, dynamic>{
        'id':               int.tryParse(id) ?? 0,
        'nama':             nama,
        'nohp':             noHp,
        'nip':              nip,
        'kd_kantor':        kdKantor,
        'nama_kantor':      namaKantor ?? '',
        'hrm_employee_id':  hrmEmployeeId ?? '',
        'sbb_teller':       sbbTeller,
        'nama_sbb':         namaSbb,
        'tanggal_expired':  tanggalExpired,
        'Batch':            batch,
        'hak_otor':         hakOtor ? 'Y' : 'N',
        'bpr_id':           bprId ?? session.bprId,
        'userlogin':        session.usersId,
        'term':             'WEB',
        'akses': (akses ?? []).map((f) => {
          'Modul': f.modul,
          'Menu': f.menu,
          'Submenu': f.submenu,
          'SubSubmenu': f.subsubmenu,
          'Urut': int.tryParse(f.urut) ?? 0,
          'Flag': true,
        }).toList(),
      };

      // password opsional saat edit — kirim hanya jika diisi
      if ((password ?? '').trim().isNotEmpty) {
        body['password'] = password!.trim();
      }

      if (kDebugMode) {
        print('UPDATE TELLER URL : ${NetworkURL.updateTeller()}');
        print('UPDATE TELLER BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.updateTeller(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('UPDATE TELLER RESP: $decoded');

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR UPDATE TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== DELETE ====================
  static Future<Map<String, dynamic>> deleteTeller({
    required String id,
    required String alasan,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'id':        int.tryParse(id) ?? 0,
        'alasan':    alasan,
        'bpr_id':    bprId ?? session.bprId,
        'userlogin': session.usersId,
        'term':      'WEB',
      };

      if (kDebugMode) {
        print('DELETE TELLER URL : ${NetworkURL.deleteTeller()}');
        print('DELETE TELLER BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.deleteTeller(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('DELETE TELLER RESP: $decoded');

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR DELETE TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== BLOKIR ====================
  static Future<Map<String, dynamic>> blokirTeller({
    required String id,
    required String alasan,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'id':        int.tryParse(id) ?? 0,
        'alasan':    alasan,
        'bpr_id':    bprId ?? session.bprId,
        'userlogin': session.usersId,
        'term':      'WEB',
      };

      if (kDebugMode) {
        print('BLOKIR TELLER URL : ${NetworkURL.blokirTeller()}');
        print('BLOKIR TELLER BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.blokirTeller(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('BLOKIR TELLER RESP: $decoded');

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR BLOKIR TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== UNBLOKIR ====================
  static Future<Map<String, dynamic>> unblokirTeller({
    required String id,
    required String alasan,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'id':        int.tryParse(id) ?? 0,
        'alasan':    alasan,
        'bpr_id':    bprId ?? session.bprId,
        'userlogin': session.usersId,
        'term':      'WEB',
      };

      if (kDebugMode) {
        print('UNBLOKIR TELLER URL : ${NetworkURL.unblokirTeller()}');
        print('UNBLOKIR TELLER BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.unblokirTeller(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('UNBLOKIR TELLER RESP: $decoded');

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR UNBLOKIR TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== BUKA TRANSAKSI ====================
  static Future<Map<String, dynamic>> bukaTransaksiTeller({
    required String userId,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'bpr_id':    bprId ?? session.bprId,
        'userid':    userId,
        'userlogin': session.usersId,
        'term':      'WEB',
      };

      if (kDebugMode) {
        print('BUKA TRANSAKSI TELLER URL : ${NetworkURL.bukaTransaksiTeller()}');
        print('BUKA TRANSAKSI TELLER BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.bukaTransaksiTeller(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('BUKA TRANSAKSI TELLER RESP: $decoded');

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR BUKA TRANSAKSI TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== TUTUP TRANSAKSI ====================
  static Future<Map<String, dynamic>> tutupTransaksiTeller({
    required String userId,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'bpr_id':    bprId ?? session.bprId,
        'userid':    userId,
        'userlogin': session.usersId,
        'term':      'WEB',
      };

      if (kDebugMode) {
        print('TUTUP TRANSAKSI TELLER URL : ${NetworkURL.tutupTransaksiTeller()}');
        print('TUTUP TRANSAKSI TELLER BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.tutupTransaksiTeller(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('TUTUP TRANSAKSI TELLER RESP: $decoded');

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR TUTUP TRANSAKSI TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== LIMIT TRANSAKSI ====================
  static Future<Map<String, dynamic>> getLimitTeller({
    String? userId,
    String? noHp,
    String? backendId,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = <String, dynamic>{'bpr_id': bprId ?? session.bprId};
      if (userId != null && userId.trim().isNotEmpty) body['userid'] = userId.trim();
      if (noHp != null && noHp.trim().isNotEmpty) body['nohp'] = noHp.trim();
      final parsedBackendId = int.tryParse(backendId ?? '') ?? 0;
      if (parsedBackendId > 0) body['backend_id'] = parsedBackendId;

      if (kDebugMode) {
        print('LIMIT INQUIRY TELLER URL : ${NetworkURL.limitInquiryTeller()}');
        print('LIMIT INQUIRY TELLER BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.limitInquiryTeller(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('LIMIT INQUIRY TELLER RESP: $decoded');

      final rawData = decoded['data'];
      final limits  = (rawData is Map ? rawData['limits'] : null) ?? [];

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
        'limits':  limits is List ? limits : [],
      };
    } catch (e) {
      if (kDebugMode) print('ERROR LIMIT INQUIRY TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e), 'limits': []};
    }
  }

  static Future<Map<String, dynamic>> saveLimitTeller({
    String? userId,
    String? noHp,
    String? backendId,
    required double minSetorTunai,
    required double limitSetorTunai,
    required double maxSetorTunai,
    required double minTarikTunai,
    required double limitTarikTunai,
    required double maxTarikTunai,
    required double minPindahBuku,
    required double limitPindahBuku,
    required double maxPindahBuku,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = <String, dynamic>{
        'bpr_id':    bprId ?? session.bprId,
        'userlogin': session.usersId,
        'term':      'WEB',
        'limits': [
          {'tcode': '1000', 'min_nominal': minSetorTunai,  'limit_nominal': limitSetorTunai,  'max_nominal': maxSetorTunai},
          {'tcode': '1100', 'min_nominal': minTarikTunai,  'limit_nominal': limitTarikTunai,  'max_nominal': maxTarikTunai},
          {'tcode': '2300', 'min_nominal': minPindahBuku,  'limit_nominal': limitPindahBuku,  'max_nominal': maxPindahBuku},
        ],
      };
      if (userId != null && userId.trim().isNotEmpty) body['userid'] = userId.trim();
      if (noHp != null && noHp.trim().isNotEmpty) body['nohp'] = noHp.trim();
      final parsedBackendId = int.tryParse(backendId ?? '') ?? 0;
      if (parsedBackendId > 0) body['backend_id'] = parsedBackendId;

      if (kDebugMode) {
        print('LIMIT SAVE TELLER URL : ${NetworkURL.limitSaveTeller()}');
        print('LIMIT SAVE TELLER BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.limitSaveTeller(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('LIMIT SAVE TELLER RESP: $decoded');

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR LIMIT SAVE TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== RESET PASSWORD ====================
  static Future<Map<String, dynamic>> resetPasswordTeller({
    String? userId,
    String? noHp,
    String? backendId,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = <String, dynamic>{
        'userlogin': session.usersId,
        'term':      'WEB',
        'bpr_id':    bprId ?? session.bprId,
      };
      if (userId != null && userId.trim().isNotEmpty) body['userid'] = userId.trim();
      if (noHp != null && noHp.trim().isNotEmpty) body['nohp'] = noHp.trim();
      final parsedBackendId = int.tryParse(backendId ?? '') ?? 0;
      if (parsedBackendId > 0) body['backend_id'] = parsedBackendId;

      if (kDebugMode) {
        print('RESET PASSWORD TELLER URL : ${NetworkURL.resetPasswordTeller()}');
        print('RESET PASSWORD TELLER BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.resetPasswordTeller(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('RESET PASSWORD TELLER RESP: $decoded');

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR RESET PASSWORD TELLER: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }
}