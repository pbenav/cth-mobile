class AppConstants {
  // URLs de API (configurables via dart-define)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cth.sientia.com',
  );

  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://cth.sientia.com/mobile',
  );

  // Configuración de la app
  static const String appName = 'CTH Mobile';
  static const String appVersion = '0.0.1';
  static const String buildDate = '2025-11-08 22:50:53'; // Fecha de compilación
  static const bool isProduction = bool.fromEnvironment('PRODUCTION');

  // Configuración NFC
  static const String nfcTagPrefix = 'CTH:';
  static const Duration nfcSessionTimeout = Duration(seconds: 30);

  // Configuración de red
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration statusTimeout = Duration(seconds: 15);
  static const Duration connectivityTimeout = Duration(seconds: 5);

  // Configuración de almacenamiento local
  static const String keyWorkCenter = 'work_center';
  static const String keyUser = 'user';
  static const String keyOfflineEvents = 'offline_events';
  static const String keyLastSync = 'last_sync';
  static const String keyWorkerLastUpdate = 'worker_last_update';

  // Configuración UI
  static const double cardBorderRadius = 16.0;
  static const double buttonHeight = 56.0;
  static const double spacing = 16.0;

  // Colores
  static const int primaryColorValue = 0xFF1976D2;
  static const int successColorValue = 0xFF4CAF50;
  static const int errorColorValue = 0xFFD32F2F;
  static const int warningColorValue = 0xFFFF9800;

  // Mensajes
  static const String nfcNotAvailable =
      'NFC no está disponible en este dispositivo';
  static const String nfcScanPrompt =
      'Acerca la etiqueta NFC del centro de trabajo';
  static const String connectionError =
      'Error de conexión. Verifica tu internet.';
  static const String serverError = 'Error del servidor. Inténtalo más tarde.';

  // Rutas de navegación
  static const String routeStart = '/';
  static const String routeLogin = '/login';
  static const String routeClock = '/clock';
  static const String routeWebView = '/webview';
  static const String routeManualEntry = '/manual';
  static const String routeProfile = '/profile';
  static const String routeSettings = '/settings';

  // WebView páginas
  static const String webViewHome = '/home';
  static const String webViewHistory = '/history';
  static const String webViewSchedule = '/schedule';
  static const String webViewProfile = '/profile';
  static const String webViewReports = '/reports';
}
