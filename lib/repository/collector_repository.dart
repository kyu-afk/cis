import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/network.dart';
import 'package:intl/intl.dart';
import '../pref/pref.dart';

class CollectorRepository {
  static Future<Dio> _dioWithToken() => ApiClient.buildProtected();

  static dynamic _safeDecode(dynamic data) {
    if (data is String) return jsonDecode(data);
    return data;
  }

  static int _mapCode(dynamic response) {
    if (response is Map) {
      final status = (response['status'] ?? '').toString().toLowerCase();
      if (status == 'success') return 1;
    }
    final code = (response['code'] ?? '').toString();
    return code == '000' || code == '200' || code == '201' ? 1 : 0;
  }

  static String _mapMessage(dynamic response) {
    return (response['message'] ?? '').toString();
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

  /// Jalankan sync-repair: bandingkan backend vs cis_petugas, auto-link backend_id via nohp.
  static Future<Map<String, dynamic>> syncRepairCollector({
    String? bprId,
    bool autoLink = true,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {
        'bpr_id': bprId ?? session.bprId,
        'page': 1,
        'size': 5000,
        'auto_link': autoLink,
      };
      final response = await dio.post(NetworkURL.syncRepairCollector(), data: jsonEncode(body));
      final decoded = _safeDecode(response.data);
      return {
        'value': _mapCode(decoded),
        'message': _mapMessage(decoded),
        'data': decoded['data'],
      };
    } catch (e) {
      return {'value': 0, 'message': _dioErrorMessage(e), 'data': null};
    }
  }

  /// Backfill cis_petugas untuk data legacy (butuh userid + password per item).
  static Future<Map<String, dynamic>> syncBackfillCollector({
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final dio = await _dioWithToken();
      final response = await dio.post(
        NetworkURL.syncBackfillCollector(),
        data: jsonEncode({'items': items}),
      );
      final decoded = _safeDecode(response.data);
      return {
        'value': _mapCode(decoded),
        'message': _mapMessage(decoded),
        'data': decoded['data'],
      };
    } catch (e) {
      return {'value': 0, 'message': _dioErrorMessage(e), 'data': null};
    }
  }

  // ==================== INQUIRY COLLECTOR ====================
  static Future<Map<String, dynamic>> resolveUserIdCollector({
    String? userId,
    String? noHp,
    String? backendId,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = <String, dynamic>{
        'bpr_id': bprId ?? session.bprId,
      };
      if (userId != null && userId.trim().isNotEmpty) body['userid'] = userId.trim();
      if (noHp != null && noHp.trim().isNotEmpty) body['nohp'] = noHp.trim();
      final parsedBackendId = int.tryParse(backendId ?? '') ?? 0;
      if (parsedBackendId > 0) body['backend_id'] = parsedBackendId;

      if (kDebugMode) {
        print('RESOLVE USERID COLLECTOR URL: ${NetworkURL.resolveUserIdCollector()}');
        print('RESOLVE USERID COLLECTOR BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.resolveUserIdCollector(), data: jsonEncode(body));
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print('RESOLVE USERID COLLECTOR RESP: $decoded');

      final rawData = decoded['data'];
      final resolved = rawData is Map ? (rawData['userid'] ?? '').toString() : '';

      return {
        'value': _mapCode(decoded),
        'message': _mapMessage(decoded),
        'userid': resolved,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR RESOLVE USERID COLLECTOR: $e');
      return {'value': 0, 'message': _dioErrorMessage(e), 'userid': ''};
    }
  }

  // ==================== INQUIRY COLLECTOR ====================
  static Future<Map<String, dynamic>> inquiryCollector({
    String? filterNama,
    String? filterKodePetugas,
    String? filterKdKantor,
    String? filterStatus,
    String? bprId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {
        "userlogin": session.usersId,
        "term": "WEB",
        "filter": {
          "bpr_id": bprId ?? session.bprId,
          "nama": filterNama ?? "",
          "kd_collector": filterKodePetugas ?? "",
          "kd_kantor": filterKdKantor ?? "",
          "status": filterStatus ?? "",
        },
        "page": page,
        "size": limit,
        "sort": "nama",
        "order": "asc",
      };
      if (kDebugMode) {
        print("INQUIRY COLLECTOR URL: ${NetworkURL.inquiryCollector()}");
        print("INQUIRY COLLECTOR BODY: ${jsonEncode(body)}");
      }
      final response = await dio.post(NetworkURL.inquiryCollector(), data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("INQUIRY COLLECTOR RESPONSE: $decoded");

      final rawData = decoded['data'];
      List<dynamic> dataList = [];
      int total = 0;
      
      if (rawData is Map) {
        if (rawData['items'] is List) {
          dataList = rawData['items'] as List;
        } else if (rawData['data'] is List) {
          dataList = rawData['data'] as List;
        }
        if (rawData['pagination'] != null) {
          total = rawData['pagination']['total_items'] ?? 0;
        } else {
          total = rawData['total'] ?? 0;
        }
      } else if (rawData is List) {
        dataList = rawData;
        total = dataList.length;
      }
      
      if (kDebugMode) {
        print("PARSED DATA LIST LENGTH: ${dataList.length}");
        print("PARSED TOTAL: $total");
      }
      
      return {
        "value": _mapCode(decoded),
        "message": _mapMessage(decoded),
        "data": dataList,
        "total": total,
        "code": decoded['code'],
        "status": decoded['status'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR INQUIRY COLLECTOR: $e");
      return {"value": 0, "message": "Terjadi kesalahan: $e", "data": []};
    }
  }

  // ==================== SEARCH PETUGAS BY NAMA ====================
  static Future<Map<String, dynamic>> searchPetugasByNama({
    required String nama,
  }) async {
    final result = await inquiryCollector(filterNama: nama, limit: 10);
    if (kDebugMode) {
      print('=== SEARCH PETUGAS ===');
      print('nama: $nama');
      print('value: ${result['value']}');
      print('total: ${result['total']}');
      print('data: ${result['data']}');
      print('message: ${result['message']}');
    }
    return result;
  }

  // ==================== INSERT COLLECTOR ====================
  static Future<Map<String, dynamic>> insertCollector({
    required String userId,
    required String password,
    required String nama,
    required String noHp,
    required String nip,
    required String kdKantor,
    required String kodePetugas,
    required String noSbb,
    required String namaSbb,
    String? bprId,
    Map<String, dynamic>? limitData,
    Map<String, bool>? aksesData,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = <String, dynamic>{
        "bpr_id": bprId ?? session.bprId,
        "userlogin": session.usersId,
        "term": "WEB",
        "userid": userId,
        "password": password,
        "nama": nama,
        "nohp": noHp,
        "nip": nip,
        "kd_kantor": kdKantor,
        "kd_collector": kodePetugas,
        "nosbb": noSbb,
        "nama_sbb": namaSbb,
      };
      if (aksesData != null) {
        body['akses_setor'] = (aksesData['akses_setor'] == true) ? 'Y' : 'N';
        body['akses_tartun'] = (aksesData['akses_tartun'] == true) ? 'Y' : 'N';
        body['akses_transfer'] = (aksesData['akses_transfer'] == true) ? 'Y' : 'N';
        body['akses_ppob'] = (aksesData['akses_ppob'] == true) ? 'Y' : 'N';
        body['akses_kredit'] = (aksesData['akses_kredit'] == true) ? 'Y' : 'N';
      }
      if (limitData != null) {
        limitData.forEach((key, value) {
          body[key] = value; // null = akses tidak aktif, backend akan reset ke 0
        });
      }

      if (kDebugMode) print("INSERT COLLECTOR BODY: ${jsonEncode(body)}");
      final response = await dio.post(NetworkURL.insertCollector(), data: jsonEncode(body));
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("INSERT COLLECTOR RESPONSE: $decoded");
      return {
        "value": _mapCode(decoded),
        "message": _mapMessage(decoded),
        "data": decoded['data'],
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR INSERT COLLECTOR: $e");
      return {"value": 0, "message": _dioErrorMessage(e)};
    }
  }

  // ==================== UPDATE COLLECTOR ====================
  static Future<Map<String, dynamic>> updateCollector({
    required String id,
    required String userId,
    required String nama,
    required String noHp,
    required String nip,
    required String kdKantor,
    required String kodePetugas,
    required String noSbb,
    required String namaSbb,
    String? password,
    String? bprId,
    Map<String, dynamic>? limitData,
    Map<String, bool>? aksesData,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = <String, dynamic>{
        "bpr_id": bprId ?? session.bprId,
        "userlogin": session.usersId,
        "term": "WEB",
        "id": id,
        "userid": userId,
        "nama": nama,
        "nohp": noHp,
        "nip": nip,
        "kd_kantor": kdKantor,
        "kd_collector": kodePetugas,
        "nosbb": noSbb,
        "nama_sbb": namaSbb,
      };
      if (password != null && password.isNotEmpty) {
        body['password'] = password;
      }
      if (aksesData != null) {
        body['akses_setor'] = (aksesData['akses_setor'] == true) ? 'Y' : 'N';
        body['akses_tartun'] = (aksesData['akses_tartun'] == true) ? 'Y' : 'N';
        body['akses_transfer'] = (aksesData['akses_transfer'] == true) ? 'Y' : 'N';
        body['akses_ppob'] = (aksesData['akses_ppob'] == true) ? 'Y' : 'N';
        body['akses_kredit'] = (aksesData['akses_kredit'] == true) ? 'Y' : 'N';
      }
      if (limitData != null) {
        limitData.forEach((key, value) {
          body[key] = value; // null = akses tidak aktif, backend akan reset ke 0
        });
      }

      if (kDebugMode) print("UPDATE COLLECTOR BODY: ${jsonEncode(body)}");
      final response = await dio.post(NetworkURL.updateCollector(), data: jsonEncode(body));
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("UPDATE COLLECTOR RESPONSE: $decoded");
      return {
        "value": _mapCode(decoded),
        "message": _mapMessage(decoded),
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR UPDATE COLLECTOR: $e");
      return {"value": 0, "message": _dioErrorMessage(e)};
    }
  }

  // ==================== DELETE COLLECTOR ====================
  static Future<Map<String, dynamic>> deleteCollector({
    required String id,
    required String alasan,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {
        "bpr_id": bprId ?? session.bprId,
        "userlogin": session.usersId,
        "term": "WEB",
        "id": int.tryParse(id) ?? 0,
        "alasan": alasan,
      };
      if (kDebugMode) print("DELETE COLLECTOR BODY: ${jsonEncode(body)}");
      final response = await dio.post(NetworkURL.deleteCollector(), data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("DELETE COLLECTOR RESPONSE: $decoded");
      return {
        "value": _mapCode(decoded),
        "message": _mapMessage(decoded),
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR DELETE COLLECTOR: $e");
      return {"value": 0, "message": _dioErrorMessage(e)};
    }
  }

  // ==================== BLOKIR COLLECTOR ====================
  static Future<Map<String, dynamic>> blokirCollector({
    required String id,
    required String alasan,
    required String userLogin,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {
        "bpr_id": bprId ?? session.bprId,
        "userlogin": userLogin.isNotEmpty ? userLogin : session.usersId,
        "term": "WEB",
        "id": int.tryParse(id) ?? 0,
        "alasan": alasan,
      };
      if (kDebugMode) print("BLOKIR COLLECTOR BODY: ${jsonEncode(body)}");
      final response = await dio.post(NetworkURL.blokirCollector(), data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("BLOKIR COLLECTOR RESPONSE: $decoded");
      return {
        "value": _mapCode(decoded),
        "message": _mapMessage(decoded),
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR BLOKIR COLLECTOR: $e");
      return {"value": 0, "message": _dioErrorMessage(e)};
    }
  }

  // ==================== UNBLOKIR COLLECTOR ====================
  static Future<Map<String, dynamic>> unblokirCollector({
    required String id,
    required String alasan,
    required String userLogin,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {
        "bpr_id": bprId ?? session.bprId,
        "userlogin": userLogin.isNotEmpty ? userLogin : session.usersId,
        "term": "WEB",
        "id": int.tryParse(id) ?? 0,
        "alasan": alasan,
      };
      if (kDebugMode) print("UNBLOKIR COLLECTOR BODY: ${jsonEncode(body)}");
      final response = await dio.post(NetworkURL.unblokirCollector(), data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("UNBLOKIR COLLECTOR RESPONSE: $decoded");
      return {
        "value": _mapCode(decoded),
        "message": _mapMessage(decoded),
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR UNBLOKIR COLLECTOR: $e");
      return {"value": 0, "message": _dioErrorMessage(e)};
    }
  }

  // ==================== GENERATE MPIN ====================
  static Future<Map<String, dynamic>> generateMpin({
    required String collectorId,
    required String noSbb,
    required String kdKantor,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {
        "id": int.tryParse(collectorId) ?? 0,
        "bpr_id": bprId ?? session.bprId,
        "userlogin": session.usersId,
        "term": "WEB",
      };
      if (kDebugMode) print("GENERATE MPIN BODY: ${jsonEncode(body)}");
      final response = await dio.post(NetworkURL.generateMpin(), data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("GENERATE MPIN RESPONSE: $decoded");
      return {
        "value": _mapCode(decoded),
        "message": _mapMessage(decoded),
        "mpin": (decoded['data'] is Map) ? (decoded['data']['mpin'] ?? '') : '',
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR GENERATE MPIN: $e");
      return {"value": 0, "message": _dioErrorMessage(e), "mpin": ""};
    }
  }

  // ==================== REGENERATE MPIN ====================
  static Future<Map<String, dynamic>> regenerateMpin({
    required String collectorId,
    required String noSbb,
    required String kdKantor,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {
        "id": int.tryParse(collectorId) ?? 0,
        "bpr_id": bprId ?? session.bprId,
        "userlogin": session.usersId,
        "term": "WEB",
      };
      if (kDebugMode) print("REGENERATE MPIN BODY: ${jsonEncode(body)}");
      final response = await dio.post(NetworkURL.regenerateMpin(), data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("REGENERATE MPIN RESPONSE: $decoded");
      return {
        "value": _mapCode(decoded),
        "message": _mapMessage(decoded),
        "mpin": (decoded['data'] is Map) ? (decoded['data']['mpin'] ?? '') : '',
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR REGENERATE MPIN: $e");
      return {"value": 0, "message": _dioErrorMessage(e), "mpin": ""};
    }
  }

  // ==================== RESET MPIN ====================
  static Future<Map<String, dynamic>> resetMpin({
    required String collectorId,
    required String noSbb,
    required String kdKantor,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {
        "id": int.tryParse(collectorId) ?? 0,
        "bpr_id": bprId ?? session.bprId,
        "userlogin": session.usersId,
        "term": "WEB",
      };
      if (kDebugMode) print("RESET MPIN BODY: ${jsonEncode(body)}");
      final response = await dio.post(NetworkURL.resetMpin(), data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("RESET MPIN RESPONSE: $decoded");
      return {
        "value": _mapCode(decoded),
        "message": _mapMessage(decoded),
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR RESET MPIN: $e");
      return {"value": 0, "message": _dioErrorMessage(e)};
    }
  }

  // ==================== CETAK MPIN ====================
  static Future<Map<String, dynamic>> cetakMpin({
    required String collectorId,
    required String noSbb,
    required String kdKantor,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();
      final body = {
        "id": int.tryParse(collectorId) ?? 0,
        "bpr_id": bprId ?? session.bprId,
        "userlogin": session.usersId,
        "term": "WEB",
      };
      if (kDebugMode) print("CETAK MPIN BODY: ${jsonEncode(body)}");
      final response = await dio.post(NetworkURL.cetakMpin(), data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("CETAK MPIN RESPONSE: $decoded");
      return {
        "value": _mapCode(decoded),
        "message": _mapMessage(decoded),
        "mpin": (decoded['data'] is Map) ? (decoded['data']['mpin'] ?? '') : '',
        "print_url": (decoded['data'] is Map) ? (decoded['data']['print_url'] ?? '') : '',
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR CETAK MPIN: $e");
      return {"value": 0, "message": _dioErrorMessage(e), "mpin": ""};
    }
  }

  // ==================== BUKA TRANSAKSI ====================
  static Future<Map<String, dynamic>> bukaTransaksiCollector({
    required String noHp,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        "bpr_id":    bprId ?? session.bprId,
        "nohp":      noHp,
        "userlogin": session.usersId,
        "term":      "WEB",
      };

      if (kDebugMode) {
        print("BUKA TRANSAKSI COLLECTOR URL : ${NetworkURL.bukaTransaksiCollector()}");
        print("BUKA TRANSAKSI COLLECTOR BODY: ${jsonEncode(body)}");
      }

      final response = await dio.post(NetworkURL.bukaTransaksiCollector(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print("BUKA TRANSAKSI COLLECTOR RESP: $decoded");

      return {
        "value":   _mapCode(decoded),
        "message": _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print("ERROR BUKA TRANSAKSI COLLECTOR: $e");
      return {"value": 0, "message": _dioErrorMessage(e)};
    }
  }

  // ==================== TUTUP TRANSAKSI ====================
  static Future<Map<String, dynamic>> tutupTransaksiCollector({
    required String noHp,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        "bpr_id":    bprId ?? session.bprId,
        "nohp":      noHp,
        "userlogin": session.usersId,
        "term":      "WEB",
      };

      if (kDebugMode) {
        print("TUTUP TRANSAKSI COLLECTOR URL : ${NetworkURL.tutupTransaksiCollector()}");
        print("TUTUP TRANSAKSI COLLECTOR BODY: ${jsonEncode(body)}");
      }

      final response = await dio.post(NetworkURL.tutupTransaksiCollector(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print("TUTUP TRANSAKSI COLLECTOR RESP: $decoded");

      return {
        "value":   _mapCode(decoded),
        "message": _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print("ERROR TUTUP TRANSAKSI COLLECTOR: $e");
      return {"value": 0, "message": _dioErrorMessage(e)};
    }
  }

  // ==================== RESET PASSWORD ====================
  static Future<Map<String, dynamic>> resetPasswordCollector({
    String? userId,
    String? noHp,
    String? backendId,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = <String, dynamic>{
        "userlogin": session.usersId,
        "term":      "WEB",
        "bpr_id":    bprId ?? session.bprId,
      };
      if (userId != null && userId.trim().isNotEmpty) body['userid'] = userId.trim();
      if (noHp != null && noHp.trim().isNotEmpty) body['nohp'] = noHp.trim();
      final parsedBackendId = int.tryParse(backendId ?? '') ?? 0;
      if (parsedBackendId > 0) body['backend_id'] = parsedBackendId;

      if (kDebugMode) {
        print("RESET PASSWORD COLLECTOR URL : ${NetworkURL.resetPasswordCollector()}");
        print("RESET PASSWORD COLLECTOR BODY: ${jsonEncode(body)}");
      }

      final response = await dio.post(NetworkURL.resetPasswordCollector(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print("RESET PASSWORD COLLECTOR RESP: $decoded");

      return {
        "value":   _mapCode(decoded),
        "message": _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print("ERROR RESET PASSWORD COLLECTOR: $e");
      return {"value": 0, "message": _dioErrorMessage(e)};
    }
  }

  // ==================== LIMIT TRANSAKSI PER-TCODE (DINAMIS) ====================
  // Pola sama persis dengan TellerRepository.getLimitTeller/saveLimitTeller.
  static Future<Map<String, dynamic>> getLimitPetugas({
    String? userId,
    String? noHp,
    String? backendId,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = <String, dynamic>{
        'bpr_id': bprId ?? session.bprId,
      };
      if (userId != null && userId.trim().isNotEmpty) body['userid'] = userId.trim();
      if (noHp != null && noHp.trim().isNotEmpty) body['nohp'] = noHp.trim();
      final parsedBackendId = int.tryParse(backendId ?? '') ?? 0;
      if (parsedBackendId > 0) body['backend_id'] = parsedBackendId;

      if (kDebugMode) {
        print('LIMIT INQUIRY PETUGAS URL : ${NetworkURL.limitInquiryCollector()}');
        print('LIMIT INQUIRY PETUGAS BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.limitInquiryCollector(), data: jsonEncode(body));
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('LIMIT INQUIRY PETUGAS RESP: $decoded');

      final rawData = decoded['data'];
      final limits = (rawData is Map ? rawData['limits'] : null) ?? [];
      final resolvedUserId = rawData is Map ? (rawData['userid'] ?? '').toString() : '';

      return {
        'value': _mapCode(decoded),
        'message': _mapMessage(decoded),
        'limits': limits is List ? limits : [],
        'userid': resolvedUserId,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR LIMIT INQUIRY PETUGAS: $e');
      return {'value': 0, 'message': _dioErrorMessage(e), 'limits': [], 'userid': ''};
    }
  }

  static Future<Map<String, dynamic>> saveLimitPetugas({
    String? userId,
    String? noHp,
    String? backendId,
    required List<Map<String, dynamic>> limits,
    String? bprId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = <String, dynamic>{
        'bpr_id': bprId ?? session.bprId,
        'userlogin': session.usersId,
        'term': 'WEB',
        'limits': limits,
      };
      if (userId != null && userId.trim().isNotEmpty) body['userid'] = userId.trim();
      if (noHp != null && noHp.trim().isNotEmpty) body['nohp'] = noHp.trim();
      final parsedBackendId = int.tryParse(backendId ?? '') ?? 0;
      if (parsedBackendId > 0) body['backend_id'] = parsedBackendId;

      if (kDebugMode) {
        print('LIMIT SAVE PETUGAS URL : ${NetworkURL.limitSaveCollector()}');
        print('LIMIT SAVE PETUGAS BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.limitSaveCollector(), data: jsonEncode(body));
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('LIMIT SAVE PETUGAS RESP: $decoded');

      return {
        'value': _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR LIMIT SAVE PETUGAS: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== HELPERS ====================
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
}