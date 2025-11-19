import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/worker_data.dart';
import '../services/storage_service.dart';
import '../utils/exceptions.dart';

class SetupService {
  static const String _tempServerUrlKey = 'temp_server_url';
  static const String _setupCompletedKey = 'setup_completed';
  static const String _workerDataKey = 'worker_data';

  /// Centralized logging function
  static void _log(String message, {Function(String)? onLog}) {
    onLog?.call(message);
  }

  /// Checks if initial setup is complete
  static Future<bool> isSetupCompleted() async {
    return await StorageService.getBool(_setupCompletedKey) ?? false;
  }

  /// Tests server connection
  static Future<bool> testServerConnection(String serverUrl,
      {Function(String)? onLog}) async {
    try {
      _log('🔄 Iniciando prueba de conexión...', onLog: onLog);
      _log('📝 Server URL: $serverUrl', onLog: onLog);

      final normalizedUrl = _normalizeUrl(serverUrl);
      _log('🔧 URL normalizada: $normalizedUrl', onLog: onLog);

      final url = Uri.parse('$normalizedUrl/api/v1/config/ping');
      _log('🌐 Intentando conectar a: $url', onLog: onLog);

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      _log('📡 Server response - Code: ${response.statusCode}', onLog: onLog);

      if (response.statusCode == 200) {
        _log('✅ Connection successful - Server responded correctly',
            onLog: onLog);
        return true;
      } else {
        _log('❌ HTTP error: ${response.statusCode} - ${response.reasonPhrase}',
            onLog: onLog);
        return false;
      }
    } catch (e) {
      _log('💥 Connection error: ${e.toString()}', onLog: onLog);
      return false;
    }
  }

  /// Normaliza la URL para asegurar que tenga el formato correcto
  static String _normalizeUrl(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Temporarily saves the server URL during setup
  static Future<void> saveTempServerUrl(String serverUrl) async {
    await StorageService.setString(_tempServerUrlKey, serverUrl);
  }

  /// Gets the temporary server URL
  static Future<String?> getTempServerUrl() async {
    return await StorageService.getString(_tempServerUrlKey);
  }

  /// Loads worker data using the secret code
  static Future<WorkerData?> loadWorkerData(String workerCode,
      {Function(String)? onLog}) async {
    try {
      String? serverUrl =
          await getTempServerUrl() ?? await getConfiguredServerUrl();

      if (serverUrl == null) {
        _log('❌ No server URL configured', onLog: onLog);
        throw SetupException('Server URL not configured');
      }

      _log('🔄 Iniciando carga de datos del trabajador...', onLog: onLog);
      _log('👤 Worker code: $workerCode', onLog: onLog);
      _log('📝 Server URL: $serverUrl', onLog: onLog);

      final normalizedUrl = _normalizeUrl(serverUrl);
      final url = Uri.parse('$normalizedUrl/api/v1/mobile/worker/$workerCode');
      _log('🌐 URL completa: $url', onLog: onLog);

      final response = await http.get(url).timeout(const Duration(seconds: 30));

      _log('📡 Server response - Code: ${response.statusCode}', onLog: onLog);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final payload =
            decoded is Map<String, dynamic> && decoded.containsKey('data')
                ? decoded['data']
                : decoded;

        if (payload == null) {
          _log('❌ Respuesta inesperada: payload nulo', onLog: onLog);
          throw SetupException('Unexpected server response');
        }

        _log('📦 Payload procesado correctamente', onLog: onLog);
        return WorkerData.fromJson(payload);
      } else if (response.statusCode == 404) {
        _log('❌ Trabajador no encontrado (404)', onLog: onLog);
        return null;
      } else {
        _log('❌ Server error: ${response.statusCode} - ${response.body}',
            onLog: onLog);
        throw APIException(
          'Server error: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      _log('💥 Error loading data: ${e.toString()}', onLog: onLog);
      if (e is APIException) rethrow;
      throw SetupException('Connection error: ${e.toString()}');
    }
  }

  /// Saves all worker data and marks setup as complete
  static Future<void> saveWorkerData(WorkerData workerData) async {
    try {
      final serverUrl = await getTempServerUrl();
      if (serverUrl != null) {
        await StorageService.setString('server_url', serverUrl);
      }

      final workerDataJson = json.encode(workerData.toJson());
      await StorageService.setString(_workerDataKey, workerDataJson);

      await StorageService.saveUser(workerData.user);
      await StorageService.saveWorkCenter(workerData.workCenter);
      await _saveSchedule(workerData.schedule);
      await _saveHolidays(workerData.holidays);

      await StorageService.setBool(_setupCompletedKey, true);
      await StorageService.remove(_tempServerUrlKey);
    } catch (e) {
      throw SetupException('Error saving setup: ${e.toString()}');
    }
  }

  /// Gets saved worker data
  static Future<WorkerData?> getSavedWorkerData() async {
    try {
      final workerDataJson = await StorageService.getString(_workerDataKey);
      if (workerDataJson == null) return null;

      final decoded = json.decode(workerDataJson);
      Map<String, dynamic>? payload;
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('data') &&
            decoded['data'] is Map<String, dynamic>) {
          payload = decoded['data'];
        } else {
          payload = decoded;
        }
      }

      if (payload == null) return null;
      return WorkerData.fromJson(payload);
    } catch (e) {
      print('Error getting saved worker data: $e'); // Already in English
      return null;
    }
  }

  /// Gets configured server URL
  static Future<String?> getConfiguredServerUrl() async {
    return await StorageService.getString('server_url');
  }

