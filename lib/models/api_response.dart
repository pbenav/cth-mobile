class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final List<String>? errors;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool,
      message: json['message'] is String ? json['message'] as String : '',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'] as Map<String, dynamic>)
          : json['data'] as T?,
      errors: json['errors'] != null
          ? List<String>.from(json['errors'] as List)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'message': message,
        'data': data,
        'errors': errors,
      };
}

class ClockResponse {
  final String action;
  final DateTime timestamp;
  final String workCenterCode;
  final String userCode;
  final String message;

  const ClockResponse({
    required this.action,
    required this.timestamp,
    required this.workCenterCode,
    required this.userCode,
    required this.message,
  });

  factory ClockResponse.fromJson(Map<String, dynamic> json) => ClockResponse(
        action: json['action'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        workCenterCode: json['work_center_code'] as String,
        userCode: json['user_code'] as String,
        message: json['message'] as String,
      );

  Map<String, dynamic> toJson() => {
        'action': action,
        'timestamp': timestamp.toIso8601String(),
        'work_center_code': workCenterCode,
        'user_code': userCode,
        'message': message,
      };
}

class SyncResponse {
  final int processedEvents;
  final int failedEvents;
  final List<String> errors;
  final DateTime syncTimestamp;

  const SyncResponse({
    required this.processedEvents,
    required this.failedEvents,
    required this.errors,
    required this.syncTimestamp,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) => SyncResponse(
        processedEvents: json['processed_events'] as int,
        failedEvents: json['failed_events'] as int,
        errors: List<String>.from(json['errors'] as List),
        syncTimestamp: DateTime.parse(json['sync_timestamp'] as String),
      );

  Map<String, dynamic> toJson() => {
        'processed_events': processedEvents,
        'failed_events': failedEvents,
        'errors': errors,
        'sync_timestamp': syncTimestamp.toIso8601String(),
      };
}

class OfflineClockEvent {
  final String action;
  final DateTime timestamp;
  final String workCenterCode;
  final String userCode;
  final bool synced;

  const OfflineClockEvent({
    required this.action,
    required this.timestamp,
    required this.workCenterCode,
    required this.userCode,
    this.synced = false,
  });

  factory OfflineClockEvent.fromJson(Map<String, dynamic> json) =>
      OfflineClockEvent(
        action: json['action'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        workCenterCode: json['work_center_code'] as String,
        userCode: json['user_code'] as String,
        synced: json['synced'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'action': action,
        'timestamp': timestamp.toIso8601String(),
        'work_center_code': workCenterCode,
        'user_code': userCode,
        'synced': synced,
      };
}
