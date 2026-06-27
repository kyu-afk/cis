import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:cis_menu/network/network.dart';
import 'package:cis_menu/pref/pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class SbbPerantaraRepository {
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

  static Future<Map<String, dynamic>> inquiry({String? noSbb, String? nama}) async {
    try {
      final dio = await _dio();
      final session = await Pref().getUsers();
      final body = {
        'bpr_id': session.bprId,
        if ((noSbb ?? '').isNotEmpty) 'no_sbb': noSbb,
        if ((nama ?? '').isNotEmpty) 'nama': nama,
        'page': 1,
        'size': 200,
      };
      if (kDebugMode) print('SBB PERANTARA INQUIRY: ${jsonEncode(body)}');
      final res = await dio.post(NetworkURL.inquirySbbPerantara(), data: body);
      final d = _decode(res.data);
      final raw = d['data'];
      final List items = raw is Map ? (raw['items'] ?? raw['data'] ?? []) : (raw is List ? raw : []);
      return {'value': _code(d), 'message': _msg(d), 'data': items, 'total': raw is Map ? (raw['total'] ?? items.length) : items.length};
    } catch (e) {
      return {'value': 0, 'message': _err(e), 'data': [], 'total': 0};
    }
  }

  static Future<Map<String, dynamic>> add({required String noSbb, required String namaSbb}) async {
    try {
      final dio = await _dio();
      final session = await Pref().getUsers();
      final body = {'bpr_id': session.bprId, 'no_sbb': noSbb, 'nama_sbb': namaSbb, 'userlogin': session.usersId, 'term': 'WEB'};
      final res = await dio.post(NetworkURL.addSbbPerantara(), data: body);
      final d = _decode(res.data);
      return {'value': _code(d), 'message': _msg(d)};
    } catch (e) {
      return {'value': 0, 'message': _err(e)};
    }
  }

  static Future<Map<String, dynamic>> edit({required int id, required String noSbb, required String namaSbb}) async {
    try {
      final dio = await _dio();
      final session = await Pref().getUsers();
      final body = {'id': id, 'bpr_id': session.bprId, 'no_sbb': noSbb, 'nama_sbb': namaSbb, 'userlogin': session.usersId, 'term': 'WEB'};
      final res = await dio.post(NetworkURL.editSbbPerantara(), data: body);
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
      final res = await dio.post(NetworkURL.deleteSbbPerantara(), data: body);
      final d = _decode(res.data);
      return {'value': _code(d), 'message': _msg(d)};
    } catch (e) {
      return {'value': 0, 'message': _err(e)};
    }
  }
}
