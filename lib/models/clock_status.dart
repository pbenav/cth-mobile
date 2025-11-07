class ClockStatus {
  final String nextAction; // 'entrada' | 'salida'
  final bool canClock;
  final TodayStats todayStats;
  final DateTime currentTime;

  const ClockStatus({
    required this.nextAction,
    required this.canClock,
    required this.todayStats,
    required this.currentTime,
  });

  Map<String, dynamic> toJson() => {
        'next_action': nextAction,
        'can_clock': canClock,
        'today_stats': todayStats.toJson(),
        'current_time': currentTime.toIso8601String(),
      };

  factory ClockStatus.fromJson(Map<String, dynamic> json) => ClockStatus(
        nextAction: json['next_action'] as String,
        canClock: json['can_clock'] as bool,
        todayStats:
            TodayStats.fromJson(json['today_stats'] as Map<String, dynamic>),
        currentTime: DateTime.parse(json['current_time'] as String),
      );
}

class TodayStats {
  final int entriesCount;
  final int exitsCount;
  final String workedHours;
  final String currentStatus;
  final ClockAction? lastAction;

  const TodayStats({
    required this.entriesCount,
    required this.exitsCount,
    required this.workedHours,
    required this.currentStatus,
    this.lastAction,
  });

  Map<String, dynamic> toJson() => {
        'entries_count': entriesCount,
        'exits_count': exitsCount,
        'worked_hours': workedHours,
        'current_status': currentStatus,
        'last_action': lastAction?.toJson(),
      };

  factory TodayStats.fromJson(Map<String, dynamic> json) => TodayStats(
        entriesCount: json['entries_count'] as int,
        exitsCount: json['exits_count'] as int,
        workedHours: json['worked_hours'] as String,
        currentStatus: json['current_status'] as String,
        lastAction: json['last_action'] != null
            ? ClockAction.fromJson(json['last_action'] as Map<String, dynamic>)
            : null,
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
