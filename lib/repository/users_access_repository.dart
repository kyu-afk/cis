import 'dart:convert';
import 'package:cis_menu/network/api_client.dart';
import 'package:cis_menu/utils/url.dart';
import 'package:cis_menu/utils/user_pass_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/network.dart';
import '../models/index.dart';
import '../pref/pref.dart';

class UsersAccessRepository {
  static Future<Dio> _dioWithToken() => ApiClient.buildProtected();

  static Dio _dioLegacy() {
    Dio dio = Dio();
    if (!kIsWeb) {
      dio.options.headers['x-username'] = xusername;
      dio.options.headers['x-password'] = xpassword;
    }
    dio.options.headers['Content-Type'] = 'application/json';
    return dio;
  }

  static dynamic _safeDecode(dynamic data) {
    if (data is String) {
      return jsonDecode(data);
    }
    return data;
  }

  /// Ambil pesan error dari response body DioException (status 4xx/5xx).
  /// Fallback ke pesan generik jika body tidak bisa dibaca.
  static String _extractError(Object e) {
    if (e is DioException && e.response?.data != null) {
      try {
        final body = _safeDecode(e.response!.data);
        if (body is Map) {
          final msg = (body['message'] ?? '').toString().trim();
          if (msg.isNotEmpty) return msg;
        }
      } catch (_) {}
    }
    return 'Terjadi kesalahan, silakan coba lagi.';
  }

  static int _mapValueFromGo(dynamic response) {
    final code = (response['code'] ?? '').toString();
    return code == "000" ? 1 : 0;
  }

  static String _mapMessageFromGo(dynamic response) {
    return (response['message'] ?? '').toString();
  }

  static List<dynamic> _asList(dynamic dataResponse) {
    if (dataResponse == null) return [];
    if (dataResponse is List) return dataResponse;
    if (dataResponse is Map) {
      if (dataResponse['items'] is List) return dataResponse['items'] as List;
      if (dataResponse['data'] is List) return dataResponse['data'] as List;
      if (dataResponse.isNotEmpty) return [dataResponse];
    }
    return [];
  }

  static String _normalizeUserId(String? userId) {
    return (userId ?? '').trim().toUpperCase();
  }

  static String? extractPassFromMap(Map<String, dynamic> json) {
    const keys = [
      'pass', 'Pass', 'password', 'Password', 'passwd', 'pass_enc', 'passEncrypt',
    ];
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    for (final entry in json.entries) {
      if (entry.value is Map) {
        final nested = extractPassFromMap(Map<String, dynamic>.from(entry.value as Map));
        if (nested != null) return nested;
      }
    }
    return null;
  }

  static Future<String?> resolveEncryptedPassForUpdate({
    required String bprId,
    required String targetUserId,
    String? inquiryPass,
  }) async {
    final normalizedUserId = _normalizeUserId(targetUserId);
    final fromInquiry = (inquiryPass ?? '').trim();
    if (fromInquiry.isNotEmpty) return fromInquiry;

    final cached = await UserPassCache.get(normalizedUserId);
    if (cached != null && cached.isNotEmpty) return cached;

    final fromCms = await _fetchPassFromCmsUserSearch(bprId: bprId, userId: normalizedUserId);
    if (fromCms != null && fromCms.isNotEmpty) {
      await UserPassCache.save(normalizedUserId, fromCms);
      return fromCms;
    }
    return null;
  }

