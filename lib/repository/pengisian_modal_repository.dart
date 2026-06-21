import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../network/network.dart';
import '../pref/pref.dart';

class PengisianModalRepository {
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
          final fields = d['data']?['fields'];
          if (fields is Map && fields.isNotEmpty) {
            final details = fields.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join('\n');
            final baseMsg = (d['message'] ?? '').toString().trim();
            return baseMsg.isNotEmpty ? '$baseMsg\n$details' : details;
          }
          final msg = (d['message'] ?? '').toString().trim();
          if (msg.isNotEmpty) return msg;
        }
      } catch (_) {}
    }
    return 'Terjadi kesalahan, silakan coba lagi.';
  }

  // ==================== INQUIRY ====================
  static Future<Map<String, dynamic>> inquiryPengisianModal({
    String? filterNoHp,
    String? filterNoReff,
    String? filterStatus,
    String? bprId,
    int page = 1,
    int size = 50,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'filter': {
          'bpr_id': bprId ?? session.bprId,
          if ((filterNoHp   ?? '').isNotEmpty) 'nohp':   filterNoHp,
          if ((filterNoReff ?? '').isNotEmpty) 'noreff': filterNoReff,
          if ((filterStatus ?? '').isNotEmpty) 'status': filterStatus,
        },
        'page':  page,
        'size':  size,
        'sort':  'id',
        'order': 'desc',
      };

      if (kDebugMode) {
        print('INQUIRY PENGISIAN MODAL URL : ${NetworkURL.inquiryPengisianModal()}');
        print('INQUIRY PENGISIAN MODAL BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.inquiryPengisianModal(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('INQUIRY PENGISIAN MODAL RESP: $decoded');

      final rawData = decoded['data'];
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

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
        'data':    dataList,
        'total':   total,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR INQUIRY PENGISIAN MODAL: $e');
      return {'value': 0, 'message': _dioErrorMessage(e), 'data': [], 'total': 0};
    }
  }

  // ==================== ADD ====================
static Future<Map<String, dynamic>> addPengisianModal({
  required String noHp,
  required double amount,
  String? noReff,
  String? keterangan,
  String? bprId,
}) async {
  try {
    final dio     = await _dioWithToken();
    final session = await Pref().getUsers();

    final tglTrans = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    
    // Generate RRN menggunakan mikrotime (microseconds since epoch)
    final rrn = DateTime.now().microsecondsSinceEpoch.toString();

    final body = {
      'bpr_id':     bprId ?? session.bprId,
      'nohp':       noHp,
      'amount':     amount,
      'noreff':     noReff ?? rrn,
      'tgl_trans':  tglTrans,
      'keterangan': keterangan ?? '',
      'userlogin':  session.usersId,
      'term':       'WEB',
    };

    if (kDebugMode) {
      print('ADD PENGISIAN MODAL URL : ${NetworkURL.addPengisianModal()}');
      print('ADD PENGISIAN MODAL BODY: ${jsonEncode(body)}');
      print('RRN: $rrn');
    }

    final response = await dio.post(NetworkURL.addPengisianModal(), data: body);
    final decoded  = _safeDecode(response.data);

    if (kDebugMode) print('ADD PENGISIAN MODAL RESP: $decoded');

    return {
      'value':   _mapCode(decoded),
      'message': _mapMessage(decoded),
      'data':    decoded['data'],
    };
  } catch (e) {
    if (kDebugMode) print('ERROR ADD PENGISIAN MODAL: $e');
    return {'value': 0, 'message': _dioErrorMessage(e)};
  }
}

  // ==================== DELETE ====================
  static Future<Map<String, dynamic>> deletePengisianModal({
    required int id,
    String? alasan,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'id':        id,
        'bpr_id':    bprId ?? session.bprId,
        'alasan':    alasan ?? '',
        'userlogin': session.usersId,
        'term':      'WEB',
      };

      if (kDebugMode) {
        print('DELETE PENGISIAN MODAL URL : ${NetworkURL.deletePengisianModal()}');
        print('DELETE PENGISIAN MODAL BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.deletePengisianModal(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('DELETE PENGISIAN MODAL RESP: $decoded');

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR DELETE PENGISIAN MODAL: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }

  // ==================== TRANSAKSI ====================
  static Future<Map<String, dynamic>> transaksiPengisianModal({
    required String noHp,
    required double amount,
    required String trxCode,
    String? trxType,
    double? biayaLayanan,
    double? feeBpr,
    String? noReff,
    String? keterangan,
    String? bprId,
  }) async {
    try {
      final dio     = await _dioWithToken();
      final session = await Pref().getUsers();

      final tglTrans = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final body = <String, dynamic>{
        'bpr_id':        bprId ?? session.bprId,
        'no_hp':         noHp,
        'trx_code':      trxCode,
        'trx_type':      trxType ?? 'TRX',
        'amount':        amount,
        'biaya_layanan': biayaLayanan ?? 0,
        'fee_bpr':       feeBpr ?? 0,
        'noreff':        noReff ?? '',
        'tgl_trans':     tglTrans,
        'keterangan':    keterangan ?? '',
        'userlogin':     session.usersId,
        'term':          'WEB',
      };

      if (kDebugMode) {
        print('TRANSAKSI PENGISIAN MODAL URL : ${NetworkURL.transaksiPengisianModal()}');
        print('TRANSAKSI PENGISIAN MODAL BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.transaksiPengisianModal(), data: body);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) print('TRANSAKSI PENGISIAN MODAL RESP: $decoded');

      return {
        'value':   _mapCode(decoded),
        'message': _mapMessage(decoded),
        'data':    decoded['data'],
      };
    } catch (e) {
      if (kDebugMode) print('ERROR TRANSAKSI PENGISIAN MODAL: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }
}