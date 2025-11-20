import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import '../models/clock_status.dart';
import '../services/setup_service.dart';
import '../services/config_service.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';

class ClockService {
  // Obtener URL base dinámicamente
  static Future<String> _getBaseUrl() async {
    // Primero intentar obtener la URL configurada en el setup
    final setupUrl = await SetupService.getConfiguredServerUrl();
    if (setupUrl != null) {
      return _normalizeUrl(setupUrl);
    }

    // If no setup URL, use previous configuration
    final configuredUrl = await ConfigService.getCurrentServerUrl();
    final baseUrl = configuredUrl ?? AppConstants.apiBaseUrl;

    return _normalizeUrl(baseUrl);
  }

  // Normalizar la URL para evitar duplicados
  static String _normalizeUrl(String baseUrl) {
    if (baseUrl.endsWith('/api/v1/mobile')) {
      return baseUrl;
    } else if (baseUrl.endsWith('/api/v1')) {
      return '$baseUrl/mobile';
    } else {
      return '$baseUrl/api/v1/mobile';
    }
  }

  // Realizar fichaje
  static Future<ApiResponse<ClockStatus>> performClock({
    required String workCenterCode,
    required String userCode,
    String? action, // 'pause', 'resume_workday', 'clock_out', etc.
    int? pauseEventId, // Nuevo parámetro opcional
    int? eventTypeId, // Nuevo parámetro para clock_in
    String? observations, // Nuevo parámetro para observaciones
  }) async {
    try {
      // Intentar refrescar datos del trabajador guardado antes de cualquier
      // acción que haga una conexión. Esto asegura que la app tenga los
      // datos más recientes del trabajador y evita errores por user not found.
      try {
        // Hacemos un refresh bloqueante pero con timeout corto para evitar
        // latencias largas: si la API responde rápido, tendremos datos
        // actualizados; si no, procedemos con los datos en caché.
        await SetupService.refreshSavedWorkerData(
            blocking: true, timeout: const Duration(seconds: 3));
      } catch (_) {
        // Silenciar: no queremos que un fallo en el refresh impida el fichaje
      }
      final baseUrl = await _getBaseUrl();
      final body = {
        'work_center_code': workCenterCode,
        'user_code': userCode,
        if (action != null) 'action': action,
        if (pauseEventId != null) 'pause_event_id': pauseEventId,
        if (eventTypeId != null) 'event_type_id': eventTypeId,
        if (observations != null) 'observations': observations,
      };
      final response = await http
          .post(
            Uri.parse('$baseUrl/clock'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<ClockStatus>.fromJson(
          jsonData,
          (data) => ClockStatus.fromJson(data),
        );
      } else {
        // Asegura que el mensaje sea siempre String
        final msg = jsonData['message'];
        throw ClockException(
          msg is String ? msg : (msg?.toString() ?? 'Clock error'),
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
    required String userCode,
  }) async {
    try {
      // Refrescar datos del trabajador antes de consultar estado
      try {
        await SetupService.refreshSavedWorkerData(
            blocking: true, timeout: const Duration(seconds: 3));
      } catch (_) {}
      final baseUrl = await _getBaseUrl();
      final bodyJson = jsonEncode({
        'user_code': userCode,
      });
      final response = await http
          .post(
            Uri.parse('$baseUrl/status'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: bodyJson,
          )
          .timeout(const Duration(seconds: 15));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<ClockStatus>.fromJson(
          jsonData,
          (data) => ClockStatus.fromJson(data),
        );
      } else {
        // Asegura que el mensaje sea siempre String
        final msg = jsonData['message'];
        throw ClockException(
          msg is String ? msg : (msg?.toString() ?? 'Status error'),
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
      // Refrescar datos guardados antes de sincronizar
      try {
        await SetupService.refreshSavedWorkerData(
            blocking: true, timeout: const Duration(seconds: 3));
      } catch (_) {}
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
          jsonData['message'] ?? 'Sync error',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is SyncException) rethrow;
      throw NetworkException('Error de conexión: $e');
    }
  }

  // Validar conectividad con el servidor
  // static Future<bool> checkConnectivity() async {
  //   // Implementar si es necesario
  // }

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
