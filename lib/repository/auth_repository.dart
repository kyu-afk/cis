import 'dart:convert';

import 'package:cis_menu/models/index.dart';
import 'package:cis_menu/models/login_model.dart';
import 'package:cis_menu/network/api_client.dart';
import 'package:cis_menu/pref/pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/network.dart';

class AuthRepository {
  // Login tidak butuh token — pakai public client
  static Dio _dio() => ApiClient.buildPublic();

  /// Dio dengan Bearer token untuk endpoint protected.
  static Future<Dio> _dioAuth() => ApiClient.buildProtected();

  static dynamic _safeDecode(dynamic data) {
    if (data is String) {
      return jsonDecode(data);
    }
    return data;
  }

  static int _mapValueFromGo(dynamic response) {
    final code = (response['code'] ?? '').toString();
    return code == "000" ? 1 : 0;
  }

  static String _mapMessageFromGo(dynamic response) {
    return (response['message'] ?? '').toString();
  }

  static String _normalizeUpper(dynamic value) {
    return (value ?? "").toString().trim().toUpperCase();
  }

  static String _decodeBase64(String encoded) {
    try {
      return utf8.decode(base64.decode(encoded));
    } catch (e) {
      return encoded;
    }
  }

  /// Ambil pesan error dari DioException response body.
  static String _extractDioErrorMessage(Object e) {
    if (e is DioException && e.response?.data != null) {
      try {
        final decoded = _safeDecode(e.response!.data);
        if (decoded is Map) {
          final msg = (decoded['message'] ?? '').toString().trim();
          if (msg.isNotEmpty) return msg;
        }
      } catch (_) {}
    }
    return "Terjadi kesalahan koneksi, silakan coba lagi.";
  }

  static Map<String, dynamic> _mapLoginDataToOldShape(
    Map<String, dynamic> row,
    String bprId,
  ) {
    return {
      "users_id":    (row["userid"] ?? "").toString(),
      "usersId":     (row["userid"] ?? "").toString(),
      "userid":      (row["userid"] ?? "").toString(),
      "bpr_id":      bprId,
      "bprId":       bprId,
      "nama_users":  (row["nama"] ?? "").toString(),
      "namaUsers":   (row["nama"] ?? "").toString(),
      "namauser":    (row["nama"] ?? "").toString(),
      "kode_kantor": (row["kd_kantor"] ?? "").toString(),
      "kodeKantor":  (row["kd_kantor"] ?? "").toString(),
      "kdkantor":    (row["kd_kantor"] ?? "").toString(),
      "kode_bank":   bprId,
      "kodeBank":    bprId,
      "kdbank":      bprId,
      "pass":        "",
      "tglexp":      "",
      "lvluser":     (row["lvluser"] ?? row["lvl_user"] ?? "1").toString(),
      "nama_kantor": "",
      ...row,
    };
  }

  // ==================== LOGIN ====================

