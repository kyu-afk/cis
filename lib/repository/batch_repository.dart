import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/network.dart';
import '../pref/pref.dart';

class BatchRepository {
  static dynamic _safeDecode(dynamic data) {
    if (data is String) return jsonDecode(data);
    return data;
  }

  // ==================== VERIFIKASI BATCH ====================
  // Batch teller/kolektor wajib lolos verifikasi ini sebelum boleh diinsert.
  static Future<Map<String, dynamic>> verifikasiBatch({
    required String batch,
    String? bprId,
  }) async {
    try {
      final dio = await ApiClient.buildProtected();
      final session = await Pref().getUsers();

      final body = {
        "bpr_id": bprId ?? session.bprId,
        "rrn": DateTime.now().millisecondsSinceEpoch.toString(),
        "batch": batch,
      };

      if (kDebugMode) {
        print('VERIFIKASI BATCH URL: ${NetworkURL.inquiryBatch()}');
        print('VERIFIKASI BATCH BODY: ${jsonEncode(body)}');
      }

      final response = await dio.post(NetworkURL.inquiryBatch(), data: body);
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print('VERIFIKASI BATCH RESPONSE: $decoded');

      final code = (decoded is Map ? decoded['code'] : '').toString();
      final ok = code == '000' || code == '200';
      final message = (decoded is Map ? decoded['message'] : null)?.toString() ?? '';
      return {
        "value": ok ? 1 : 0,
        "message": message.isNotEmpty
            ? message
            : (ok ? 'Batch terverifikasi' : 'Batch tidak ditemukan'),
        "data": decoded is Map ? decoded['data'] : null,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR VERIFIKASI BATCH: $e');
      String message = 'Gagal verifikasi batch, silakan coba lagi.';
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
