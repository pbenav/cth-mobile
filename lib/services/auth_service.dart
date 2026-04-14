import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../services/config_service.dart';
import '../services/setup_service.dart';
import '../services/storage_service.dart';
import '../utils/exceptions.dart';

class AuthService {
  static String _normalizeUrl(String baseUrl) {
    if (baseUrl.endsWith('/')) {
      return baseUrl.substring(0, baseUrl.length - 1);
    }
    return baseUrl;
  }

  static Future<String> _getBaseUrl() async {
    // Durante setup inicial, buscar URL temporal
    final tempUrl = await SetupService.getTempServerUrl();
    if (tempUrl != null) return _normalizeUrl(tempUrl);
    // Después del setup, buscar URL guardada
    final setupUrl = await SetupService.getConfiguredServerUrl();
    if (setupUrl != null) return _normalizeUrl(setupUrl);
    // Fallback a ConfigService
    final configuredUrl = await ConfigService.getCurrentServerUrl();
    return _normalizeUrl(configuredUrl ?? '');
  }

  static Future<User> login({
    required String email,
    required String password,
    String deviceName = 'cth_mobile',
    Function(String)? onLog,
  }) async {
    void _log(String msg) => onLog?.call(msg);

    final baseUrl = await _getBaseUrl();
    if (baseUrl.isEmpty) {
      throw const AuthException('Servidor no configurado');
    }

    final url = Uri.parse('$baseUrl/api/v1/login');
    _log('🌐 URL de login: $url');
    
    http.Response response;
    try {
      _log('📡 Enviando credenciales...');
      response = await http
          .post(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'password': password,
              'device_name': deviceName,
            }),
          )
          .timeout(const Duration(seconds: 30));
      _log('📥 Respuesta recibida: ${response.statusCode}');
    } catch (e) {
      _log('❌ Error de conexión: $e');
      throw AuthException('Error de conexión: $e');
    }

    _log('📄 Body: ${response.body.substring(0, (response.body.length > 200) ? 200 : response.body.length)}');

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      _log('❌ No se pudo parsear JSON');
      throw AuthException('Respuesta inválida del servidor', statusCode: response.statusCode);
    }

    if (response.statusCode == 200) {
      _log('✅ Autenticación exitosa');
      final data = (json['data'] is Map<String, dynamic>) ? (json['data'] as Map<String, dynamic>) : <String, dynamic>{};
      final token = (data['token'] ?? '').toString();
      if (token.isEmpty) {
        _log('❌ Token vacío en respuesta');
        throw const AuthException('Login incompleto: token ausente');
      }

      final userMap = (data['user'] is Map<String, dynamic>) ? (data['user'] as Map<String, dynamic>) : <String, dynamic>{};
      final user = User.fromJson(userMap);

      await StorageService.saveApiToken(token);
      // Guardamos también el usuario (para compatibilidad con el resto de la app)
      await StorageService.saveUser(user);

      return user;
    }

    final msg = (json['message'] ?? 'Error de autenticación').toString();
    _log('❌ Error ${response.statusCode}: $msg');
    throw AuthException(msg, statusCode: response.statusCode);
  }

  static Future<void> logout() async {
    await StorageService.clearApiToken();
    await StorageService.clearSession();
  }
}

