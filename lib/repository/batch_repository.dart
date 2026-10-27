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
      final message = (decoded is Map ? decoded['message'] : null)?.toString() ?? '';
      final data = decoded is Map && decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : <String, dynamic>{};

      if (code != '000') {
        return {
          "value": 0,
          "message": message.isNotEmpty ? message : 'Batch tidak ditemukan',
          "data": data,
        };
      }

      // Core: {"batch","nama","status","sbbkas"} — batch harus berstatus aktif.
      final nama = (data['nama'] ?? '').toString();
      final status = (data['status'] ?? '').toString();
      final sbbKas = (data['sbbkas'] ?? '').toString();
      if (status.isNotEmpty && status.toLowerCase() != 'aktif') {
        return {
          "value": 0,
          "message": 'Batch $batch${nama.isNotEmpty ? ' ($nama)' : ''} berstatus "$status", tidak bisa digunakan.',
          "data": data,
        };
      }
      return {
        "value": 1,
        "message": [
          'Batch terverifikasi',
          if (nama.isNotEmpty) 'Nama: $nama',
          if (status.isNotEmpty) 'Status: $status',
          if (sbbKas.isNotEmpty) 'SBB Kas: $sbbKas',
        ].join('\n'),
        "data": data,
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
