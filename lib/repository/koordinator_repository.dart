import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:cis_menu/network/network.dart';
import 'package:cis_menu/pref/pref.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

/// Master Koordinator + member (rekening tabungan yang disetor lewat koordinator).
class KoordinatorRepository {
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

  static Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> extra) async {
    try {
      final dio = await _dio();
      final session = await Pref().getUsers();
      final body = {'bpr_id': session.bprId, 'userlogin': session.usersId, 'term': 'WEB', ...extra};
      final res = await dio.post(url, data: body);
      final d = _decode(res.data);
      return {'value': _code(d), 'message': _msg(d), 'raw': d['data']};
    } catch (e) {
      return {'value': 0, 'message': _err(e), 'raw': null};
    }
  }

  static List _items(dynamic raw) => raw is Map ? (raw['items'] ?? []) as List : (raw is List ? raw : []);

  static Future<Map<String, dynamic>> inquiry({String? q}) async {
    final r = await _post(NetworkURL.inquiryKoordinator(), {'nama': q ?? '', 'page': 1, 'size': 500});
    return {...r, 'data': _items(r['raw'])};
  }

  static Future<Map<String, dynamic>> save({
    int? id,
    required String kdKoord,
    required String nama,
    required String jalan,
    required String kelurahan,
    required String kecamatan,
    required String kota,
    required String noHp,
    required String sbbPerantara,
    required String namaSbb,
    String? password,
  }) {
    final body = {
      if (id != null) 'id': id,
      'kd_koord': kdKoord,
      'nama': nama,
      'jalan': jalan,
      'kelurahan': kelurahan,
      'kecamatan': kecamatan,
      'kota': kota,
      'no_hp': noHp,
      'sbb_perantara': sbbPerantara,
      'nama_sbb': namaSbb,
      if (id == null) 'password': password ?? '',
    };
    return _post(id == null ? NetworkURL.addKoordinator() : NetworkURL.editKoordinator(), body);
  }

  static Future<Map<String, dynamic>> delete(int id) => _post(NetworkURL.deleteKoordinator(), {'id': id});
  static Future<Map<String, dynamic>> resetPassword(int id, String password) =>
      _post(NetworkURL.resetPasswordKoordinator(), {'id': id, 'password': password});
  static Future<Map<String, dynamic>> blokir(int id) => _post(NetworkURL.blokirKoordinator(), {'id': id});
  static Future<Map<String, dynamic>> unblokir(int id) => _post(NetworkURL.unblokirKoordinator(), {'id': id});

  static Future<Map<String, dynamic>> members(String kdKoord) async {
    final r = await _post(NetworkURL.inquiryMemberKoordinator(), {'kd_koord': kdKoord});
    return {...r, 'data': _items(r['raw'])};
  }

  static Future<Map<String, dynamic>> addMember(String kdKoord, String noRek, String namaRek) =>
      _post(NetworkURL.addMemberKoordinator(), {'kd_koord': kdKoord, 'no_rek': noRek, 'nama_rek': namaRek});

  static Future<Map<String, dynamic>> deleteMember(int id) => _post(NetworkURL.deleteMemberKoordinator(), {'id': id});

  /// Inquiry rekening tabungan (gl_jns 2) / SBB (gl_jns 1) lewat core.
  static Future<Map<String, dynamic>> inquiryRekening(String noRek, {String glJns = '2'}) async {
    try {
      final dio = await _dio();
      final session = await Pref().getUsers();
      final tgl = DateFormat('ddMMyyHHmmss').format(DateTime.now());
      final res = await dio.post(NetworkURL.inquiryAccount(), data: {
        'userlogin': session.usersId,
        'bpr_id': session.bprId,
        'trx_code': '0200',
        'trx_type': 'TRX',
        'tgl_trans': tgl,
        'tgl_transmis': tgl,
        'rrn': DateTime.now().millisecondsSinceEpoch.toString(),
        'no_rek': noRek,
        'gl_jns': glJns,
      });
      final d = _decode(res.data);
      if ((d['code'] ?? '').toString() == '000' && d['data'] != null) {
        final data = d['data'] is List && (d['data'] as List).isNotEmpty ? d['data'][0] : d['data'];
        final nama = (data['nama'] ?? data['nama_rekening'] ?? '').toString();
        if (nama.isNotEmpty) return {'value': 1, 'nama': nama, 'no_rek': (data['no_rek'] ?? noRek).toString()};
      }
      return {'value': 0, 'message': (d['message'] ?? 'Rekening tidak ditemukan').toString()};
    } catch (e) {
      return {'value': 0, 'message': 'Gagal inquiry rekening: ${_err(e)}'};
    }
  }
}