  static Future<dynamic> login(
    String token,
    String url,
    String username,
    String password,
  ) async {
    const String bprId = "609999";

    final normalizedUsername = _normalizeUpper(username);
    final plainPassword = _decodeBase64(password.trim());

    // PATCH: field name disamakan dengan LoginRequest struct di Go backend
    final Map<String, dynamic> json = {
      "bpr_id":   bprId,
      "user_id":  normalizedUsername,  // ← was "userid"
      "password": plainPassword,        // ← was "pass"
    };

    final dio = _dio();

    if (kDebugMode) {
      print("ENDPOINT URL LOGIN : $url");
      print("REQUEST LOGIN : $json");
    }

    try {
      final response = await dio.post(url, data: json);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) {
        print("RESPONSE STATUS CODE LOGIN : ${response.statusCode}");
        print("RESPONSE DATA LOGIN : $decoded");
      }

      final isSuccess = decoded['code'] == '000';
      // Login response dari web service: { token, userid, nama, kd_kantor, akses }
      final rawData = decoded['data'] ?? {};

      final mappedData = _mapLoginDataToOldShape(
        rawData is Map ? Map<String, dynamic>.from(rawData) : {},
        bprId,
      );

      List<dynamic> fasilitasList = [];
      if (isSuccess && rawData is Map) {
        try {
          // Simpan token Bearer ke pref
          final authToken = (rawData['token'] ?? '').toString();
          if (authToken.isNotEmpty) {
            await Pref().setToken(authToken);
          }

          final loginResp = LoginResponseModel.fromJson(
            Map<String, dynamic>.from(rawData),
          );

          final usersModel = UsersModel(
            bprId:      bprId,
            usersId:    loginResp.user.userId,
            namaUsers:  loginResp.user.namaUser,
            kodeKantor: loginResp.user.kdKantor,
            namaKantor: "",
            lvlUser:    int.tryParse((rawData['lvluser'] ?? rawData['lvl_user'] ?? '1').toString()) ?? 1,
          );
          await Pref().simpan(usersModel);

          fasilitasList = loginResp.akses
              .where((a) => a.flag)
              .map((a) => a.toFasilitasJson())
              .toList();

          await Pref().setFasilitas(jsonEncode(fasilitasList));

          if (kDebugMode) {
            print("[AuthRepository.login] token saved   : $authToken");
            print("[AuthRepository.login] akses count   : ${loginResp.akses.length}");
            print("[AuthRepository.login] fasilitas saved: ${fasilitasList.length} item(s)");
          }
        } catch (e) {
          if (kDebugMode) print("[AuthRepository.login] ERROR parse data: $e");
        }
      }

      return {
        "value":     isSuccess ? 1 : 0,
        "message":   decoded['message'] ?? "",
        "data":      mappedData,
        "fasilitas": fasilitasList,
        "raw":       decoded,
      };
    } catch (e) {
      if (kDebugMode) print("[AuthRepository.login] ERROR: $e");
      return {
        "value":     0,
        "message":   _extractDioErrorMessage(e),
        "data":      {},
        "fasilitas": [],
        "raw":       {},
      };
    }
  }

  // ==================== LOGOUT ====================
  // Web service logout: POST /logout dengan Authorization: Bearer <token>
  // Tidak memerlukan body.

  static Future<dynamic> logOut(
    String url,
    String bprId,
    String userlogin,
    String userid,
  ) async {
    final dio = await _dioAuth();

    if (kDebugMode) {
      print("ENDPOINT URL LOGOUT : $url");
    }

    try {
      final response = await dio.post(url);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) {
        print("RESPONSE STATUS CODE LOGOUT : ${response.statusCode}");
        print("RESPONSE DATA LOGOUT : $decoded");
      }

      return {
        "value":   decoded['code'] == '000' ? 1 : 0,
        "message": decoded['message'] ?? "",
        "data":    decoded['data'],
        "raw":     decoded,
      };
    } catch (e) {
      if (kDebugMode) print("[AuthRepository.logOut] ERROR: $e");
      return {
        "value":   0,
        "message": _extractDioErrorMessage(e),
        "data":    {},
        "raw":     {},
      };
    }
  }

  // ==================== FORCE LOGOUT ====================

  static Future<dynamic> forceLogOut(
    String url,
    String bprId,
    String userlogin,
    String userid,
  ) async {
    final dio = await _dioAuth();

    if (kDebugMode) {
      print("ENDPOINT URL FORCE LOGOUT : $url");
    }

    try {
      final response = await dio.post(url);
      final decoded  = _safeDecode(response.data);

      if (kDebugMode) {
        print("RESPONSE STATUS CODE FORCE LOGOUT : ${response.statusCode}");
        print("RESPONSE DATA FORCE LOGOUT : $decoded");
      }

      return {
        "value":   decoded['code'] == '000' ? 1 : 0,
        "message": decoded['message'] ?? "",
        "data":    decoded['data'],
        "raw":     decoded,
      };
    } catch (e) {
      if (kDebugMode) print("[AuthRepository.forceLogOut] ERROR: $e");
      return {
        "value":   0,
        "message": _extractDioErrorMessage(e),
        "data":    {},
        "raw":     {},
      };
    }
  }

  // ==================== METHOD LAMA (tidak diubah) ====================

  static Future<dynamic> inqueryHp(
    String token,
    String url,
    String bprId,
    String noHp,
    String userlogin,
  ) async {
    return {"value": 0, "message": "Method not available", "data": {}};
  }

  static Future<dynamic> inquiryUserAccount(
    String token,
    String url,
    String bprId,
    String usersId,
  ) async {
    return {"value": 0, "message": "Method not available", "data": {}};
  }

  static Future<dynamic> postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    final dio = Dio();
    dio.options.headers = {"Content-Type": "application/json"};
    if (!kIsWeb) {
      dio.options.headers['x-username'] = xusername;
      dio.options.headers['x-password'] = xpassword;
    }

    final response = await dio.post(url, data: body);
    return response.data is String
        ? jsonDecode(response.data)
        : response.data;
  }

  static Future<dynamic> createUsersInfo(
    String url,
    Map<String, dynamic> body,
  ) async {
    Dio dio = _dio();
    final res = await dio.post(url, data: body);
    return res.data is String ? jsonDecode(res.data) : res.data;
  }

  static Future<dynamic> updateUsersInfo(
    String url,
    Map<String, dynamic> body,
  ) async {
    Dio dio = _dio();
    final response = await dio.post(url, data: body);
    final decoded  = response.data is String
        ? jsonDecode(response.data)
        : response.data;
    return {
      "value":   decoded["value"] == 1 || decoded["code"] == "000" ? 1 : 0,
      "message": (decoded["message"] ?? "").toString(),
      "data":    decoded["data"],
      "raw":     decoded,
    };
  }

  static Future<dynamic> gantiPassword(
    String token,
    String url,
    String bprId,
    String usersId,
    String passwordBaru,
    String passwordLama,
    String passwordKonfirmasi,
    String userLogin,
  ) async {
    try {
      final dio = await _dioAuth();
      final body = {
        'bpr_id':        bprId,
        'userlogin':     userLogin.toUpperCase(),
        'term':          'WEB',
        'userid':        usersId.toUpperCase(),
        'password_lama': passwordLama,
        'password_baru': passwordBaru,
      };

      final response = await dio.post(url, data: body);
      final decoded  = _safeDecode(response.data);

      return {
        'value':   decoded['code'] == '000' ? 1 : 0,
        'message': decoded['message'] ?? '',
        'data':    decoded['data'],
        'raw':     decoded,
      };
    } catch (e) {
      return {
        'value':   0,
        'message': _extractDioErrorMessage(e),
        'data':    null,
      };
    }
  }
}