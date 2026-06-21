import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/network.dart';
import '../pref/pref.dart';

class SetupTransaksiRepository {
  static Future<Dio> _dioWithToken() => ApiClient.buildProtected();

  static dynamic _safeDecode(dynamic data) {
    if (data is String) return jsonDecode(data);
    return data;
  }

  static int _mapCode(dynamic response) {
    final code = (response['code'] ?? '').toString();
    return (code == '000' || code == '200') ? 1 : 0;
  }

  static String _mapMessage(dynamic response) {
    return (response['message'] ?? '').toString();
  }

  static String _dioErrorMessage(dynamic e) {
    if (e is DioException && e.response?.data != null) {
      try {
        final d = _safeDecode(e.response!.data);
        if (d is Map && d['message'] != null) {
          final msg = d['message'].toString().trim();
          if (msg.isNotEmpty) return msg;
        }
      } catch (_) {}
    }
    return 'Terjadi kesalahan, silakan coba lagi.';
  }

  // ==================== INQUIRY ACCOUNT (debit/kredit) ====================
  static Future<Map<String, dynamic>> inquiryAccount({
    required String noRek,
    required String glJns, // "1" untuk debit, "4" untuk kredit
  }) async {
    try {
      final dio = Dio();
      dio.options.headers['Content-Type'] = 'application/json';

      final session = await Pref().getUsers();

      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final tgl = '${two(now.year % 100)}${two(now.month)}${two(now.day)}${two(now.hour)}${two(now.minute)}${two(now.second)}';
      final rrn = now.microsecondsSinceEpoch.toString();

      final body = {
        'userlogin'   : session.usersId,
        'bpr_id'      : session.bprId,
        'trx_code'    : '0200',
        'trx_type'    : 'TRX',
        'tgl_trans'   : tgl,
        'tgl_transmis': tgl,
        'rrn'         : rrn,
        'no_rek'      : noRek,
        'gl_jns'      : glJns,
      };

      if (kDebugMode) {
        print('INQUIRY ACCOUNT URL : ${NetworkURL.inquiryAccount()}');
        print('INQUIRY ACCOUNT BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.inquiryAccount(), data: jsonEncode(body));
      final res = _safeDecode(response.data);

      if (kDebugMode) print('INQUIRY ACCOUNT RESP: $res');

      return {'value': _mapCode(res), 'message': _mapMessage(res), 'data': res['data']};
    } catch (e) {
      if (kDebugMode) print('INQUIRY ACCOUNT ERR: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== LIST TCODE ====================
  static Future<Map<String, dynamic>> listTcode() async {
    try {
      final dio = Dio();
      dio.options.headers['Content-Type'] = 'application/json';

      final body = {'action': 'list'};

      if (kDebugMode) {
        print('LIST TCODE URL : ${NetworkURL.listTcode()}');
      }

      final response = await dio.post(NetworkURL.listTcode(), data: jsonEncode(body));
      final res = _safeDecode(response.data);

      if (kDebugMode) print('LIST TCODE RESP: $res');

      final code = (res['code'] ?? '').toString();
      if (code == '000') {
        final data = res['data'];
        return {'value': 1, 'data': data is List ? data : []};
      }
      return {'value': 0, 'message': _mapMessage(res)};
    } catch (e) {
      if (kDebugMode) print('LIST TCODE ERR: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== INQUIRY ====================
  static Future<Map<String, dynamic>> inquirySetupTransaksi({
    required String trxCode,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'bpr_id': session.bprId,
        'trx_code': trxCode,
        'page': 1,
        'size': 100,
      };

      if (kDebugMode) {
        print('INQUIRY SETUP-TRANSAKSI URL : ${NetworkURL.inquirySetupTransaksi()}');
        print('INQUIRY SETUP-TRANSAKSI BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.inquirySetupTransaksi(), data: jsonEncode(body));
      final res = _safeDecode(response.data);

      if (kDebugMode) print('INQUIRY SETUP-TRANSAKSI RESP: $res');

      return {'value': _mapCode(res), 'message': _mapMessage(res), 'data': res['data']};
    } catch (e) {
      if (kDebugMode) print('INQUIRY SETUP-TRANSAKSI ERR: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== SAVE ====================
  static Future<Map<String, dynamic>> saveSetupTransaksi({
    required String trxCode,
    required String keterangan,
    required List<Map<String, dynamic>> data,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'bpr_id': session.bprId,
        'kd_bank': session.bprId,
        'trx_code': trxCode,
        'keterangan': keterangan,
        'userlogin': session.usersId,
        'term': 'WEB',
        'data': data,
      };

      if (kDebugMode) {
        print('SAVE SETUP-TRANSAKSI URL : ${NetworkURL.saveSetupTransaksi()}');
        print('SAVE SETUP-TRANSAKSI BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.saveSetupTransaksi(), data: jsonEncode(body));
      final res = _safeDecode(response.data);

      if (kDebugMode) print('SAVE SETUP-TRANSAKSI RESP: $res');

      return {'value': _mapCode(res), 'message': _mapMessage(res)};
    } catch (e) {
      if (kDebugMode) print('SAVE SETUP-TRANSAKSI ERR: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }
}