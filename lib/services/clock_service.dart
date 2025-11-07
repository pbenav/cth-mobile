import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import '../models/clock_status.dart';
import '../utils/exceptions.dart';
import '../utils/constants.dart';
import 'config_service.dart';

class ClockService {
  // Obtener URL base dinámicamente
  static Future<String> _getBaseUrl() async {
    final configuredUrl = await ConfigService.getCurrentServerUrl();
    final baseUrl = configuredUrl ?? AppConstants.apiBaseUrl;

    // Normalizar la URL para evitar duplicados
    if (baseUrl.endsWith('/api/v1/mobile')) {
      return baseUrl;
    } else if (baseUrl.endsWith('/api/v1')) {
      return '$baseUrl/mobile';
    } else {
      return '$baseUrl/api/v1/mobile';
    }
  }

  // Realizar fichaje
  static Future<ApiResponse<ClockResponse>> performClock({
    required String workCenterCode,
    required String userCode,
    String? action, // 'pause' or 'clock_out' when working
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/clock'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'work_center_code': workCenterCode,
              'user_secret_code': userCode,
              if (action != null) 'action': action,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<ClockResponse>.fromJson(
          jsonData,
          (data) => ClockResponse.fromJson(data),
        );
      } else {
        throw ClockException(
          jsonData['message'] ?? 'Error en fichaje',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ClockException) rethrow;
      throw NetworkException('Error de conexión: $e');
    }
  }

  // Obtener estado actual
  static Future<ApiResponse<ClockStatus>> getStatus({
    required String workCenterCode,
    required String userCode,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/status').replace(queryParameters: {
          'work_center_code': workCenterCode,
          'user_secret_code': userCode,
        }),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<ClockStatus>.fromJson(
          jsonData,
          (data) => ClockStatus.fromJson(data),
        );
      } else {
        throw ClockException(
          jsonData['message'] ?? 'Error obteniendo estado',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ClockException) rethrow;
      throw NetworkException('Error de conexión: $e');
    }
  }

  // Sincronizar datos offline
  static Future<ApiResponse<SyncResponse>> syncOfflineData({
    required String workCenterCode,
    required String userCode,
    required List<OfflineClockEvent> events,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/sync'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'work_center_code': workCenterCode,
              'user_code': userCode,
              'offline_events': events.map((e) => e.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<SyncResponse>.fromJson(
          jsonData,
          (data) => SyncResponse.fromJson(data),
        );
      } else {
        throw SyncException(
          jsonData['message'] ?? 'Error en sincronización',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is SyncException) rethrow;
      throw NetworkException('Error de conexión: $e');
    }
  }

  // Validar conectividad con el servidor
  static Future<bool> checkConnectivity() async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/status').replace(queryParameters: {
          'work_center_code': 'test',
          'user_code': 'test',
        }),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 422;
    } catch (e) {
      return false;
    }
  }

  // Obtener configuración del servidor
  static Future<Map<String, dynamic>?> getServerConfig() async {
    try {
      final configuredUrl = await ConfigService.getCurrentServerUrl();
      final baseUrl = configuredUrl ?? AppConstants.apiBaseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/config/server'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
