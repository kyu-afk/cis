import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/network.dart';
import '../pref/pref.dart';

class SetupLimitRepository {
  static Future<Dio> _dioWithToken() => ApiClient.buildProtected();

  static dynamic _safeDecode(dynamic data) {
    if (data is String) return jsonDecode(data);
    return data;
  }

  static int _mapCode(dynamic response) {
    final code = (response['code'] ?? '').toString();
    return code == '000' || code == '200' ? 1 : 0;
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

  // ==================== INQUIRY ====================
  static Future<Map<String, dynamic>> inquirySetupLimit({
    Map<String, dynamic>? filter,
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = <String, dynamic>{
        'bpr_id': session.bprId,
        if (filter != null) ...filter,
      };

      if (kDebugMode) {
        print('INQUIRY SETUP-LIMIT URL : ${NetworkURL.inquirySetupLimit()}');
        print('INQUIRY SETUP-LIMIT BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.inquirySetupLimit(), data: body);
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('INQUIRY SETUP-LIMIT RESP: $decoded');

      final rawData = decoded['data'];
      List<dynamic> dataList = [];

      if (rawData is List) {
        dataList = rawData;
      } else if (rawData is Map) {
        if (rawData['items'] is List) {
          dataList = rawData['items'] as List;
        } else if (rawData['data'] is List) {
          dataList = rawData['data'] as List;
        } else {
          // Mungkin data langsung berupa satu object (single row limit global)
          dataList = [rawData];
        }
      }

      return {
        'value': _mapCode(decoded),
        'message': _mapMessage(decoded),
        'data': dataList,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR INQUIRY SETUP-LIMIT: $e');
      return {'value': 0, 'message': _dioErrorMessage(e), 'data': []};
    }
  }

 // ==================== EDIT ====================
  static Future<Map<String, dynamic>> editSetupLimit({
    double limitTarikTunaiMin = 0,
    double limitSetorTunaiMin = 0,
    double limitTransferMin = 0,
    double limitPpobMin = 0,
    double limitByrLoanMin = 0,
    double limitSaldoHarian = 0,
    double limitPendingSetor = 0,
    double limitPendingKredit = 0,
    double limitPendingTrf = 0,
    double limitPendingTarikTunai = 0,
    double limitPendingPpob = 0,       
    double limitTarikTunaiMax = 0,
    double limitSetorTunaiMax = 0,
    double limitTransferMax = 0,
    double limitPpobMax = 0,
    double limitByrLoanMax = 0,
    // ==================== TAMBAH PARAMETER AKSES ====================
    String aksesTarikTunai = 'N',
    String aksesSetor = 'N',
    String aksesTransfer = 'N',
    String aksesPpob = 'N',
    String aksesKredit = 'N',
  }) async {
    try {
      final dio = await _dioWithToken();
      final session = await Pref().getUsers();

      final body = {
        'bpr_id': session.bprId,
        'userlogin': session.usersId,
        'term': 'WEB',
        // Limit fields
        'limit_tarik_tunai_trx_min': limitTarikTunaiMin,
        'limit_setor_tunai_trx_min': limitSetorTunaiMin,
        'limit_transfer_trx_min': limitTransferMin,
        'limit_ppob_trx_min': limitPpobMin,
        'limit_byrloan_trx_min': limitByrLoanMin,
        'limit_saldo_harian': limitSaldoHarian,
        'limit_pending_setor': limitPendingSetor,
        'limit_pending_kredit': limitPendingKredit,
        'limit_pending_trf': limitPendingTrf,
        'limit_pending_tarik_tunai': limitPendingTarikTunai,
        'limit_pending_ppob': limitPendingPpob,    
        'limit_tarik_tunai_trx_max': limitTarikTunaiMax,
        'limit_setor_tunai_trx_max': limitSetorTunaiMax,
        'limit_transfer_trx_max': limitTransferMax,
        'limit_ppob_trx_max': limitPpobMax,
        'limit_byrloan_trx_max': limitByrLoanMax,
        // ==================== TAMBAH AKSES FIELDS ====================
        'akses_tartun': aksesTarikTunai,
        'akses_setor': aksesSetor,
        'akses_transfer': aksesTransfer,
        'akses_ppob': aksesPpob,
        'akses_kredit': aksesKredit,
      };

      if (kDebugMode) {
        print('EDIT SETUP-LIMIT URL : ${NetworkURL.editSetupLimit()}');
        print('EDIT SETUP-LIMIT BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.editSetupLimit(), data: body);
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('EDIT SETUP-LIMIT RESP: $decoded');

      return {
        'value': _mapCode(decoded),
        'message': _mapMessage(decoded),
      };
    } catch (e) {
      if (kDebugMode) print('ERROR EDIT SETUP-LIMIT: $e');
      return {'value': 0, 'message': _dioErrorMessage(e)};
    }
  }
}