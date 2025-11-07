import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/work_center.dart';
import '../models/user.dart';
import '../models/api_response.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';

class StorageService {
  static SharedPreferences? _prefs;

  // Inicializar SharedPreferences
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Asegurar que SharedPreferences está inicializado
  static Future<SharedPreferences> get _preferences async {
    if (_prefs == null) await init();
    return _prefs!;
  }

  // Método público para acceder a SharedPreferences (para casos especiales)
  static Future<SharedPreferences> get preferences async {
    return await _preferences;
  }

  // WorkCenter operations
  static Future<void> saveWorkCenter(WorkCenter workCenter) async {
    try {
      final prefs = await _preferences;
      await prefs.setString(
        AppConstants.keyWorkCenter,
        jsonEncode(workCenter.toJson()),
      );
    } catch (e) {
      throw StorageException('Error guardando centro de trabajo: $e');
    }
  }

  static Future<WorkCenter?> getWorkCenter() async {
    try {
      final prefs = await _preferences;
      final data = prefs.getString(AppConstants.keyWorkCenter);
      if (data != null) {
        return WorkCenter.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw StorageException('Error cargando centro de trabajo: $e');
    }
  }

  static Future<void> clearWorkCenter() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(AppConstants.keyWorkCenter);
    } catch (e) {
      throw StorageException('Error limpiando centro de trabajo: $e');
    }
  }

  // User operations
  static Future<void> saveUser(User user) async {
    try {
      final prefs = await _preferences;
      await prefs.setString(
        AppConstants.keyUser,
        jsonEncode(user.toJson()),
      );
    } catch (e) {
      throw StorageException('Error guardando usuario: $e');
    }
  }

  static Future<User?> getUser() async {
    try {
      final prefs = await _preferences;
      final data = prefs.getString(AppConstants.keyUser);
      if (data != null) {
        return User.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw StorageException('Error cargando usuario: $e');
    }
  }

  static Future<void> clearUser() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(AppConstants.keyUser);
    } catch (e) {
      throw StorageException('Error limpiando usuario: $e');
    }
  }

  // Offline events operations
  static Future<void> saveOfflineEvents(List<OfflineClockEvent> events) async {
    try {
      final prefs = await _preferences;
      final eventsJson = events.map((e) => e.toJson()).toList();
      await prefs.setString(
        AppConstants.keyOfflineEvents,
        jsonEncode(eventsJson),
      );
    } catch (e) {
      throw StorageException('Error guardando eventos offline: $e');
    }
  }

  static Future<List<OfflineClockEvent>> getOfflineEvents() async {
    try {
      final prefs = await _preferences;
      final data = prefs.getString(AppConstants.keyOfflineEvents);
      if (data != null) {
        final List<dynamic> eventsJson = jsonDecode(data) as List<dynamic>;
        return eventsJson
            .map((e) => OfflineClockEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw StorageException('Error cargando eventos offline: $e');
    }
  }

  static Future<void> addOfflineEvent(OfflineClockEvent event) async {
    try {
      final events = await getOfflineEvents();
      events.add(event);
      await saveOfflineEvents(events);
    } catch (e) {
      throw StorageException('Error añadiendo evento offline: $e');
    }
  }

  static Future<void> clearOfflineEvents() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(AppConstants.keyOfflineEvents);
    } catch (e) {
      throw StorageException('Error limpiando eventos offline: $e');
    }
  }

  static Future<void> markEventsAsSynced(List<String> eventIds) async {
    try {
      final events = await getOfflineEvents();
      final updatedEvents = events.map((event) {
        // Aquí necesitarías un ID único para cada evento
        // Por simplicidad, usamos timestamp como identificador
        return event;
      }).toList();
      await saveOfflineEvents(updatedEvents);
    } catch (e) {
      throw StorageException('Error marcando eventos como sincronizados: $e');
    }
  }

  // Last sync operations
  static Future<void> saveLastSyncTime(DateTime syncTime) async {
    try {
      final prefs = await _preferences;
      await prefs.setString(
        AppConstants.keyLastSync,
        syncTime.toIso8601String(),
      );
    } catch (e) {
      throw StorageException('Error guardando tiempo de sincronización: $e');
    }
  }

  static Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await _preferences;
      final data = prefs.getString(AppConstants.keyLastSync);
      if (data != null) {
        return DateTime.parse(data);
      }
      return null;
    } catch (e) {
      throw StorageException('Error cargando tiempo de sincronización: $e');
    }
  }

  // Session operations
  static Future<bool> hasValidSession() async {
    final workCenter = await getWorkCenter();
    final user = await getUser();
    return workCenter != null && user != null;
  }

  static Future<Map<String, dynamic>?> getSessionData() async {
    final workCenter = await getWorkCenter();
    final user = await getUser();

    if (workCenter != null && user != null) {
      return {
        'work_center': workCenter.toJson(),
        'user': user.toJson(),
      };
    }
    return null;
  }

  static Future<void> clearSession() async {
    await Future.wait([
      clearWorkCenter(),
      clearUser(),
      clearOfflineEvents(),
    ]);
  }

  // Configuration operations
  static Future<void> saveConfig(String key, dynamic value) async {
    try {
      final prefs = await _preferences;
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else {
        await prefs.setString(key, jsonEncode(value));
      }
    } catch (e) {
      throw StorageException('Error guardando configuración: $e');
    }
  }

  static Future<T?> getConfig<T>(String key) async {
    try {
      final prefs = await _preferences;

      if (T == String) {
        return prefs.getString(key) as T?;
      } else if (T == int) {
        return prefs.getInt(key) as T?;
      } else if (T == bool) {
        return prefs.getBool(key) as T?;
      } else if (T == double) {
        return prefs.getDouble(key) as T?;
      } else {
        final data = prefs.getString(key);
        if (data != null) {
          return jsonDecode(data) as T;
        }
      }
      return null;
    } catch (e) {
      throw StorageException('Error cargando configuración: $e');
    }
  }
}
