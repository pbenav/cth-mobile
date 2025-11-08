import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/server_config.dart';
import '../models/work_center.dart';
import '../utils/exceptions.dart';
import 'storage_service.dart';

class ConfigService {
  static const String _serverUrlKey = 'server_url';
  static const String _serverConfigKey = 'server_config';

  /// Configura el servidor automáticamente usando una URL
  static Future<bool> configureServer(String serverUrl, {Function(String)? onLog}) async {
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
        final configData = json.decode(response.body);
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
    print('🔍 Starting NFC verification for ID: $workCenterId');
    try {
      final serverUrl = await getCurrentServerUrl();
      if (serverUrl == null) {
        print('❌ No server URL configured');
        throw const ConfigException('No hay servidor configurado');
      }

      final verifyUrl = '$serverUrl/api/v1/nfc/verify';
      print('🌐 Verifying with URL: $verifyUrl');
      final response = await http.post(
        Uri.parse(verifyUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({'nfc_id': workCenterId}),
      );

      print('📡 HTTP Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Validar que la respuesta tenga contenido
        if (response.body.trim().isEmpty) {
          throw const APIException('Respuesta vacía del servidor');
        }

        print('📡 NFC Verify Response: ${response.body}');

        dynamic decodedData;
        try {
          decodedData = json.decode(response.body);
        } catch (e) {
          print('❌ Error parsing JSON response: $e');
          throw APIException('Respuesta JSON inválida del servidor: $e');
        }

        // Validar que la respuesta sea un Map
        if (decodedData == null || decodedData is! Map<String, dynamic>) {
          print('❌ Invalid response format: $decodedData');
          throw const APIException('Formato de respuesta inválido del servidor');
        }

        final data = decodedData;

        // Validar estructura de la respuesta
        if (!data.containsKey('success')) {
          print('❌ Missing "success" field in response');
          throw const APIException('Respuesta del servidor incompleta');
        }

        if (data['success'] == true) {
          print('✅ Server response success: true');
          if (data.containsKey('work_center')) {
            print('✅ work_center key exists in response');
            final workCenterData = data['work_center'];
            print('📋 work_center data: $workCenterData');
            if (workCenterData != null && workCenterData is Map<String, dynamic>) {
              print('✅ work_center data is valid Map, creating WorkCenter object');
              try {
                final workCenter = WorkCenter.fromJson(workCenterData);
                print('✅ WorkCenter created successfully: $workCenter');
                return workCenter;
              } catch (e) {
                print('❌ Error creating WorkCenter from JSON: $e');
                throw APIException('Error procesando datos del centro de trabajo: $e');
              }
            } else {
              print('❌ work_center data is null or not a Map: $workCenterData');
              throw const NFCVerificationException('Datos del centro de trabajo inválidos');
            }
          } else {
            print('❌ work_center key not found in response');
            throw const NFCVerificationException('Centro de trabajo no encontrado en la respuesta');
          }
        } else {
          final message = data['message'] as String? ?? 'Error desconocido en verificación NFC';
          print('❌ Server response success: false, message: $message');
          throw NFCVerificationException(message);
        }
      } else {
        // Manejar errores HTTP
        print('❌ HTTP Error - Status: ${response.statusCode}');
        print('📡 Error Response Body: ${response.body}');
        String errorMessage = 'Error del servidor (${response.statusCode})';
        try {
          if (response.body.isNotEmpty) {
            final errorData = json.decode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage = errorData['message'] as String;
            }
          }
        } catch (e) {
          print('❌ Error parsing error response: $e');
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
      print('Error cargando configuración guardada: $e');
      return false;
    }
  }

  /// Obtiene la URL del servidor actual
  static Future<String?> getCurrentServerUrl() async {
    try {
      return await StorageService.getConfig<String>(_serverUrlKey);
    } catch (e) {
      print('Error obteniendo URL del servidor: $e');
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
      print('Error obteniendo configuración del servidor: $e');
      return null;
    }
  }

  /// Limpia la configuración del servidor
  static Future<void> clearServerConfiguration() async {
    try {
      final prefs = await StorageService.preferences;
      await prefs.remove(_serverUrlKey);
      await prefs.remove(_serverConfigKey);

      print('Configuración del servidor limpiada');
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
