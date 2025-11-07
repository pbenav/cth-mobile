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
  static Future<WorkCenter?> scanWorkCenter() async {
    if (!await NfcManager.instance.isAvailable()) {
      throw const NFCNotAvailableException('NFC no está disponible en este dispositivo');
    }

    Completer<WorkCenter?> completer = Completer();

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso18092, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            final payload = await _readNFCPayload(tag);
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
  static Future<NFCPayload?> _readNFCPayload(NfcTag tag) async {
    final ndef = Ndef.from(tag);
    if (ndef != null && ndef.cachedMessage != null && ndef.cachedMessage!.records.isNotEmpty) {
      final record = ndef.cachedMessage!.records.first;
      final payload = record.payload;
      final text = utf8.decode(payload.skip(3).toList());
      if (text.trim().startsWith('{') && text.trim().endsWith('}')) {
        try {
          final data = json.decode(text);
          return NFCPayload(
            type: NFCPayloadType.autoConfig,
            content: text,
            data: data,
          );
        } catch (e) {
          print('Error parseando JSON: $e');
        }
      }
      if (text.startsWith('CTH:')) {
        return NFCPayload(
          type: NFCPayloadType.simple,
          content: text,
        );
      }
    }
    // Intentar leer ID del tag como fallback
    // Si necesitas soporte para otras tecnologías, consulta la documentación oficial
    return null;
  }

  /// Maneja payloads de auto-configuración
  static Future<WorkCenter?> _handleAutoConfigPayload(
      NFCPayload payload) async {
    if (payload.data == null) return null;

    try {
      final url = payload.data!['url'] as String?;
      final workCenterId = payload.data!['id'] as String?;

      if (url == null || workCenterId == null) {
        throw const NFCVerificationException('Payload JSON incompleto');
      }

      // Configurar servidor automáticamente
      final configResult = await ConfigService.configureServer(url);

      if (!configResult) {
        throw const ConfigException(
            'No se pudo configurar el servidor automáticamente');
      }

      // Verificar la etiqueta NFC con el servidor
      final workCenter = await ConfigService.verifyNFCTag(workCenterId);

      if (workCenter == null) {
        throw const NFCVerificationException(
            'Centro de trabajo no encontrado en el servidor');
      }

      return workCenter;
    } catch (e) {
      print('Error en auto-configuración: $e');
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
