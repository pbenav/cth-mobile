class ClockStatus {
  final String action; // 'clock_in', 'working_options', 'resume_workday', 'confirm_exceptional_clock_in', 'clock_out'
  final bool canClock;
  final String? message;
  final bool? overtime;
  final int? eventTypeId;
  final NextSlot? nextSlot;
  final TodayStats todayStats;
  final DateTime currentTime;

  const ClockStatus({
    required this.action,
    required this.canClock,
    this.message,
    this.overtime,
    this.eventTypeId,
    this.nextSlot,
    required this.todayStats,
    required this.currentTime,
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
      };

  factory ClockStatus.fromJson(Map<String, dynamic> json) => ClockStatus(
        action: json['action'] as String,
        canClock: json['can_clock'] as bool,
        message: json['message'] as String?,
        overtime: json['overtime'] as bool?,
        eventTypeId: json['event_type_id'] as int?,
        nextSlot: json['next_slot'] != null
            ? NextSlot.fromJson(json['next_slot'] as Map<String, dynamic>)
            : null,
        todayStats:
            TodayStats.fromJson(json['today_stats'] as Map<String, dynamic>),
        currentTime: DateTime.parse(json['current_time'] as String),
      );
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

  factory NextSlot.fromJson(Map<String, dynamic> json) => NextSlot(
        start: json['start'] as String,
        end: json['end'] as String,
        minutesUntil: json['minutes_until'] as int?,
      );
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

  factory TodayStats.fromJson(Map<String, dynamic> json) => TodayStats(
        totalEntries: json['total_entries'] as int? ?? 0,
        totalExits: json['total_exits'] as int? ?? 0,
        workedHours: json['worked_hours'] as String?,
        currentStatus: json['current_status'] as String?,
      );
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
