import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:cis_menu/network/network.dart';
import 'package:cis_menu/pref/pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cis_menu/utils/inquiry_filter.dart';
import 'package:cis_menu/repository/collector_repository.dart';

class ModalKolektorRepository {
  static Future<Dio> _dio() => ApiClient.buildProtected();

  static dynamic _decode(dynamic d) => d is String ? jsonDecode(d) : d;
  static int _code(dynamic r) {
    final c = (r['code'] ?? '').toString();
    return c == '000' || c == '200' || c == '201' ? 1 : 0;
  }
  static String _msg(dynamic r) => (r['message'] ?? '').toString();
  static String _err(dynamic e) {
    if (e is DioException && e.response?.data != null) {
      try {
        final d = _decode(e.response!.data);
        if (d is Map) {
          final f = d['data']?['fields'];
          if (f is Map && f.isNotEmpty) return f.entries.map((e) => '${e.key}: ${e.value}').join('\n');
          final m = (d['message'] ?? '').toString().trim();
          if (m.isNotEmpty) return m;
        }
      } catch (_) {}
    }
    return 'Terjadi kesalahan, silakan coba lagi.';
  }

  static Future<Map<String, dynamic>> inquiry({String? petugasHp, String? status, int? sinceDays}) async {
    try {
      final dio = await _dio();
      final session = await Pref().getUsers();
      final body = {
        'bpr_id': session.bprId,
        if ((petugasHp ?? '').isNotEmpty) 'petugas_hp': petugasHp,
        if ((status ?? '').isNotEmpty) 'status': status,
        // Batasi data ke N hari terakhir (default backend 7 hari kalau gak
        // dikirim) -- sesuai kesepakatan performa: data lama TETAP AMAN
        // tersimpan di database, cuma gak ditampilkan/di-query di sini.
        // Backend juga pakai jendela waktu yang sama buat proses auto-settle
        // (cocokkan status DIBERIKAN -> SETTLE), jadi filter ini bukan cuma
        // soal tampilan.
        'since_days': sinceDays ?? 7,
        'page': 1,
        'size': 200,
      };
      if (kDebugMode) print('MODAL KOLEKTOR INQUIRY: ${jsonEncode(body)}');
      final res = await dio.post(NetworkURL.inquiryModalKolektor(), data: body);
      final d = _decode(res.data);
      final raw = d['data'];
      final List rawItems = raw is Map ? (raw['items'] ?? raw['data'] ?? []) : (raw is List ? raw : []);

      // PATCH: data modal kolektor sendiri gak bawa field kd_kantor, jadi
      // buat filter per-kantor kita cross-check ke inquiry kolektor (yang
      // punya kd_kantor per nohp), lalu tempel ke tiap item di sini.
      List filteredItems = rawItems;
      if ((session.kodeKantor).isNotEmpty && session.kodeKantor != '000') {
        try {
          final kolektorResult = await CollectorRepository.inquiryCollectorDb(limit: 1000);
          if (kolektorResult['value'] == 1) {
            final List<dynamic> kolektorList = kolektorResult['data'] ?? [];
            final Map<String, String> kdKantorByNoHp = {
              for (final k in kolektorList)
                if ((k['nohp'] ?? '').toString().trim().isNotEmpty)
                  k['nohp'].toString().trim(): (k['kd_kantor'] ?? '').toString(),
            };
            filteredItems = rawItems.where((item) {
              final nohp = (item['petugas_hp'] ?? '').toString().trim();
              final kdKantor = kdKantorByNoHp[nohp];
              // Kalau gak ketemu cross-reference-nya, biarkan lolos (jangan
              // sampai data hilang gara-gara gagal cocokin, bukan gara-gara
              // memang beda kantor).
              if (kdKantor == null) return true;
              return kdKantor == session.kodeKantor;
            }).toList();
          }
        } catch (e) {
          if (kDebugMode) print('MODAL KOLEKTOR: gagal cross-check kd_kantor: $e');
        }
      }

      final items = InquiryFilter.applyWithSession(
        filteredItems,
        sessionBprId: session.bprId,
        sessionKodeKantor: session.kodeKantor,
        sentBprId: true,
      );
      return {'value': _code(d), 'message': _msg(d), 'data': items, 'total': raw is Map ? (raw['total'] ?? items.length) : items.length};
    } catch (e) {
      return {'value': 0, 'message': _err(e), 'data': [], 'total': 0};
    }
  }

  static Future<Map<String, dynamic>> add({
    required String petugasHp,
    required String petugasNama,
    required double nominal,
    String keterangan = '',
  }) async {
    try {
      final dio = await _dio();
      final session = await Pref().getUsers();
      final body = {
        'bpr_id': session.bprId,
        'petugas_hp': petugasHp,
        'petugas_nama': petugasNama,
        'nominal': nominal,
        'keterangan': keterangan,
        'userlogin': session.usersId,
        'term': 'WEB',
      };
      if (kDebugMode) print('MODAL KOLEKTOR ADD: ${jsonEncode(body)}');
      final res = await dio.post(NetworkURL.addModalKolektor(), data: body);
      final d = _decode(res.data);
      return {'value': _code(d), 'message': _msg(d), 'data': d['data']};
    } catch (e) {
      return {'value': 0, 'message': _err(e)};
    }
  }

  static Future<Map<String, dynamic>> berikan({
    required int id,
    required String tellerID,
    required String tellerNama,
  }) async {
    try {
      final dio = await _dio();
      final session = await Pref().getUsers();
      final body = {
        'id': id,
        'bpr_id': session.bprId,
        'teller_id': tellerID,
        'teller_nama': tellerNama,
        'userlogin': session.usersId,
        'term': 'WEB',
      };
      final res = await dio.post(NetworkURL.berikanModalKolektor(), data: body);
      final d = _decode(res.data);
      return {'value': _code(d), 'message': _msg(d)};
    } catch (e) {
      return {'value': 0, 'message': _err(e)};
    }
  }

  static Future<Map<String, dynamic>> delete({required int id}) async {
    try {
      final dio = await _dio();
      final session = await Pref().getUsers();
      final body = {'id': id, 'bpr_id': session.bprId, 'userlogin': session.usersId, 'term': 'WEB'};
      final res = await dio.post(NetworkURL.deleteModalKolektor(), data: body);
      final d = _decode(res.data);
      return {'value': _code(d), 'message': _msg(d)};
    } catch (e) {
      return {'value': 0, 'message': _err(e)};
    }
  }
}