  static Future<String?> _fetchPassFromCmsUserSearch({
    required String bprId,
    required String userId,
  }) async {
    final normalizedUserId = _normalizeUserId(userId);
    try {
      final dio = _dioLegacy();
      final body = {
        'bpr_id': bprId,
        'userlogin': normalizedUserId,
        'term': 'WEB',
        'filter': {'userid': normalizedUserId, 'namauser': '', 'stsaktif': ''},
        'pagination': {'page': 1, 'limit': 5},
      };
      final response = await dio.post(NetworkURL.getUsersAccess(), data: body);
      final decoded = _safeDecode(response.data);
      if (_mapValueFromGo(decoded) != 1) return null;
      for (final row in _asList(decoded['data'])) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final id = _normalizeUserId(map['userid'] ?? map['user_id'] ?? '');
        if (id != normalizedUserId) continue;
        final pass = extractPassFromMap(map);
        if (pass != null) return pass;
      }
    } catch (e) {
      if (kDebugMode) print('CMS user_search pass fallback gagal: $e');
    }
    return null;
  }

  static Future<void> warmPassCacheForUsers({
    required List<Map<String, dynamic>> users,
  }) async {
    for (final row in users) {
      final userid = _normalizeUserId(row['userid'] ?? '');
      if (userid.isEmpty) continue;
      final cached = await UserPassCache.get(userid);
      if (cached != null && cached.isNotEmpty) continue;
      final pass = extractPassFromMap(row);
      if (pass != null && pass.isNotEmpty) {
        await UserPassCache.save(userid, pass);
      }
    }
  }

  // ==================== INQUIRY USERS ====================
  static Future<Map<String, dynamic>> inquiryUsers({
    required String url,
    required String bprId,
    String? filterUserid,
    String? filterNamauser,
    String? filterStsaktif,
    String? sortBy,
    String? sortType,
    int? page,
    int? limit,
  }) async {
    try {
      final dio = await _dioWithToken();
      final normalizedFilterUserid = _normalizeUserId(filterUserid);

      final body = {
        "filter": {
          "userid":   normalizedFilterUserid,
          "namauser": filterNamauser ?? "",
          "stsaktif": filterStsaktif ?? "",
        },
        "sort": {
          "sort_by":   sortBy ?? "userid",
          "sort_type": sortType ?? "DESC",
        },
        "pagination": {"page": page ?? 1, "limit": limit ?? 10},
      };

      if (kDebugMode) {
        print("ENDPOINT URL INQUIRY USERS : $url");
        print("REQUEST INQUIRY USERS : ${jsonEncode(body)}");
      }

      final response = await dio.post(url, data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("RESPONSE DATA INQUIRY USERS : $decoded");

      final rawData = decoded['data'];
      final List<dynamic> dataList;
      if (rawData is Map && rawData['data'] is List) {
        dataList = rawData['data'] as List;
      } else {
        dataList = _asList(rawData);
      }

      return {
        "value": _mapValueFromGo(decoded),
        "message": _mapMessageFromGo(decoded),
        "data": dataList,
        "total": (rawData is Map) ? (rawData['total'] ?? 0) : 0,
        "code": decoded['code'],
        "status": decoded['status'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR INQUIRY USERS : $e");
      return {"value": 0, "message": _extractError(e), "data": []};
    }
  }

  // ==================== RESET PASSWORD USER ====================
  static Future<Map<String, dynamic>> resetPasswordUser({
    required String url,
    required String bprId,
    required String userlogin,
    required String targetUserId,
    required String term,
  }) async {
    try {
      final dio = await _dioWithToken();
      final normalizedTargetUserId = _normalizeUserId(targetUserId);
      final normalizedUserlogin = _normalizeUserId(userlogin);
      
      final body = {
        "bpr_id": bprId,
        "userlogin": normalizedUserlogin,
        "term": term,
        "userid": normalizedTargetUserId,
      };
      
      if (kDebugMode) {
        print("ENDPOINT URL RESET PASSWORD USER : $url");
        print("REQUEST RESET PASSWORD USER : ${jsonEncode(body)}");
      }
      
      final response = await dio.post(url, data: body);
      final decoded = _safeDecode(response.data);
      
      if (kDebugMode) print("RESPONSE DATA RESET PASSWORD USER : $decoded");
      
      return {
        "value": decoded['code'] == '000' ? 1 : 0,
        "message": decoded['message'] ?? "",
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR RESET PASSWORD USER : $e");
      return {"value": 0, "message": _extractError(e)};
    }
  }

  // ==================== INSERT / UPDATE USERS ====================
  static Future<Map<String, dynamic>> saveUsers({
    required String url,
    required String action,
    required String bprId,
    required String userlogin,
    required String userId,
    required String password,
    String? existingEncryptedPass,
    required String username,
    required String namaUsers,
    required String kdKantor,
    required String tglKadaluarsa,
    required String stsAktif,
    required String listFasilitas,
  }) async {
    try {
      final dio = await _dioWithToken();

      final normalizedUserId = _normalizeUserId(userId);
      final normalizedUserlogin = _normalizeUserId(userlogin);

      List<dynamic> fasilitasList = [];
      if (listFasilitas.isNotEmpty) {
        fasilitasList = jsonDecode(listFasilitas);
      }

      final aksesList = fasilitasList.map((f) {
        return {
          "Modul": f['modul'] ?? "",
          "Menu": f['menu'] ?? "",
          "Submenu": f['submenu'] ?? "",
          "SubSubmenu": f['subsubmenu'] ?? "",
          "Urut": int.tryParse(f['urut']?.toString() ?? '0') ?? 0,
          "Flag": f['flag'] == true || f['is_active'] == true,
        };
      }).toList();

      final Map<String, dynamic> body = {
        "bpr_id": bprId,
        "userlogin": normalizedUserlogin,
        "term": "WEB",
        "userid": normalizedUserId,
        "namauser": namaUsers,
        "kdkantor": kdKantor,
        "tglexp": tglKadaluarsa,
        "lvluser": 1,
        "akses": aksesList,
      };

      if (password.isNotEmpty) {
        body["pass"] = encryptString(password);
      } else if (existingEncryptedPass != null && existingEncryptedPass.trim().isNotEmpty) {
        body["pass"] = existingEncryptedPass.trim();
      }

      if (kDebugMode) print("📤 USERS SAVE REQUEST: ${jsonEncode(body)}");

      final response = await dio.post(url, data: body);
      final decoded = _safeDecode(response.data);

      if (kDebugMode) print("📥 USERS SAVE RESPONSE: $decoded");

      final encryptedSent = body['pass']?.toString();
      if (decoded['code'] == '000' && normalizedUserId.isNotEmpty &&
          encryptedSent != null && encryptedSent.isNotEmpty) {
        await UserPassCache.save(normalizedUserId, encryptedSent);
      } else if (decoded['code'] == '000' && decoded['data'] is Map) {
        final responsePass = extractPassFromMap(Map<String, dynamic>.from(decoded['data'] as Map));
        if (responsePass != null && normalizedUserId.isNotEmpty) {
          await UserPassCache.save(normalizedUserId, responsePass);
        }
      }

      return {
        "value": decoded['code'] == '000' ? 1 : 0,
        "message": decoded['message'] ?? "",
        "data": decoded['data'],
        "code": decoded['code'],
        "encryptedPassSent": encryptedSent,
      };
    } catch (e) {
      if (kDebugMode) {
        print("❌ USERS SAVE ERROR: $e");
        if (e is DioException) print("❌ USERS SAVE DIO RESPONSE: ${e.response?.data}");
      }
      String errorMessage = "Terjadi kesalahan, silakan coba lagi.";
      if (e is DioException && e.response?.data != null) {
        try {
          final responseData = _safeDecode(e.response!.data);
          if (responseData is Map && responseData['message'] != null) {
            final msg = responseData['message'].toString().trim();
            if (msg.isNotEmpty) errorMessage = msg;
          }
        } catch (_) {}
      }
      return {"value": 0, "message": errorMessage};
    }
  }

  // ==================== DELETE USERS ====================
  static Future<Map<String, dynamic>> deleteUsers({
    required String url,
    required String bprId,
    required String userlogin,
    required String targetUserId,
    required String deletedBy,
  }) async {
    try {
      final dio = await _dioWithToken();
      final normalizedTargetUserId = _normalizeUserId(targetUserId);
      final normalizedUserlogin = _normalizeUserId(userlogin);
      final body = {
        "bpr_id": bprId,
        "userlogin": normalizedUserlogin,
        "term": "WEB",
        "userid": normalizedTargetUserId,
      };
      if (kDebugMode) {
        print("ENDPOINT URL DELETE USERS : $url");
        print("REQUEST DELETE USERS : ${jsonEncode(body)}");
      }
      final response = await dio.post(url, data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("RESPONSE DATA DELETE USERS : $decoded");
      return {
        "value": decoded['code'] == '000' ? 1 : 0,
        "message": decoded['message'] ?? "",
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR DELETE USERS : $e");
      return {"value": 0, "message": _extractError(e)};
    }
  }

  // ==================== BLOKIR USERS ====================
  static Future<Map<String, dynamic>> blokirUsers({
    required String url,
    required String bprId,
    required String userlogin,
    required String targetUserId,
    required String blockedBy,
    required String alasan,
  }) async {
    try {
      final dio = await _dioWithToken();
      final normalizedTargetUserId = _normalizeUserId(targetUserId);
      final normalizedUserlogin = _normalizeUserId(userlogin);
      final body = {
        "bpr_id": bprId,
        "userlogin": normalizedUserlogin,
        "term": "WEB",
        "userid": normalizedTargetUserId,
      };
      if (kDebugMode) {
        print("ENDPOINT URL BLOKIR USERS : $url");
        print("REQUEST BLOKIR USERS : ${jsonEncode(body)}");
      }
      final response = await dio.post(url, data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("RESPONSE DATA BLOKIR USERS : $decoded");
      return {
        "value": decoded['code'] == '000' ? 1 : 0,
        "message": decoded['message'] ?? "",
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR BLOKIR USERS : $e");
      return {"value": 0, "message": _extractError(e)};
    }
  }

  // ==================== BUKA BLOKIR USERS ====================
  static Future<Map<String, dynamic>> bukaBlokirUsers({
    required String url,
    required String bprId,
    required String userlogin,
    required String targetUserId,
    required String unblockedBy,
  }) async {
    try {
      final dio = await _dioWithToken();
      final normalizedTargetUserId = _normalizeUserId(targetUserId);
      final normalizedUserlogin = _normalizeUserId(userlogin);
      final body = {
        "bpr_id": bprId,
        "userlogin": normalizedUserlogin,
        "term": "WEB",
        "userid": normalizedTargetUserId,
      };
      if (kDebugMode) {
        print("ENDPOINT URL BUKA BLOKIR USERS : $url");
        print("REQUEST BUKA BLOKIR USERS : ${jsonEncode(body)}");
      }
      final response = await dio.post(url, data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("RESPONSE DATA BUKA BLOKIR USERS : $decoded");
      return {
        "value": decoded['code'] == '000' ? 1 : 0,
        "message": decoded['message'] ?? "",
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR BUKA BLOKIR USERS : $e");
      return {"value": 0, "message": _extractError(e)};
    }
  }

  // ==================== FORCE LOGOUT USER ====================
  static Future<Map<String, dynamic>> forceLogoutUser({
    required String url,
    required String bprId,
    required String userlogin,
    required String targetUserId,
  }) async {
    try {
      final dio = await _dioWithToken();
      final body = {
        "bpr_id":    bprId,
        "userlogin": userlogin.toUpperCase(),
        "term":      "WEB",
        "userid":    targetUserId.toUpperCase(),
      };
      if (kDebugMode) {
        print("ENDPOINT URL FORCE LOGOUT USER : $url");
        print("REQUEST FORCE LOGOUT USER : ${jsonEncode(body)}");
      }
      final response = await dio.post(url, data: body);
      final decoded  = _safeDecode(response.data);
      if (kDebugMode) print("RESPONSE DATA FORCE LOGOUT USER : $decoded");
      return {
        "value":   decoded['code'] == '000' ? 1 : 0,
        "message": decoded['message'] ?? "",
        "code":    decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR FORCE LOGOUT USER : $e");
      return {"value": 0, "message": _extractError(e)};
    }
  }

  // ==================== CLOSE USERS ====================
  static Future<Map<String, dynamic>> closeUsers({
    required String url,
    required String bprId,
    required String userlogin,
    required String targetUserId,
    required String closedBy,
  }) async {
    try {
      final dio = await _dioWithToken();
      final normalizedTargetUserId = _normalizeUserId(targetUserId);
      final normalizedUserlogin = _normalizeUserId(userlogin);
      final body = {
        "bpr_id": bprId,
        "userlogin": normalizedUserlogin,
        "term": "WEB",
        "userid": normalizedTargetUserId,
      };
      if (kDebugMode) {
        print("ENDPOINT URL CLOSE USERS : $url");
        print("REQUEST CLOSE USERS : ${jsonEncode(body)}");
      }
      final response = await dio.post(url, data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("RESPONSE DATA CLOSE USERS : $decoded");
      return {
        "value": decoded['code'] == '000' ? 1 : 0,
        "message": decoded['message'] ?? "",
        "code": decoded['code'],
      };
    } catch (e) {
      if (kDebugMode) print("ERROR CLOSE USERS : $e");
      return {"value": 0, "message": _extractError(e)};
    }
  }

  // ==================== GET LIST FASILITAS ====================
  static Future<Map<String, dynamic>> getListFasilitas({
    required String url,
    required String userId,
    required String bprId,
  }) async {
    try {
      final dio = _dioLegacy();
      final normalizedUserId = _normalizeUserId(userId);
      final body = {
        "action": "list",
        "type": "CIS",
      };
      if (kDebugMode) {
        print("ENDPOINT URL GET LIST FASILITAS : $url");
        print("REQUEST GET LIST FASILITAS : $body");
      }
      final response = await dio.post(url, data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("RESPONSE DATA GET LIST FASILITAS : $decoded");
      return {
        "value": _mapValueFromGo(decoded),
        "message": _mapMessageFromGo(decoded),
        "data": _asList(decoded['data']),
        "kantor": _asList(decoded['kantor']),
      };
    } catch (e) {
      if (kDebugMode) print("ERROR GET LIST FASILITAS : $e");
      return {"value": 0, "message": _extractError(e), "data": [], "kantor": []};
    }
  }

  // ==================== GET LIST KANTOR ====================
  static Future<Map<String, dynamic>> getListKantor({
    required String url,
    required String userId,
    required String bprId,
  }) async {
    try {
      final dio = _dioLegacy();
      final body = {"type": "all", "userlogin": userId, "bpr_id": bprId, "term": "web"};
      if (kDebugMode) {
        print("=========================================");
        print("📞 GET LIST KANTOR");
        print("🌐 URL: $url");
        print("📤 BODY: $body");
        print("=========================================");
      }
      final response = await dio.post(url, data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) {
        print("📥 RESPONSE KANTOR: $decoded");
        print("=========================================");
      }
      List<dynamic> kantorList = [];
      final int value = _mapValueFromGo(decoded);
      if (value == 1) {
        if (decoded['data'] != null && decoded['data'] is List) {
          kantorList = decoded['data'] as List<dynamic>;
        } else if (decoded['data'] is Map && decoded['data']['data'] is List) {
          kantorList = decoded['data']['data'] as List<dynamic>;
        }
      }
      return {"value": value, "message": _mapMessageFromGo(decoded), "kantor": kantorList};
    } catch (e) {
      if (kDebugMode) print("❌ ERROR GET LIST KANTOR: $e");
      return {"value": 0, "message": _extractError(e), "kantor": []};
    }
  }

  // ==================== GET ALL USERS ACCESS ====================
  static Future<List<UsersAccessModel>> getAllUsersAccess({
    required String bprId,
    required String userLogin,
    required String term,
  }) async {
    try {
      final result = await inquiryUsers(
        url: NetworkURL.inquiryUsers(),
        bprId: bprId,
        filterUserid: "",
        filterNamauser: "",
        filterStsaktif: "",
        sortBy: "userid",
        sortType: "DESC",
        page: 1,
        limit: 100,
      );
      if (result['value'] == 1) {
        final List<dynamic> data = result['data'] ?? [];
        List<UsersAccessModel> users = data.map((item) => UsersAccessModel.fromJson(item)).toList();
        users.sort((a, b) => (a.namauser ?? "").compareTo(b.namauser ?? ""));
        return users;
      }
      return [];
    } catch (e) {
      if (kDebugMode) print("Error getAllUsersAccess: $e");
      return [];
    }
  }

  // ==================== SEARCH USERS ACCESS ====================
  static Future<List<UsersAccessModel>> searchUsersAccess({
    required String bprId,
    required String userLogin,
    required String term,
    required String keyword,
  }) async {
    try {
      final result = await inquiryUsers(
        url: NetworkURL.inquiryUsers(),
        bprId: bprId,
        filterUserid: keyword,
        filterNamauser: keyword,
        filterStsaktif: "",
        sortBy: "userid",
        sortType: "DESC",
        page: 1,
        limit: 50,
      );
      if (result['value'] == 1) {
        final List<dynamic> data = result['data'] ?? [];
        return data.map((item) => UsersAccessModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print("Error searchUsersAccess: $e");
      return [];
    }
  }

  // ==================== AKSES USER (MEDFO) ====================
  static Future<List<dynamic>> fetchUserAksesFromMedfo({
    required String bprId,
    required String targetUserId,
  }) async {
    try {
      final normalizedTargetUserId = _normalizeUserId(targetUserId);
      final result = await inquiryUsers(
        url: NetworkURL.inquiryUsers(),
        bprId: bprId,
        filterUserid: normalizedTargetUserId,
        page: 1,
        limit: 10,
      );
      if (result['value'] != 1) return [];
      final data = result['data'] as List<dynamic>? ?? [];
      for (final row in data) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final userid = _normalizeUserId(map['userid'] ?? '');
        if (userid != normalizedTargetUserId) continue;
        final akses = map['akses'];
        if (akses is List) return akses;
      }
      return [];
    } catch (e) {
      if (kDebugMode) print("ERROR FETCH USER AKSES MEDFO : $e");
      return [];
    }
  }

  // ==================== GET FASILITAS BY USER (LEGACY CMS) ====================
  @Deprecated('Database CMS terpisah dari Medfo. Pakai fetchUserAksesFromMedfo.')
  static Future<Map<String, dynamic>> getListFasilitasByUsers({
    required String url,
    required String userId,
    required String targetUserId,
    required String bprId,
  }) async {
    try {
      final dio = _dioLegacy();
      final normalizedUserId = _normalizeUserId(userId);
      final normalizedTargetUserId = _normalizeUserId(targetUserId);
      final body = {
        "bpr_id": bprId,
        "userlogin": normalizedUserId,
        "userid": normalizedTargetUserId,
        "term": "WEB",
      };
      if (kDebugMode) {
        print("ENDPOINT URL GET FASILITAS BY USER : $url");
        print("REQUEST GET FASILITAS BY USER : $body");
      }
      final response = await dio.post(url, data: body);
      final decoded = _safeDecode(response.data);
      if (kDebugMode) print("RESPONSE DATA GET FASILITAS BY USER : $decoded");
      return {
        "value": _mapValueFromGo(decoded),
        "message": _mapMessageFromGo(decoded),
        "data": _asList(decoded['data']),
      };
    } catch (e) {
      if (kDebugMode) print("ERROR GET FASILITAS BY USER : $e");
      return {"value": 0, "message": _extractError(e), "data": []};
    }
  }
}