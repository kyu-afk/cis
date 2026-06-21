import 'dart:convert';
import 'package:cis_menu/pref/pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'network.dart';

/// ApiClient — Dio terpusat untuk semua request ke backend CIS.
///
/// Fitur utama:
/// - Otomatis pasang X-API-Key dan Authorization Bearer di setiap request.
/// - Intercept response: kalau backend return rc = TOKEN_INVALID,
///   session di-clear dan user di-redirect ke halaman login secara otomatis.
///   Ini menangkap case force logout dari perangkat lain.
/// - rc lain (API_KEY_INVALID, TOKEN_MISSING) ditangani sebagai error biasa
///   tanpa redirect — jadi tidak ada redirect yang salah sasaran.
class ApiClient {
  ApiClient._();

  // NavigatorKey global — pasang di MaterialApp agar ApiClient bisa navigate
  // tanpa perlu BuildContext.
  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<Dio> _build({bool withToken = true}) async {
    final dio = Dio();
    dio.options.headers['X-API-Key'] = apiKeymiddlewarecis;
    dio.options.headers['Content-Type'] = 'application/json';

    if (withToken) {
      final token = await Pref().getToken();
      if (token.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          _checkTokenInvalid(response.data);
          handler.next(response);
        },
        onError: (DioException e, handler) {
          // Backend mengembalikan 401 dengan body JSON —
          // Dio melempar ini sebagai error, kita perlu baca body-nya.
          if (e.response != null) {
            _checkTokenInvalid(e.response!.data);
          }
          handler.next(e);
        },
      ),
    );

    return dio;
  }

  /// Dio untuk endpoint yang TIDAK butuh token (hanya login).
  static Dio buildPublic() {
    final dio = Dio();
    dio.options.headers['X-API-Key'] = apiKeymiddlewarecis;
    dio.options.headers['Content-Type'] = 'application/json';
    return dio;
  }

  /// Dio untuk endpoint protected (butuh Bearer token).
  static Future<Dio> buildProtected() => _build(withToken: true);

  // ── Internal ──────────────────────────────────────────────────────────

  /// Cek apakah response mengandung rc = TOKEN_INVALID.
  /// Kalau iya, clear session dan redirect ke login.
  static void _checkTokenInvalid(dynamic data) {
    try {
      final Map<String, dynamic> body = data is String ? jsonDecode(data) : Map<String, dynamic>.from(data as Map);
      final rc = (body['rc'] ?? '').toString();

      if (rc == 'TOKEN_INVALID') {
        if (kDebugMode) print('[ApiClient] TOKEN_INVALID — redirect ke login');
        _forceRedirectToLogin();
      }
    } catch (_) {
      // Kalau body bukan JSON atau tidak ada field rc, abaikan
    }
  }

  /// Clear pref dan navigate ke halaman login.
  static void _forceRedirectToLogin() async {
    await Pref().hapus();

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // Pastikan kita tidak navigate kalau sudah di halaman login
    nav.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  /// Helper: decode response body dengan aman.
  static dynamic safeDecode(dynamic data) {
    if (data is String) return jsonDecode(data);
    return data;
  }

  /// Helper: ambil message dari response body.
  static String extractMessage(dynamic data) {
    try {
      final body = safeDecode(data);
      return (body['message'] ?? '').toString();
    } catch (_) {
      return 'Terjadi kesalahan';
    }
  }

  /// Helper: ambil pesan error dari DioException.
  static String extractDioError(Object e) {
    if (e is DioException && e.response?.data != null) {
      try {
        final body = safeDecode(e.response!.data);
        if (body is Map) {
          final msg = (body['message'] ?? '').toString().trim();
          if (msg.isNotEmpty) return msg;
        }
      } catch (_) {}
    }
    return 'Terjadi kesalahan koneksi, silakan coba lagi.';
  }
}
