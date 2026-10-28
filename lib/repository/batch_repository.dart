import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/network.dart';
import '../pref/pref.dart';

// Verifikasi data ke core (lewat web_service_CIS): batch teller/kolektor dan
// kode kolektor. Keduanya wajib lolos sebelum boleh diinsert.
class BatchRepository {
  static dynamic _safeDecode(dynamic data) {
    if (data is String) return jsonDecode(data);
    return data;
  }

  // ==================== VERIFIKASI BATCH ====================
  static Future<Map<String, dynamic>> verifikasiBatch({
    required String batch,
    String? bprId,
  }) =>
      _verifikasiKeCore(
        label: 'Batch',
        url: NetworkURL.inquiryBatch(),
        field: 'batch',
        value: batch,
        bprId: bprId,
      );

  // ==================== VERIFIKASI KODE KOLEKTOR ====================
  static Future<Map<String, dynamic>> verifikasiKodeKolektor({
    required String kdColl,
    String? bprId,
  }) =>
      _verifikasiKeCore(
        label: 'Kode kolektor',
        url: NetworkURL.inquiryKodeCollector(),
        field: 'kd_coll',
        value: kdColl,
        bprId: bprId,
      );

  // Webservice meneruskan ke {URL_CORE}/inquiry dan mengisi trx_code
  // (0400 = batch, 0500 = kode kolektor), trx_type, dan tgl_trans.
  // Response: {"code","message","data":{...,"nama"|"nama_kolektor","status"}}.
  // Sukses hanya kalau code 000 dan status (kalau ada) "aktif".
  static Future<Map<String, dynamic>> _verifikasiKeCore({
    required String label,
    required String url,
    required String field,
    required String value,
    String? bprId,
  }) async {
    try {
      final dio = await ApiClient.buildProtected();
      final session = await Pref().getUsers();

      final body = {
        "bpr_id": bprId ?? session.bprId,
        "rrn": DateTime.now().millisecondsSinceEpoch.toString(),
        field: value,
      };

      if (kDebugMode) {
        print('VERIFIKASI ${label.toUpperCase()} URL: $url');
        print('VERIFIKASI ${label.toUpperCase()} BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(url, data: body);
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('VERIFIKASI ${label.toUpperCase()} RESPONSE: $decoded');

      final code = (decoded is Map ? decoded['code'] : '').toString();
      final message = (decoded is Map ? decoded['message'] : null)?.toString() ?? '';
      final data = decoded is Map && decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : <String, dynamic>{};

      if (code != '000') {
        return {
          "value": 0,
          "message": message.isNotEmpty ? message : '$label tidak ditemukan',
          "data": data,
        };
      }

      // Kode kolektor mengirim "nama_kolektor"; samakan ke "nama" untuk notifier.
      final nama = (data['nama'] ?? data['nama_kolektor'] ?? '').toString();
      data['nama'] = nama;
      final status = (data['status'] ?? '').toString();
      if (status.isNotEmpty && status.toLowerCase() != 'aktif') {
        return {
          "value": 0,
          "message": '$label $value${nama.isNotEmpty ? ' ($nama)' : ''} berstatus "$status", tidak bisa digunakan.',
          "data": data,
        };
      }
      return {
        "value": 1,
        "message": '$label terverifikasi',
        "data": data,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR VERIFIKASI ${label.toUpperCase()}: $e');
      String message = 'Gagal verifikasi ${label.toLowerCase()}, silakan coba lagi.';
      if (e is DioException && e.response?.data != null) {
        try {
          final d = _safeDecode(e.response!.data);
          final msg = (d is Map ? d['message'] : null)?.toString().trim() ?? '';
          if (msg.isNotEmpty) message = msg;
        } catch (_) {}
      }
      return {"value": 0, "message": message, "data": null};
    }
  }
}
