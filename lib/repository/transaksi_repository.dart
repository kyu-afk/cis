// lib/repository/transaksi_repository.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../network/network.dart';
import '../pref/pref.dart';

class TransaksiRepository {
  static Future<Map<String, dynamic>> inquiryTransaksi({
    required String bprId,
    required String userLogin,
    String? noHp,
    String? status,
    String? tglFrom,
    String? tglTo,
    int? page,
    int? size,
  }) async {
    try {
      final token = await Pref().getToken();

      final requestBody = {
        "filter": {
          "bpr_id": bprId,
          "nohp": noHp ?? "",
          "status": status ?? "",
          // backend struct pakai created_at dengan tipe object {from, to}
          "created_at": {
            "from": tglFrom ?? "",
            "to": tglTo ?? "",
          }
        },
        "page": page ?? 1,
        "size": size ?? 100,
        "sort": "tgl_trans",
        "order": "DESC",
      };

      if (kDebugMode) {
        print("📤 INQUIRY TRANSAKSI URL: ${NetworkURL.inquiryTransaksi()}");
        print("📤 INQUIRY TRANSAKSI BODY: ${jsonEncode(requestBody)}");
      }

      final response = await http.post(
        Uri.parse(NetworkURL.inquiryTransaksi()),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKeymiddlewarecis,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (kDebugMode) {
        print("📥 INQUIRY TRANSAKSI STATUS: ${response.statusCode}");
        print("📥 INQUIRY TRANSAKSI RESPONSE: ${response.body}");
      }

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['code'] == '000' || jsonData['status'] == 'success') {
          // response membungkus list di dalam data.items
          final Map<String, dynamic> dataObj = jsonData['data'] ?? {};
          final List<dynamic> items = dataObj['items'] ?? [];
          final Map<String, dynamic> pagination = dataObj['pagination'] ?? {};
          return {
            'value': 1,
            'message': jsonData['message'] ?? 'Berhasil',
            'data': items,
            'total': pagination['total_items'] ?? items.length,
          };
        } else {
          return {
            'value': 0,
            'message': jsonData['message'] ?? 'Gagal memuat data',
            'data': [],
          };
        }
      } else {
        return {
          'value': 0,
          'message': 'HTTP ${response.statusCode}',
          'data': [],
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ ERROR INQUIRY TRANSAKSI: $e");
      }
      return {
        'value': 0,
        'message': 'Error: $e',
        'data': [],
      };
    }
  }
}