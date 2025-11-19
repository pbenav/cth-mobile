class ClockStatus {
  final String
      action; // 'clock_in', 'working_options', 'resume_workday', 'confirm_exceptional_clock_in', 'clock_out'
  final bool canClock;
  final String? message;
  final bool? overtime;
  final int? eventTypeId;
  final NextSlot? nextSlot;
  final TodayStats todayStats;
  final DateTime currentTime;
  final String? workCenterCode;
  final String? workCenterName; // Nombre del centro de trabajo
  final int? pauseEventId; // Nuevo campo para reanudar desde pausa
  final List<ClockEvent> todayRecords; // Nuevo campo para eventos del día

  const ClockStatus({
    required this.action,
    required this.canClock,
    this.message,
    this.overtime,
    this.eventTypeId,
    this.nextSlot,
    required this.todayStats,
    required this.currentTime,
    this.workCenterCode,
    this.workCenterName,
    this.pauseEventId,
    this.todayRecords = const [],
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'can_clock': canClock,
        'message': message,
        'overtime': overtime,
        'event_type_id': eventTypeId,
        'next_slot': nextSlot?.toJson(),
        'today_stats': todayStats.toJson(),
        'current_time': currentTime.toIso8601String(),
        'work_center_code': workCenterCode,
        'work_center_name': workCenterName,
        'pause_event_id': pauseEventId,
        'today_records': todayRecords.map((e) => e.toJson()).toList(),
      };

  static ClockStatus fromJson(Map<String, dynamic> json) {
    final action = json['action'] is String ? json['action'] as String : '';
    final pauseEventIdRaw = json['pause_event_id'];
    final pauseEventId = (pauseEventIdRaw == null)
        ? null
        : (pauseEventIdRaw is int
            ? pauseEventIdRaw
            : (pauseEventIdRaw is String
                ? int.tryParse(pauseEventIdRaw)
                : null));
    final todayRecordsRaw = json['today_records'];
    final List<ClockEvent> todayRecords = (todayRecordsRaw is List)
        ? todayRecordsRaw
            .map((e) => ClockEvent.fromJson(e as Map<String, dynamic>))
            .toList()
        : [];
    return ClockStatus(
      action: action,
      canClock: json['can_clock'] is bool ? json['can_clock'] as bool : false,
      message: json['message'] is String ? json['message'] as String : null,
      overtime: json['overtime'] as bool?,
      eventTypeId: json['event_type_id'] is int
          ? json['event_type_id'] as int
          : (json['event_type_id'] is String
              ? int.tryParse(json['event_type_id'])
              : null),
      nextSlot: null,
      todayStats: json['today_stats'] is Map<String, dynamic>
          ? TodayStats.fromJson(json['today_stats'])
          : TodayStats(totalEntries: 0, totalExits: 0),
      currentTime: DateTime.now(),
      workCenterCode: json['work_center_code'] is String
          ? json['work_center_code'] as String
          : null,
      workCenterName: json['work_center_name'] is String
          ? json['work_center_name'] as String
          : null,
      pauseEventId: pauseEventId,
      todayRecords: todayRecords,
    );
  }
}

// Modelo para los eventos del día
class ClockEvent {
  final int id;
  final int? eventTypeId;
  final String type;
  final String status;
  final DateTime timestamp;
  final int? pauseEventId;
  final bool? isOpen;

  ClockEvent({
    required this.id,
    this.eventTypeId,
    required this.type,
    required this.status,
    required this.timestamp,
    this.pauseEventId,
    this.isOpen,
  });

  factory ClockEvent.fromJson(Map<String, dynamic> json) {
    return ClockEvent(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      eventTypeId: json['event_type_id'] is int
          ? json['event_type_id']
          : int.tryParse(json['event_type_id']?.toString() ?? ''),
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      pauseEventId: json['pause_event_id'] is int
          ? json['pause_event_id']
          : int.tryParse(json['pause_event_id']?.toString() ?? ''),
      isOpen: json['is_open'] == true || json['is_open']?.toString() == 'true',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_type_id': eventTypeId,
        'type': type,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
        'pause_event_id': pauseEventId,
        'is_open': isOpen,
      };
}

class NextSlot {
  final String start;
  final String end;
  final int? minutesUntil;

  const NextSlot({
    required this.start,
    required this.end,
    this.minutesUntil,
  });

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'minutes_until': minutesUntil,
      };

  factory NextSlot.fromJson(Map<String, dynamic> json) {
    final start = json['start'] is String ? json['start'] : '';
    final end = json['end'] is String ? json['end'] : '';
    final minutesUntil =
        json['minutes_until'] is int ? json['minutes_until'] : null;
    return NextSlot(start: start, end: end, minutesUntil: minutesUntil);
  }
}

class TodayStats {
  final int totalEntries;
  final int totalExits;
  final String? workedHours;
  final String? currentStatus;

  const TodayStats({
    required this.totalEntries,
    required this.totalExits,
    this.workedHours,
    this.currentStatus,
  });

  Map<String, dynamic> toJson() => {
        'total_entries': totalEntries,
        'total_exits': totalExits,
        'worked_hours': workedHours,
        'current_status': currentStatus,
      };

  static TodayStats fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    String? parseString(dynamic v) {
      if (v == null) return null;
      if (v is String) return v;
      return v.toString();
    }

    final totalEntries = parseInt(json['total_entries']);
    final totalExits = parseInt(json['total_exits']);
    final workedHours = parseString(json['worked_hours']);
    final currentStatus = parseString(json['current_status']);
    return TodayStats(
      totalEntries: totalEntries,
      totalExits: totalExits,
      workedHours: workedHours,
      currentStatus: currentStatus,
    );
  }
}

class ClockAction {
  final String action;
  final DateTime timestamp;
  final String? workCenterCode;

  const ClockAction({
    required this.action,
    required this.timestamp,
    this.workCenterCode,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'timestamp': timestamp.toIso8601String(),
        'work_center_code': workCenterCode,
      };

  factory ClockAction.fromJson(Map<String, dynamic> json) => ClockAction(
        action: json['action'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        workCenterCode: json['work_center_code'] as String?,
      );
}
