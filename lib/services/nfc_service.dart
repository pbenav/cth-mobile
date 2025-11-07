import 'dart:async';
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
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
      throw const NFCNotAvailableException(
          'NFC no está disponible en este dispositivo');
    }

    Completer<WorkCenter?> completer = Completer();

    try {
      await NfcManager.instance.startSession(
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
              completer.completeError(
                  NFCReadException('Error leyendo etiqueta NFC: $e'));
            }
          } finally {
            await NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer
            .completeError(const NFCException('Error iniciando sesión NFC'));
      }
    }

    return completer.future;
  }

  /// Lee el payload de una etiqueta NFC y determina su tipo
  static Future<NFCPayload?> _readNFCPayload(NfcTag tag) async {
    final ndef = Ndef.from(tag);

    if (ndef?.cachedMessage?.records.isNotEmpty == true) {
      final record = ndef!.cachedMessage!.records.first;
      final text = utf8.decode(record.payload.skip(3).toList());

      // Verificar si es un payload JSON (auto-configuración)
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

      // Verificar si es formato simple CTH:
      if (text.startsWith('CTH:')) {
        return NFCPayload(
          type: NFCPayloadType.simple,
          content: text,
        );
      }
    }

    // Intentar leer ID del tag como fallback
    final id = tag.data['nfca']?['identifier'] ??
        tag.data['nfcb']?['identifier'] ??
        tag.data['nfcf']?['identifier'] ??
        tag.data['nfcv']?['identifier'];

    if (id != null) {
      final idHex =
          id.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
      print('Tag ID detectado: $idHex');

      return NFCPayload(
        type: NFCPayloadType.simple,
        content: idHex,
      );
    }

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
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              completer.complete(false);
              return;
            }

            final message = NdefMessage([
              NdefRecord.createText(content),
            ]);

            await ndef.write(message);
            completer.complete(true);
          } catch (e) {
            completer.completeError(
                NFCWriteException('Error escribiendo etiqueta: $e'));
          } finally {
            await NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      completer.completeError(
          const NFCException('Error iniciando sesión de escritura'));
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
