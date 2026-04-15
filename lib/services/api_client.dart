import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';
import '../utils/exceptions.dart';

class ApiClient {
  /// Decodifica el body de una respuesta HTTP como UTF-8.
  /// El paquete http de Dart usa latin1 por defecto si el servidor
  /// no envía charset=utf-8 en Content-Type, lo que corrompe las tildes.
  static String decodeBody(http.Response response) {
    return utf8.decode(response.bodyBytes);
  }

  static Future<Map<String, String>> _headers({Map<String, String>? extra}) async {

    final headers = <String, String>{
      'Accept': 'application/json',
    };

    final token = await StorageService.getApiToken();
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extra != null) {
      headers.addAll(extra);
    }

    return headers;
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await http
        .get(url, headers: await _headers(extra: headers))
        .timeout(timeout ?? const Duration(seconds: 30));
    await _handleAuth(response);
    return response;
  }

  static Future<http.Response> postJson(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final mergedHeaders = await _headers(extra: {
      'Content-Type': 'application/json',
      if (headers != null) ...headers,
    });

    final response = await http
        .post(url, headers: mergedHeaders, body: body == null ? null : jsonEncode(body))
        .timeout(timeout ?? const Duration(seconds: 30));
    await _handleAuth(response);
    return response;
  }

  static Future<void> _handleAuth(http.Response response) async {
    if (response.statusCode != 401) return;

    // Si el token ya no es válido, lo limpiamos para forzar re-login.
    await StorageService.clearApiToken();
    throw AuthException('Sesión caducada. Inicia sesión de nuevo.', statusCode: 401);
  }
}

