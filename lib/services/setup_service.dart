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
  static Future<bool> testServerConnection(String serverUrl) async {
    try {
      final url = Uri.parse('$serverUrl/api/health');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error testing server connection: $e');
      return false;
    }
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
  static Future<WorkerData?> loadWorkerData(String workerCode) async {
    try {
      final serverUrl = await getTempServerUrl();
      if (serverUrl == null) {
        throw SetupException('URL del servidor no configurada');
      }

      final url = Uri.parse('$serverUrl/api/mobile/worker/$workerCode');
      print('Loading worker data from: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return WorkerData.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        return null; // Trabajador no encontrado
      } else {
        throw APIException(
          'Error del servidor: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('Error loading worker data: $e');
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