  /// Gets saved schedule
  static Future<List<ScheduleEntry>> getSavedSchedule() async {
    try {
      final workerData = await getSavedWorkerData();
      return workerData?.schedule ?? [];
    } catch (e) {
      print('Error getting saved schedule: $e'); // Already in English
      return [];
    }
  }

  /// Gets saved holidays
  static Future<List<Holiday>> getSavedHolidays() async {
    try {
      final workerData = await getSavedWorkerData();
      return workerData?.holidays ?? [];
    } catch (e) {
      print('Error getting saved holidays: $e'); // Already in English
      return [];
    }
  }

  /// Verifica si una fecha es festiva
  static Future<bool> isHoliday(DateTime date) async {
    final holidays = await getSavedHolidays();
    final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
    return holidays.any((holiday) => holiday.date == dateStr);
  }

  /// Gets schedule for a specific day
  static Future<ScheduleEntry?> getScheduleForDay(String dayOfWeek) async {
    final schedule = await getSavedSchedule();
    try {
      return schedule.firstWhere(
        (entry) =>
            entry.dayOfWeek.toLowerCase() == dayOfWeek.toLowerCase() &&
            entry.isActive,
      );
    } catch (e) {
      return null; // No schedule found for this day
    }
  }

  /// Resetea toda la configuración (para desarrollo/testing)
  static Future<void> resetSetup() async {
    await StorageService.remove(_setupCompletedKey);
    await StorageService.remove(_workerDataKey);
    await StorageService.remove('server_url');
    await StorageService.remove(_tempServerUrlKey);
  }

  /// Actualiza (sobrescribe) los datos del trabajador guardados sin tocar
  /// la URL del servidor ni el estado de setup. Útil para refrescar datos
  /// cuando se detecta conectividad.
  static Future<void> updateSavedWorkerData(WorkerData workerData) async {
    try {
      final workerDataJson = json.encode(workerData.toJson());
      await StorageService.setString(_workerDataKey, workerDataJson);

      // Guardar datos individuales para compatibilidad con el código existente
      await StorageService.saveUser(workerData.user);
      await StorageService.saveWorkCenter(workerData.workCenter);

      // Guardar horario y festivos
      await _saveSchedule(workerData.schedule);
      await _saveHolidays(workerData.holidays);

      // Registrar timestamp de la actualización para la UI
      try {
        await StorageService.saveWorkerLastUpdate(DateTime.now());
      } catch (e) {
        // No bloquear si el guardado del timestamp falla
        print('SetupService: warning saving worker last update: $e');
      }

      // print(
      //     'SetupService: updateSavedWorkerData -> datos actualizados localmente');
    } catch (e) {
      print('SetupService: Error updateSavedWorkerData: $e');
      throw SetupException(
          'Error al actualizar datos del trabajador: ${e.toString()}');
    }
  }

  /// Refresca los datos del trabajador guardado, si existe un usuario en
  /// almacenamiento local. Hace una llamada a la API y actualiza los datos
  /// locales si se reciben correctamente.
  /// Refresca los datos del trabajador guardado.
  ///
  /// Parámetros:
  /// - [onLog]: callback para logging.
  /// - [blocking]: si true, la función esperará a que termine el refresh
  ///   (hasta [timeout]) y se podrá usar para asegurar que los datos están
  ///   actualizados antes de proceder. Si false (por defecto), el refresh se
  ///   lanza en background y no bloqueará al llamador.
  /// - [timeout]: duración máxima a esperar cuando [blocking] es true.
  static Future<void> refreshSavedWorkerData(
      {Function(String)? onLog,
      bool blocking = false,
      Duration timeout = const Duration(seconds: 3)}) async {
    final log = onLog ?? (String m) => {}; // Reemplazar print con función vacía

    try {
      final savedUser = await StorageService.getUser();
      if (savedUser == null) {
        log('No hay usuario guardado para refrescar');
        return;
      }

      log('Refrescando datos para usuario: ${savedUser.code} (blocking=$blocking)');

      Future<void> doRefresh() async {
        try {
          final workerData = await loadWorkerData(savedUser.code, onLog: onLog);
          if (workerData != null) {
            await updateSavedWorkerData(workerData);
            log('Datos del trabajador refrescados y guardados localmente');
          } else {
            log('La API no devolvió datos para el trabajador durante el refresh');
          }
        } catch (e) {
          log('Error durante loadWorkerData en refresh: ${e.toString()}');
        }
      }

      if (blocking) {
        try {
          await doRefresh().timeout(timeout);
        } on TimeoutException catch (_) {
          log('Timeout al refrescar datos del trabajador (timeout=${timeout.inSeconds}s)');
        } catch (e) {
          log('Error al refrescar datos del trabajador: ${e.toString()}');
        }
      } else {
        // Ejecutar en background sin esperar
        unawaited(doRefresh());
      }
    } catch (e) {
      log('Error refrescando datos del trabajador: ${e.toString()}');
      // No rethrow: no queremos bloquear la operación principal por el refresh
    }
  }

  // Métodos privados auxiliares
  static Future<void> _saveSchedule(List<ScheduleEntry> schedule) async {
    final scheduleJson = json.encode(schedule.map((e) => e.toJson()).toList());
    await StorageService.setString('worker_schedule', scheduleJson);
  }

  static Future<void> _saveHolidays(List<Holiday> holidays) async {
    final holidaysJson = json.encode(holidays.map((e) => e.toJson()).toList());
    await StorageService.setString('worker_holidays', holidaysJson);
  }
}
