import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/server_config.dart';
import '../models/work_center.dart';
import '../utils/exceptions.dart';
import '../services/setup_service.dart';
import 'storage_service.dart';

class ConfigService {
  static const String _serverUrlKey = 'server_url';
  static const String _serverConfigKey = 'server_config';

  /// Configura el servidor automáticamente usando una URL
  static Future<bool> configureServer(String serverUrl,
      {Function(String)? onLog}) async {
    final log = onLog ?? (String message) => print(message);

    log('🔄 Iniciando configuración del servidor...');
    log('📝 URL original introducida: $serverUrl');

    try {
      // Normalizar la URL para asegurar que tenga protocolo
      final normalizedUrl = _normalizeUrl(serverUrl);
      log('🔧 URL normalizada: $normalizedUrl');

      // Hacer una petición al endpoint de configuración
      final configUrl = '$normalizedUrl/api/v1/config/server';
      log('🌐 Intentando conectar a: $configUrl');

      final response = await http.get(
        Uri.parse(configUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      log('📡 Respuesta del servidor - Código: ${response.statusCode}');

      if (response.statusCode == 200) {
        log('✅ Respuesta exitosa, procesando configuración...');
        final configData = json.decode(utf8.decode(response.bodyBytes));
        final serverConfig = ServerConfig.fromJson(configData['data']);

        // Validar que los endpoints requeridos estén disponibles
        if (serverConfig.endpoints.nfc.workCenters.isEmpty ||
            serverConfig.endpoints.nfc.verifyTag.isEmpty) {
          log('❌ Configuración del servidor incompleta');
          throw const ConfigException('Configuración del servidor incompleta');
        }

        // Guardar configuración (guardar la URL normalizada)
        await StorageService.saveConfig(_serverUrlKey, normalizedUrl);
        await StorageService.saveConfig(_serverConfigKey, configData);

        log('💾 Configuración guardada correctamente');
        log('🏢 Servidor configurado: ${serverConfig.serverInfo.name}');
        log('✅ Configuración completada exitosamente');

        return true;
      } else if (response.statusCode == 404) {
        log('❌ Error 404: Endpoint no encontrado en $configUrl');
        throw APIException(
          'Servidor encontrado pero endpoint no disponible.\nURL intentada: $configUrl\nVerifica que sea un servidor CTH válido.',
          statusCode: 404,
        );
      } else if (response.statusCode == 500) {
        log('❌ Error 500: Error interno del servidor en $configUrl');
        throw APIException(
          'Error interno del servidor en $configUrl.\nContacta al administrador.',
          statusCode: 500,
        );
      } else {
        log('❌ Error HTTP ${response.statusCode}: ${response.reasonPhrase}');
        throw APIException(
          'Error del servidor (${response.statusCode}) en $configUrl\n${response.reasonPhrase ?? "Sin detalles"}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      log('💥 Error durante la configuración: $e');
      if (e is ConfigException || e is APIException) {
        rethrow;
      }
      throw ConfigException('Error de conexión: $e');
    }
  }

  /// Verifica una etiqueta NFC con el servidor configurado
  static Future<WorkCenter?> verifyNFCTag(String workCenterId) async {
    try {
      final serverUrl = await getCurrentServerUrl();
      if (serverUrl == null) {
        throw const ConfigException('No hay servidor configurado');
      }

      final verifyUrl = '$serverUrl/api/v1/nfc/verify';
      final response = await http.post(
        Uri.parse(verifyUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({'nfc_id': workCenterId}),
      );

      if (response.statusCode == 200) {
        // Validar que la respuesta tenga contenido
        final responseBody = utf8.decode(response.bodyBytes);
        if (responseBody.trim().isEmpty) {
          throw const APIException('Respuesta vacía del servidor');
        }

        dynamic decodedData;
        try {
          decodedData = json.decode(responseBody);
        } catch (e) {
          throw APIException('Respuesta JSON inválida del servidor: $e');
        }

        // Validar que la respuesta sea un Map
        if (decodedData == null || decodedData is! Map<String, dynamic>) {
          throw const APIException(
              'Formato de respuesta inválido del servidor');
        }

        final data = decodedData;

        // Validar estructura de la respuesta
        if (!data.containsKey('success')) {
          throw const APIException('Respuesta del servidor incompleta');
        }

        if (data['success'] == true) {
          if (data.containsKey('work_center')) {
            final workCenterData = data['work_center'];
            if (workCenterData != null &&
                workCenterData is Map<String, dynamic>) {
              try {
                final workCenter = WorkCenter.fromJson(workCenterData);
                return workCenter;
              } catch (e) {
                throw APIException(
                    'Error procesando datos del centro de trabajo: $e');
              }
            } else {
              throw const NFCVerificationException(
                  'Datos del centro de trabajo inválidos');
            }
          } else {
            throw const NFCVerificationException(
                'Centro de trabajo no encontrado en la respuesta');
          }
        } else {
          final message = data['message'] as String? ??
              'Error desconocido en verificación NFC';
          throw NFCVerificationException(message);
        }
      } else {
        // Manejar errores HTTP
        String errorMessage = 'Error del servidor (${response.statusCode})';
        try {
          final errBody = utf8.decode(response.bodyBytes);
          if (errBody.isNotEmpty) {
            final errorData = json.decode(errBody);
            if (errorData is Map<String, dynamic> &&
                errorData.containsKey('message')) {
              errorMessage = errorData['message'] as String;
            }
          }
        } catch (e) {
          // Ignorar errores de parsing en respuestas de error
        }

        throw APIException(errorMessage, statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ConfigException ||
          e is NFCVerificationException ||
          e is APIException) {
        rethrow;
      }
      throw NFCVerificationException('Error verificando etiqueta: $e');
    }
  }

  /// Carga configuración guardada si existe
  static Future<bool> loadSavedConfiguration() async {
    try {
      final serverUrl = await StorageService.getConfig<String>(_serverUrlKey);
      final serverConfig = await StorageService.getConfig<Map<String, dynamic>>(
          _serverConfigKey);

      return serverUrl != null && serverConfig != null;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene la URL del servidor actual
  static Future<String?> getCurrentServerUrl() async {
    try {
      // Primero intentar obtener la URL configurada en el setup
      final setupUrl = await SetupService.getConfiguredServerUrl();
      if (setupUrl != null) {
        return setupUrl;
      }

      // Si no hay URL del setup, usar la configuración anterior
      return await StorageService.getConfig<String>(_serverUrlKey);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene la configuración del servidor actual
  static Future<ServerConfig?> getCurrentServerConfig() async {
    try {
      final configData = await StorageService.getConfig<Map<String, dynamic>>(
          _serverConfigKey);
      if (configData != null) {
        return ServerConfig.fromJson(configData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Limpia la configuración del servidor
  static Future<void> clearServerConfiguration() async {
    try {
      final prefs = await StorageService.preferences;
      await prefs.remove(_serverUrlKey);
      await prefs.remove(_serverConfigKey);
    } catch (e) {
      throw ConfigException('Error limpiando configuración: $e');
    }
  }

  /// Verifica si el servidor está disponible
  static Future<bool> isServerAvailable([String? serverUrl]) async {
    try {
      serverUrl ??= await getCurrentServerUrl();
      if (serverUrl == null) return false;

      final response = await http.get(
        Uri.parse('$serverUrl/api/v1/config/ping'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Normaliza una URL para asegurar que tenga el protocolo correcto
  static String _normalizeUrl(String url) {
    // Eliminar espacios en blanco
    url = url.trim();

    // Si no tiene protocolo, agregar https por defecto
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    // Eliminar barra final si existe
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }
}
