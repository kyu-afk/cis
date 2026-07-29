// lib/repository/transaksi_repository.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../network/network.dart';
import '../pref/pref.dart';
import '../utils/inquiry_filter.dart';

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
          final List<dynamic> rawItems = dataObj['items'] ?? [];
          final Map<String, dynamic> pagination = dataObj['pagination'] ?? {};
          final session = await Pref().getUsers();
          final items = InquiryFilter.applyWithSession(
            rawItems,
            sessionBprId: session.bprId,
            sessionKodeKantor: session.kodeKantor,
            sentBprId: true,
          );
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

  // ==================== TRANSAKSI HARI INI (Collme langsung) ====================
  // GET https://api-collme.medtrans.id/api/transaksi/today?userid=...&nohp=...
  // Endpoint ini BUKAN lewat web_service_CIS — langsung ke servis Collme,
  // dan WAJIB kirim userid & nohp milik kolektor yang dipilih. Selalu
  // mengembalikan transaksi hari ini saja (tidak ada filter tanggal).
  //
  // CATATAN: skema auth endpoint ini awalnya dikira tidak perlu header
  // tambahan, tapi ternyata backend membalas 401 "Token tidak ditemukan"
  // tanpa Authorization header. Sekarang dikirim pakai token sesi CIS yang
  // sama (Pref().getToken()) sebagai percobaan pertama — kalau ternyata
  // Collme butuh token yang beda (bukan token CIS), kasih tahu supaya
  // disesuaikan.
  static Future<Map<String, dynamic>> inquiryTransaksiTodayCollme({
    required String userid,
    required String nohp,
  }) async {
    try {
      final token = await Pref().getToken();
      final uri = Uri.parse(NetworkURL.transaksiTodayCollme()).replace(
        queryParameters: {
          'userid': userid,
          'nohp': nohp,
        },
      );

      if (kDebugMode) {
        print("📤 TRANSAKSI TODAY (Collme) URL: $uri");
      }

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        print("📥 TRANSAKSI TODAY STATUS: ${response.statusCode}");
        print("📥 TRANSAKSI TODAY RESPONSE: ${response.body}");
      }

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['code'] == '000') {
          final List<dynamic> items = jsonData['data'] ?? [];
          return {
            'value': 1,
            'message': jsonData['message'] ?? 'OK',
            'data': items,
            'total': items.length,
          };
        } else {
          return {
            'value': 0,
            'message': jsonData['message'] ?? 'Gagal memuat data transaksi',
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
      if (kDebugMode) print("❌ ERROR TRANSAKSI TODAY (Collme): $e");
      return {
        'value': 0,
        'message': 'Error: $e',
        'data': [],
      };
    }
  }

  // ==================== TRANSAKSI KOLEKTOR (Settlement DB Lokal) ====================
  // POST /cis/transaksi/settlement-inquiry-db
  // Baca LANGSUNG dari database lokal kita (cis_settlement JOIN
  // cis_settlement_items) — gantiin API Collme yang sempat 401.
  // Kolektor (userid ATAU nohp) WAJIB dikirim. Tanggal opsional: kosong =
  // semua tanggal, isi tglFrom/tglTo = dibatasi rentang itu (bisa sama
  // untuk cuma 1 tanggal spesifik / hari ini saja).
  static Future<Map<String, dynamic>> inquirySettlementItemsDb({
    String? userid,
    String? nohp,
    String? tglFrom,
    String? tglTo,
    String? status,
    String? bprId,
    int page = 1,
    int size = 500,
  }) async {
    try {
      final token = await Pref().getToken();
      final session = await Pref().getUsers();

      final requestBody = {
        'bpr_id':   bprId ?? session.bprId,
        'userid':   userid ?? '',
        'nohp':     nohp ?? '',
        'tgl_from': tglFrom ?? '',
        'tgl_to':   tglTo ?? '',
        'status':   status ?? '',
        'page':     page,
        'size':     size,
      };

      if (kDebugMode) {
        print('📤 SETTLEMENT INQUIRY-DB URL: ${NetworkURL.settlementInquiryDb()}');
        print('📤 SETTLEMENT INQUIRY-DB BODY: ${jsonEncode(requestBody)}');
      }

      final response = await http.post(
        Uri.parse(NetworkURL.settlementInquiryDb()),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKeymiddlewarecis,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (kDebugMode) {
        print('📥 SETTLEMENT INQUIRY-DB STATUS: ${response.statusCode}');
        print('📥 SETTLEMENT INQUIRY-DB RESPONSE: ${response.body}');
      }

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == '000') {
          final Map<String, dynamic> dataObj = jsonData['data'] ?? {};
          final List<dynamic> items = dataObj['list'] ?? [];
          return {
            'value':   1,
            'message': jsonData['message'] ?? 'OK',
            'data':    items,
            'total':   dataObj['total'] ?? items.length,
          };
        }
        return {
          'value':   0,
          'message': jsonData['message'] ?? 'Gagal memuat data transaksi',
          'data':    [],
        };
      }
      return {
        'value':   0,
        'message': 'HTTP ${response.statusCode}',
        'data':    [],
      };
    } catch (e) {
      if (kDebugMode) print('❌ ERROR SETTLEMENT INQUIRY-DB: $e');
      return {'value': 0, 'message': 'Error: $e', 'data': []};
    }
  }
}