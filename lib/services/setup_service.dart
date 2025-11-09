import 'dart:async';
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
      // Preferir la URL temporal durante el asistente, pero si no existe
      // usar la URL configurada permanentemente (caso de uso normal de la app).
      String? serverUrl = await getTempServerUrl();
      if (serverUrl == null) {
        serverUrl = await getConfiguredServerUrl();
      }

      if (serverUrl == null) {
        log('❌ No hay URL del servidor configurada');
        throw SetupException('URL del servidor no configurada');
      }

      log('🔄 Iniciando carga de datos del trabajador...');
      log('👤 Código del trabajador: $workerCode');
      log('📝 URL del servidor: $serverUrl');

  final normalizedUrl = _normalizeUrl(serverUrl);
  // Unified mobile worker endpoint under /api/v1/mobile/worker
  final url = Uri.parse('$normalizedUrl/api/v1/mobile/worker/$workerCode');
      log('🌐 URL completa: $url');

      log('📡 Enviando petición GET...');
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      log('📡 Respuesta del servidor - Código: ${response.statusCode}');

      // Intentar extraer la cookie de sesión (laravel_session) si el
      // servidor la ha enviado en el header 'set-cookie'. Esto permite
      // reutilizar la sesión en llamadas posteriores (/status, /clock).
      try {
        final cookieHeader = response.headers['set-cookie'];
        if (cookieHeader != null && cookieHeader.contains('laravel_session=')) {
          final match = RegExp(r'laravel_session=([^;]+)').firstMatch(cookieHeader);
          if (match != null) {
            final laravelSession = match.group(1);
            if (laravelSession != null && laravelSession.isNotEmpty) {
              try {
                await StorageService.saveLaravelSessionCookie(laravelSession);
                log('🔐 laravel_session guardada localmente');
              } catch (e) {
                log('⚠️ Error guardando laravel_session: $e');
              }
            }
          }
        } else {
          log('ℹ️ No se detectó laravel_session en set-cookie');
        }
      } catch (e) {
        log('⚠️ Error parseando set-cookie: $e');
      }

        if (response.statusCode == 200) {
        log('✅ Respuesta exitosa, procesando datos...');
        final decoded = json.decode(response.body);
        log('📦 Datos recibidos (raw): ${decoded.runtimeType}');

        // La API devuelve { success: true, data: { ... } }
        // Asegurarnos de extraer el mapa correcto con los campos esperados
        Map<String, dynamic>? payload;
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
            payload = decoded['data'] as Map<String, dynamic>;
          } else {
            payload = decoded as Map<String, dynamic>;
          }
        }

        if (payload == null) {
          log('❌ Respuesta inesperada: payload nulo');
          throw SetupException('Respuesta inesperada del servidor');
        }

        log('📦 Payload a procesar: keys=${payload.keys.toList()}');
        try {
          log('📦 Payload completo: ${json.encode(payload)}');
        } catch (e) {
          log('📦 Payload completo (no serializable): $e');
        }

        final workerData = WorkerData.fromJson(payload);
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

      // DEBUG: comprobar que se ha guardado el JSON completo
      try {
        final saved = await StorageService.getString(_workerDataKey);
        print('DEBUG: worker_data guardado: $saved');
      } catch (e) {
        print('DEBUG: error leyendo worker_data tras guardar: $e');
      }

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

      final decoded = json.decode(workerDataJson);
      Map<String, dynamic>? payload;
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
          payload = decoded['data'] as Map<String, dynamic>;
        } else {
          payload = decoded as Map<String, dynamic>;
        }
      }

      if (payload == null) return null;
      return WorkerData.fromJson(payload);
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

  /// Actualiza (sobrescribe) los datos del trabajador guardados sin tocar
  /// la URL del servidor ni el estado de setup. Útil para refrescar datos
  /// cuando se detecta conectividad.
  static Future<void> updateSavedWorkerData(WorkerData workerData) async {
    try {
      final workerDataJson = json.encode(workerData.toJson());
      await StorageService.setString(_workerDataKey, workerDataJson);

      // DEBUG: comprobar que se ha guardado el JSON completo tras update
      try {
        final saved = await StorageService.getString(_workerDataKey);
        print('DEBUG: worker_data actualizado: $saved');
      } catch (e) {
        print('DEBUG: error leyendo worker_data tras update: $e');
      }

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

      print('SetupService: updateSavedWorkerData -> datos actualizados localmente');
    } catch (e) {
      print('SetupService: Error updateSavedWorkerData: $e');
      throw SetupException('Error al actualizar datos del trabajador: ${e.toString()}');
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
  static Future<void> refreshSavedWorkerData({Function(String)? onLog, bool blocking = false, Duration timeout = const Duration(seconds: 3)}) async {
    final log = onLog ?? (String m) => print('SetupService: $m');

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