import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/network.dart';

class KantorRepository {
  static Dio _dio() {
    Dio dio = Dio();
    // Web: custom headers trigger CORS preflight and must be explicitly allowed by the API.
    // For local web dev (different port/origin), omit these headers.
    if (!kIsWeb) {
      dio.options.headers['x-username'] = xusername;
      dio.options.headers['x-password'] = xpassword;
    }
    return dio;
  }

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

  static List<dynamic> _mapDataList(dynamic response) {
    final data = response['data'];
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      return [data];
    }
    return [];
  }

  static List<dynamic> _buildDummySandiBank(String bprId) {
    return [
      {
        "kode_bank": bprId,
        "nama": bprId,
      }
    ];
  }

  static Future<dynamic> getKantor(
    String token,
    String url,
    String username,
    String bprId,
  ) async {
    Map<String, dynamic> json = {
      "type": "all",
      "userlogin": username,
      "bpr_id": bprId,
      "term": "web",
    };

    Dio dio = _dio();

    if (kDebugMode) {
      print("ENDPOINT URL : $url");
      print("REQUEST BODY : $json");
    }

    final response = await dio.post(url, data: json);
    final decoded = _safeDecode(response.data);

    if (kDebugMode) {
      print("RESPONSE STATUS CODE : ${response.statusCode}");
      print("RESPONSE DATA KANTOR : $decoded");
    }

    return {
      "value": _mapValueFromGo(decoded),
      "message": _mapMessageFromGo(decoded),
      "data": _mapDataList(decoded),
      // tetap dikembalikan supaya notifier lama tidak error
      "sandi_bank": _buildDummySandiBank(bprId),
      // optional: simpan raw response untuk debug
      "raw": decoded,
    };
  }

  static Future<dynamic> insertKantorCMS(
    String token,
    String url,
    String bprId,
    String userlogin,
    String bpr_id,
    String kdKantor,
    String namaKantor,
  ) async {
    Map<String, dynamic> json = {
      "action": "insert",
      "userlogin": userlogin,
      "bpr_id": bprId,
      "kd_kantor": kdKantor,
      "term": "web",
      "nama_kantor": namaKantor,
    };

    Dio dio = _dio();

    if (kDebugMode) {
      print("ENDPOINT URL : $url");
      print("REQUEST BODY : $json");
    }

    final response = await dio.post(url, data: json);
    final decoded = _safeDecode(response.data);

    if (kDebugMode) {
      print("RESPONSE STATUS CODE : ${response.statusCode}");
      print("RESPONSE DATA INSERT KANTOR : $decoded");
    }

    return {
      "value": _mapValueFromGo(decoded),
      "message": _mapMessageFromGo(decoded),
      "data": decoded['data'],
      "raw": decoded,
    };
  }

  static Future<dynamic> updateKantorCMS(
    String token,
    String url,
    String bprId,
    String userlogin,
    String bpr_id,
    String kdKantor,
    String namaKantor,
  ) async {
    Map<String, dynamic> json = {
      "action": "update",
      "userlogin": userlogin,
      "bpr_id": bprId,
      "kd_kantor": kdKantor,
      "term": "web",
      "nama_kantor": namaKantor,
    };

    Dio dio = _dio();

    if (kDebugMode) {
      print("ENDPOINT URL : $url");
      print("REQUEST BODY : $json");
    }

    final response = await dio.post(url, data: json);
    final decoded = _safeDecode(response.data);

    if (kDebugMode) {
      print("RESPONSE STATUS CODE : ${response.statusCode}");
      print("RESPONSE DATA UPDATE KANTOR : $decoded");
    }

    return {
      "value": _mapValueFromGo(decoded),
      "message": _mapMessageFromGo(decoded),
      "data": decoded['data'],
      "raw": decoded,
    };
  }

  static Future<dynamic> deleteKantorCMS(
    String token,
    String url,
    String bprId,
    String userlogin,
    String bpr_id,
    String kdKantor,
    String namaKantor,
  ) async {
    Map<String, dynamic> json = {
      "action": "delete",
      "userlogin": userlogin,
      "bpr_id": bprId,
      "kd_kantor": kdKantor,
      "term": "web",
      "nama_kantor": namaKantor,
    };

    Dio dio = _dio();

    if (kDebugMode) {
      print("ENDPOINT URL : $url");
      print("REQUEST BODY : $json");
    }

    final response = await dio.post(url, data: json);
    final decoded = _safeDecode(response.data);

    if (kDebugMode) {
      print("RESPONSE STATUS CODE : ${response.statusCode}");
      print("RESPONSE DATA DELETE KANTOR : $decoded");
    }

    return {
      "value": _mapValueFromGo(decoded),
      "message": _mapMessageFromGo(decoded),
      "data": decoded['data'],
      "raw": decoded,
    };
  }
}
