import 'package:ndef_record/ndef_record.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import '../models/work_center.dart';
import '../utils/exceptions.dart';
import 'config_service.dart';

enum NFCPayloadType { simple, autoConfig }

class NFCPayload {
  final NFCPayloadType type;
  final String content;
  final Map<String, dynamic>? data;

  NFCPayload({
    required this.type,
    required this.content,
    this.data,
  });
}

class NFCService {
  /// Escanea una etiqueta NFC y detecta automáticamente el tipo de payload
  static Future<WorkCenter?> scanWorkCenter({Function(String, Map<String, dynamic>?)? onNFCDebug}) async {
    if (!await NfcManager.instance.isAvailable()) {
      throw const NFCNotAvailableException('NFC no está disponible en este dispositivo');
    }

    Completer<WorkCenter?> completer = Completer();

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso18092, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            final payload = await _readNFCPayload(tag, onDebug: onNFCDebug);
            if (payload != null) {
              WorkCenter? workCenter;
              switch (payload.type) {
                case NFCPayloadType.autoConfig:
                  workCenter = await _handleAutoConfigPayload(payload);
                  break;
                case NFCPayloadType.simple:
                  workCenter = await _handleSimplePayload(payload);
                  break;
              }
              if (!completer.isCompleted) {
                completer.complete(workCenter);
              }
            } else {
              if (!completer.isCompleted) {
                completer.complete(null);
              }
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(NFCReadException('Error leyendo etiqueta NFC: $e'));
            }
          } finally {
            await NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(const NFCException('Error iniciando sesión NFC'));
      }
    }
    return completer.future;
  }

  /// Lee el payload de una etiqueta NFC y determina su tipo
  static Future<NFCPayload?> _readNFCPayload(NfcTag tag, {Function(String, Map<String, dynamic>?)? onDebug}) async {
    final ndef = Ndef.from(tag);
    if (ndef != null && ndef.cachedMessage != null && ndef.cachedMessage!.records.isNotEmpty) {
      final record = ndef.cachedMessage!.records.first;
      final payload = record.payload;
      final text = utf8.decode(payload.skip(3).toList());

      print('🔍 NFC Content Read: "$text"');
      print('📏 Content Length: ${text.length} characters');

      // Notificar al callback de debug si existe
      onDebug?.call(text, null);

      if (text.trim().startsWith('{') && text.trim().endsWith('}')) {
        try {
          final data = json.decode(text);
          print('📋 Parsed JSON Data: $data');

          // Verificar que tenga los campos requeridos
          final hasUrl = data.containsKey('url') || data.containsKey('server_url');
          final hasId = data.containsKey('id') || data.containsKey('nfc_tag_id');

          print('✅ JSON valid - Has URL: $hasUrl, Has ID: $hasId');

          // Notificar datos parseados
          onDebug?.call(text, data);

          return NFCPayload(
            type: NFCPayloadType.autoConfig,
            content: text,
            data: data,
          );
        } catch (e) {
          print('❌ Error parsing JSON: $e');
        }
      }
      if (text.startsWith('CTH:')) {
        print('🏷️ Detected simple CTH format');
        return NFCPayload(
          type: NFCPayloadType.simple,
          content: text,
        );
      }
    }

    print('❓ No valid NFC payload found');
    // Intentar leer ID del tag como fallback
    // Si necesitas soporte para otras tecnologías, consulta la documentación oficial
    return null;
  }

  /// Maneja payloads de auto-configuración
  static Future<WorkCenter?> _handleAutoConfigPayload(
      NFCPayload payload) async {
    if (payload.data == null) {
      print('❌ Auto-config payload has no data');
      return null;
    }

    print('🔧 Processing auto-config payload');
    print('📦 Payload data keys: ${payload.data!.keys.toList()}');

    try {
      final url = payload.data!['url'] as String?;
      final workCenterId = payload.data!['id'] as String?;

      print('🌐 Extracted URL: $url');
      print('🆔 Extracted WorkCenter ID: $workCenterId');

      if (url == null || workCenterId == null) {
        print('❌ Missing required fields in payload');
        throw const NFCVerificationException('Payload JSON incompleto');
      }

      // Configurar servidor automáticamente
      print('⚙️ Starting server configuration...');
      final configResult = await ConfigService.configureServer(url);

      if (!configResult) {
        print('❌ Server configuration failed');
        throw const ConfigException(
            'No se pudo configurar el servidor automáticamente');
      }

      print('✅ Server configured successfully');

      // Verificar la etiqueta NFC con el servidor
      print('🔍 Verifying NFC tag with server...');
      final workCenter = await ConfigService.verifyNFCTag(workCenterId);

      if (workCenter == null) {
        print('❌ Work center not found on server');
        throw const NFCVerificationException(
            'Centro de trabajo no encontrado en el servidor');
      }

      print('✅ Work center verified: ${workCenter.name}');
      return workCenter;
    } catch (e) {
      print('💥 Error in auto-config: $e');
      rethrow;
    }
  }

  /// Maneja payloads simples (formato legacy)
  static Future<WorkCenter?> _handleSimplePayload(NFCPayload payload) async {
    final content = payload.content;

    // Formato esperado: "CTH:OC-001:Oficina Central"
    if (content.startsWith('CTH:')) {
      final parts = content.split(':');
      if (parts.length >= 2) {
        return WorkCenter(
          code: parts[1],
          name: parts.length > 2 ? parts[2] : parts[1],
        );
      }
    }

    // Para IDs de hardware, podrías implementar lógica de mapeo
    print('Payload simple no reconocido: $content');
    return null;
  }

  /// Verifica si NFC está disponible
  static Future<bool> isNFCAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  /// Detiene la sesión NFC activa
  static Future<void> stopNFCSession() async {
    await NfcManager.instance.stopSession();
  }

  /// Escribe una etiqueta NFC con formato simple (legacy)
  static Future<bool> writeWorkCenterTag({
    required String code,
    required String name,
  }) async {
    if (!await NfcManager.instance.isAvailable()) {
      throw const NFCNotAvailableException(
          'NFC no está disponible en este dispositivo');
    }

    final content = 'CTH:$code:$name';
    return await _writeNFCContent(content);
  }

  /// Escribe una etiqueta NFC con payload JSON (auto-configuración)
  static Future<bool> writeAutoConfigTag({
    required String jsonPayload,
  }) async {
    if (!await NfcManager.instance.isAvailable()) {
      throw const NFCNotAvailableException(
          'NFC no está disponible en este dispositivo');
    }

    // Validar que sea JSON válido
    try {
      json.decode(jsonPayload);
    } catch (e) {
      throw NFCWriteException('Payload JSON inválido: $e');
    }

    return await _writeNFCContent(jsonPayload);
  }

  /// Método interno para escribir contenido a etiquetas NFC
  static Future<bool> _writeNFCContent(String content) async {
    final completer = Completer<bool>();

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso18092, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              completer.complete(false);
              return;
            }
            // Crear registro NFC tipo texto manualmente (formato NFC Forum Well Known Type)
            // Crear registro NFC tipo texto usando NdefRecord y NdefMessage de nfc_manager_ndef
            final languageCode = 'en';
            final textBytes = utf8.encode(content);
            final langBytes = utf8.encode(languageCode);
            final payload = Uint8List.fromList([langBytes.length] + langBytes + textBytes);
            final record = NdefRecord(
              typeNameFormat: TypeNameFormat.wellKnown,
              type: Uint8List.fromList(utf8.encode('T')),
              identifier: Uint8List(0),
              payload: payload,
            );
            final message = NdefMessage(records: [record]);
            await ndef.write(message: message);
            completer.complete(true);
          } catch (e) {
            completer.completeError(NFCWriteException('Error escribiendo etiqueta: $e'));
          } finally {
            await NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      completer.completeError(const NFCException('Error iniciando sesión de escritura'));
    }
    return completer.future;
  }

  /// Obtiene información del servidor configurado
  static Future<String?> getCurrentServerUrl() async {
    return await ConfigService.getCurrentServerUrl();
  }

  /// Carga configuración guardada si existe
  static Future<bool> loadSavedConfiguration() async {
    return await ConfigService.loadSavedConfiguration();
  }
}
