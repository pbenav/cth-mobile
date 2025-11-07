class ServerConfig {
  final ServerInfo serverInfo;
  final Endpoints endpoints;
  final Features features;
  final Limits limits;
  final UIConfig uiConfig;

  ServerConfig({
    required this.serverInfo,
    required this.endpoints,
    required this.features,
    required this.limits,
    required this.uiConfig,
  });

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      serverInfo: ServerInfo.fromJson(json['server_info']),
      endpoints: Endpoints.fromJson(json['endpoints']),
      features: Features.fromJson(json['features']),
      limits: Limits.fromJson(json['limits']),
      uiConfig: UIConfig.fromJson(json['ui_config']),
    );
  }
}

class ServerInfo {
  final String name;
  final String version;
  final String apiVersion;
  final String timezone;
  final String locale;

  ServerInfo({
    required this.name,
    required this.version,
    required this.apiVersion,
    required this.timezone,
    required this.locale,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      name: json['name'] ?? 'CTH Server',
      version: json['version'] ?? '1.0.0',
      apiVersion: json['api_version'] ?? 'v1',
      timezone: json['timezone'] ?? 'UTC',
      locale: json['locale'] ?? 'es',
    );
  }
}

class Endpoints {
  final String baseUrl;
  final String apiBase;
  final AuthEndpoints auth;
  final ClockEndpoints clock;
  final NFCEndpoints nfc;

  Endpoints({
    required this.baseUrl,
    required this.apiBase,
    required this.auth,
    required this.clock,
    required this.nfc,
  });

  factory Endpoints.fromJson(Map<String, dynamic> json) {
    return Endpoints(
      baseUrl: json['base_url'] ?? '',
      apiBase: json['api_base'] ?? '',
      auth: AuthEndpoints.fromJson(json['auth'] ?? {}),
      clock: ClockEndpoints.fromJson(json['clock'] ?? {}),
      nfc: NFCEndpoints.fromJson(json['nfc'] ?? {}),
    );
  }
}

class AuthEndpoints {
  final String mobileLogin;
  final String mobileVerify;
  final String mobileLogout;

  AuthEndpoints({
    required this.mobileLogin,
    required this.mobileVerify,
    required this.mobileLogout,
  });

  factory AuthEndpoints.fromJson(Map<String, dynamic> json) {
    return AuthEndpoints(
      mobileLogin: json['mobile_login'] ?? '',
      mobileVerify: json['mobile_verify'] ?? '',
      mobileLogout: json['mobile_logout'] ?? '',
    );
  }
}

class ClockEndpoints {
  final String clockIn;
  final String clockOut;
  final String history;
  final String today;

  ClockEndpoints({
    required this.clockIn,
    required this.clockOut,
    required this.history,
    required this.today,
  });

  factory ClockEndpoints.fromJson(Map<String, dynamic> json) {
    return ClockEndpoints(
      clockIn: json['clock_in'] ?? '',
      clockOut: json['clock_out'] ?? '',
      history: json['history'] ?? '',
      today: json['today'] ?? '',
    );
  }
}

class NFCEndpoints {
  final String verifyTag;
  final String workCenters;

  NFCEndpoints({
    required this.verifyTag,
    required this.workCenters,
  });

  factory NFCEndpoints.fromJson(Map<String, dynamic> json) {
    return NFCEndpoints(
      verifyTag: json['verify_tag'] ?? '',
      workCenters: json['work_centers'] ?? '',
    );
  }
}

class Features {
  final bool nfcVerification;
  final bool geolocationRequired;
  final bool multipleWorkCenters;
  final bool breakManagement;
  final bool offlineSync;

  Features({
    required this.nfcVerification,
    required this.geolocationRequired,
    required this.multipleWorkCenters,
    required this.breakManagement,
    required this.offlineSync,
  });

  factory Features.fromJson(Map<String, dynamic> json) {
    return Features(
      nfcVerification: json['nfc_verification'] ?? false,
      geolocationRequired: json['geolocation_required'] ?? false,
      multipleWorkCenters: json['multiple_work_centers'] ?? false,
      breakManagement: json['break_management'] ?? false,
      offlineSync: json['offline_sync'] ?? false,
    );
  }
}

class Limits {
  final int maxClockDistanceMeters;
  final int sessionTimeoutMinutes;
  final int maxDailyBreaks;

  Limits({
    required this.maxClockDistanceMeters,
    required this.sessionTimeoutMinutes,
    required this.maxDailyBreaks,
  });

  factory Limits.fromJson(Map<String, dynamic> json) {
    return Limits(
      maxClockDistanceMeters: json['max_clock_distance_meters'] ?? 100,
      sessionTimeoutMinutes: json['session_timeout_minutes'] ?? 480,
      maxDailyBreaks: json['max_daily_breaks'] ?? 3,
    );
  }
}

class UIConfig {
  final String primaryColor;
  final String accentColor;
  final String errorColor;
  final String warningColor;
  final String companyLogoUrl;
  final bool showDebugInfo;

  UIConfig({
    required this.primaryColor,
    required this.accentColor,
    required this.errorColor,
    required this.warningColor,
    required this.companyLogoUrl,
    required this.showDebugInfo,
  });

  factory UIConfig.fromJson(Map<String, dynamic> json) {
    return UIConfig(
      primaryColor: json['primary_color'] ?? '#1976D2',
      accentColor: json['accent_color'] ?? '#10B981',
      errorColor: json['error_color'] ?? '#EF4444',
      warningColor: json['warning_color'] ?? '#F59E0B',
      companyLogoUrl: json['company_logo_url'] ?? '',
      showDebugInfo: json['show_debug_info'] ?? false,
    );
  }
}
