import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/worker_data.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';

class SetupService {
  static const String _tempServerUrlKey = 'temp_server_url';
  static const String _setupCompletedKey = 'setup_completed';
  static const String _workerDataKey = 'worker_data';

  /// Verifica si la configuración inicial está completa
  static Future<bool> isSetupCompleted() async {
    return await StorageService.getBool(_setupCompletedKey) ?? false;
  }

  /// Prueba la conexión con el servidor
  static Future<bool> testServerConnection(String serverUrl, {Function(String)? onLog}) async {
    final log = onLog ?? (String message) => print('SetupService: $message');

    try {
      log('🔄 Iniciando prueba de conexión...');
      log('📝 URL del servidor: $serverUrl');

      // Normalizar la URL
      final normalizedUrl = _normalizeUrl(serverUrl);
      log('🔧 URL normalizada: $normalizedUrl');

      final url = Uri.parse('$normalizedUrl/api/v1/config/ping');
      log('🌐 Intentando conectar a: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      log('📡 Respuesta del servidor - Código: ${response.statusCode}');

      if (response.statusCode == 200) {
        log('✅ Conexión exitosa - Servidor responde correctamente');
        return true;
      } else {
        log('❌ Error HTTP: ${response.statusCode} - ${response.reasonPhrase}');
        return false;
      }
    } catch (e) {
      log('💥 Error de conexión: ${e.toString()}');
      return false;
    }
  }

  /// Normaliza la URL para asegurar que tenga el formato correcto
  static String _normalizeUrl(String url) {
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Guarda temporalmente la URL del servidor durante la configuración
  static Future<void> saveTempServerUrl(String serverUrl) async {
    await StorageService.setString(_tempServerUrlKey, serverUrl);
  }

  /// Obtiene la URL del servidor temporal
  static Future<String?> getTempServerUrl() async {
    return await StorageService.getString(_tempServerUrlKey);
  }

  /// Carga los datos del trabajador usando el código secreto
  static Future<WorkerData?> loadWorkerData(String workerCode, {Function(String)? onLog}) async {
    final log = onLog ?? (String message) => print('SetupService: $message');

    try {
      final serverUrl = await getTempServerUrl();
      if (serverUrl == null) {
        log('❌ No hay URL del servidor configurada');
        throw SetupException('URL del servidor no configurada');
      }

      log('🔄 Iniciando carga de datos del trabajador...');
      log('👤 Código del trabajador: $workerCode');
      log('📝 URL del servidor: $serverUrl');

      final normalizedUrl = _normalizeUrl(serverUrl);
      final url = Uri.parse('$normalizedUrl/api/mobile/worker/$workerCode');
      log('🌐 URL completa: $url');

      log('📡 Enviando petición GET...');
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      log('📡 Respuesta del servidor - Código: ${response.statusCode}');

      if (response.statusCode == 200) {
        log('✅ Respuesta exitosa, procesando datos...');
        final jsonData = json.decode(response.body);
        log('📦 Datos recibidos correctamente');

        final workerData = WorkerData.fromJson(jsonData);
        log('✅ Datos del trabajador procesados exitosamente');
        log('👤 Nombre: ${workerData.user.name}');
        log('🏢 Centro: ${workerData.workCenter.name}');
        log('📅 Horarios: ${workerData.schedule.length} tramos');
        log('🎉 Festivos: ${workerData.holidays.length} días');

        return workerData;
      } else if (response.statusCode == 404) {
        log('❌ Trabajador no encontrado (404)');
        return null; // Trabajador no encontrado
      } else {
        log('❌ Error del servidor: ${response.statusCode} - ${response.body}');
        throw APIException(
          'Error del servidor: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      log('💥 Error al cargar datos: ${e.toString()}');
      if (e is APIException) rethrow;
      throw SetupException('Error de conexión: ${e.toString()}');
    }
  }

  /// Guarda todos los datos del trabajador y marca la configuración como completa
  static Future<void> saveWorkerData(WorkerData workerData) async {
    try {
      // Guardar la URL del servidor permanentemente
      final serverUrl = await getTempServerUrl();
      if (serverUrl != null) {
        await StorageService.setString('server_url', serverUrl);
      }

      // Guardar los datos del trabajador
      final workerDataJson = json.encode(workerData.toJson());
      await StorageService.setString(_workerDataKey, workerDataJson);

      // Guardar datos individuales para compatibilidad con el código existente
      await StorageService.saveUser(workerData.user);
      await StorageService.saveWorkCenter(workerData.workCenter);

      // Guardar horario y festivos
      await _saveSchedule(workerData.schedule);
      await _saveHolidays(workerData.holidays);

      // Marcar configuración como completa
      await StorageService.setBool(_setupCompletedKey, true);

      // Limpiar datos temporales
      await StorageService.remove(_tempServerUrlKey);

    } catch (e) {
      print('Error saving worker data: $e');
      throw SetupException('Error al guardar configuración: ${e.toString()}');
    }
  }

  /// Obtiene los datos del trabajador guardados
  static Future<WorkerData?> getSavedWorkerData() async {
    try {
      final workerDataJson = await StorageService.getString(_workerDataKey);
      if (workerDataJson == null) return null;

      final jsonData = json.decode(workerDataJson);
      return WorkerData.fromJson(jsonData);
    } catch (e) {
      print('Error getting saved worker data: $e');
      return null;
    }
  }

  /// Obtiene la URL del servidor configurado
  static Future<String?> getConfiguredServerUrl() async {
    return await StorageService.getString('server_url');
  }

  /// Obtiene el horario guardado
  static Future<List<ScheduleEntry>> getSavedSchedule() async {
    try {
      final workerData = await getSavedWorkerData();
      return workerData?.schedule ?? [];
    } catch (e) {
      print('Error getting saved schedule: $e');
      return [];
    }
  }

  /// Obtiene los festivos guardados
  static Future<List<Holiday>> getSavedHolidays() async {
    try {
      final workerData = await getSavedWorkerData();
      return workerData?.holidays ?? [];
    } catch (e) {
      print('Error getting saved holidays: $e');
      return [];
    }
  }

  /// Verifica si una fecha es festiva
  static Future<bool> isHoliday(DateTime date) async {
    final holidays = await getSavedHolidays();
    final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
    return holidays.any((holiday) => holiday.date == dateStr);
  }

  /// Obtiene el horario para un día específico
  static Future<ScheduleEntry?> getScheduleForDay(String dayOfWeek) async {
    final schedule = await getSavedSchedule();
    try {
      return schedule.firstWhere(
        (entry) => entry.dayOfWeek.toLowerCase() == dayOfWeek.toLowerCase() && entry.isActive,
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