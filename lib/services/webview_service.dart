import 'package:flutter/material.dart';
import '../models/work_center.dart';
import '../models/user.dart';
import '../screens/webview_screen.dart';
import '../utils/constants.dart';

class WebViewService {
  // Abrir WebView con autenticación automática
  static Future<void> openAuthenticatedWebView({
    required BuildContext context,
    required WorkCenter workCenter,
    required User user,
    required String path, // '/history', '/schedule', '/reports', etc.
  }) async {
    final url = Uri.parse('${AppConstants.webBaseUrl}$path').replace(
      queryParameters: {
        'work_center_code': workCenter.code,
        'work_center_name': workCenter.name,
        'user_code': user.code,
        'user_name': user.name,
        'auto_auth': 'true',
        'mobile': 'true',
      },
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CTHWebView(
          url: url.toString(),
          title: _getPageTitle(path),
          workCenter: workCenter,
          user: user,
        ),
      ),
    );
  }

  // Generar URL autenticada sin navegar
  static String generateAuthUrl({
    required WorkCenter workCenter,
    required User user,
    required String path,
  }) {
    return Uri.parse('${AppConstants.webBaseUrl}$path').replace(
      queryParameters: {
        'work_center_code': workCenter.code,
        'work_center_name': workCenter.name,
        'user_code': user.code,
        'user_name': user.name,
        'auto_auth': 'true',
        'mobile': 'true',
      },
    ).toString();
  }

  // Obtener título de página
  static String _getPageTitle(String path) {
    switch (path) {
      case AppConstants.webViewHome:
        return 'Inicio';
      case AppConstants.webViewHistory:
        return 'Historial';
      case AppConstants.webViewSchedule:
        return 'Horarios';
      case AppConstants.webViewProfile:
        return 'Perfil';
      case AppConstants.webViewReports:
        return 'Informes';
      default:
        return 'CTH Mobile';
    }
  }

  // Validar si una URL es de CTH
  static bool isValidCTHUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final baseUri = Uri.parse(AppConstants.webBaseUrl);
      return uri.host == baseUri.host && uri.path.startsWith('/mobile');
    } catch (e) {
      return false;
    }
  }

  // Extraer datos de autenticación de una URL
  static Map<String, String>? extractAuthDataFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final params = uri.queryParameters;

      if (params.containsKey('work_center_code') &&
          params.containsKey('user_code')) {
        return {
          'work_center_code': params['work_center_code']!,
          'work_center_name': params['work_center_name'] ?? '',
          'user_code': params['user_code']!,
          'user_name': params['user_name'] ?? '',
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
