import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:cis_menu/network/network.dart';
import 'package:cis_menu/pref/pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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

  static Future<Map<String, dynamic>> inquiry({String? petugasHp, String? status}) async {
    try {
      final dio = await _dio();
      final session = await Pref().getUsers();
      final body = {
        'bpr_id': session.bprId,
        if ((petugasHp ?? '').isNotEmpty) 'petugas_hp': petugasHp,
        if ((status ?? '').isNotEmpty) 'status': status,
        'page': 1,
        'size': 200,
      };
      if (kDebugMode) print('MODAL KOLEKTOR INQUIRY: ${jsonEncode(body)}');
      final res = await dio.post(NetworkURL.inquiryModalKolektor(), data: body);
      final d = _decode(res.data);
      final raw = d['data'];
      final List items = raw is Map ? (raw['items'] ?? raw['data'] ?? []) : (raw is List ? raw : []);
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
