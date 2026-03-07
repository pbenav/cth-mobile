import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/work_center.dart';
import '../utils/exceptions.dart';

class NFCService {
  static Future<WorkCenter?> scanWorkCenter(
      {Function(String, Map<String, dynamic>?)? onNFCDebug}) async {
    throw const NFCNotAvailableException('NFC no está disponible en entorno web');
  }

  static Future<bool> isNFCAvailable() async {
    return false;
  }

  static Future<bool> writeWorkCenterTag({
    required String code,
    required String name,
  }) async {
    throw const NFCNotAvailableException('NFC no está disponible en entorno web');
  }

  static Future<bool> writeAutoConfigTag({
    required String serverUrl,
    required String workerCode,
  }) async {
    throw const NFCNotAvailableException('NFC no está disponible en entorno web');
  }
}
