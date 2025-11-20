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

class SyncResponse {
  final int totalEvents;
  final int successfulSyncs;
  final int failedSyncs;
  final List<dynamic> syncResults;
  final DateTime syncTimestamp;

  const SyncResponse({
    required this.totalEvents,
    required this.successfulSyncs,
    required this.failedSyncs,
    required this.syncResults,
    required this.syncTimestamp,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) => SyncResponse(
        totalEvents: json['total_events'] as int? ?? 0,
        successfulSyncs: json['successful_syncs'] as int? ?? 0,
        failedSyncs: json['failed_syncs'] as int? ?? 0,
        syncResults: json['sync_results'] is List ? json['sync_results'] : [],
        syncTimestamp: DateTime.parse(json['sync_timestamp'] as String),
      );

  Map<String, dynamic> toJson() => {
        'total_events': totalEvents,
        'successful_syncs': successfulSyncs,
        'failed_syncs': failedSyncs,
        'sync_results': syncResults,
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
