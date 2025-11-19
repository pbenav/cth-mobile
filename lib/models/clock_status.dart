import 'dart:convert';

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
      };

  static ClockStatus fromJson(Map<String, dynamic> json) {
    try {
      print('[ClockStatus][DEBUG] JSON recibido: ' + json.toString());
      final action = (() {
        final v = json['action'];
        print('[ClockStatus][ClockStatus] action (raw): $v');
        final result = v is String ? v : '';
        print('[ClockStatus][ClockStatus] action (parsed): $result');
        return result;
      })();
      final canClock = (() {
        final v = json['can_clock'];
        print('[ClockStatus][ClockStatus] canClock (raw): $v');
        final result = v is bool ? v : false;
        print('[ClockStatus][ClockStatus] canClock (parsed): $result');
        return result;
      })();
      final message = (() {
        final v = json['message'];
        print('[ClockStatus][ClockStatus] message (raw): $v');
        final result = v is String ? v : null;
        print('[ClockStatus][ClockStatus] message (parsed): $result');
        return result;
      })();
      final overtime = (() {
        final v = json['overtime'];
        print('[ClockStatus][ClockStatus] overtime (raw): $v');
        final result = v as bool?;
        print('[ClockStatus][ClockStatus] overtime (parsed): $result');
        return result;
      })();
      final eventTypeId = (() {
        final v = json['event_type_id'];
        print('[ClockStatus][ClockStatus] eventTypeId (raw): $v');
        if (v == null) return null;
        if (v is int) return v;
        if (v is String) {
          // Si viene como string, intenta convertirlo a int
          final parsed = int.tryParse(v);
          return parsed;
        }
        return null;
      })();
      final nextSlot = (() {
        final v = json['next_slot'];
        print('[ClockStatus][ClockStatus] nextSlot (raw): $v');
        try {
          if (v == null) return null;
          if (v is Map<String, dynamic>) {
            return NextSlot.fromJson(v);
          }
          if (v is String) {
            // Si viene como string, intenta decodificarlo
            // (asumiendo que es un JSON string)
            try {
              final decoded = v.isNotEmpty
                  ? Map<String, dynamic>.from(jsonDecode(v))
                  : null;
              if (decoded != null) return NextSlot.fromJson(decoded);
            } catch (e) {
              print('[ClockStatus][ERROR] Error decoding nextSlot string: $e');
            }
          }
          return null;
        } catch (e) {
          print('[ClockStatus][ERROR] Error converting nextSlot: $e');
          return null;
        }
      })();
      final todayStats = (() {
        final v = json['today_stats'];
        print('[ClockStatus][ClockStatus] todayStats (raw): $v');
        if (v == null) return TodayStats(totalEntries: 0, totalExits: 0);
        if (v is Map<String, dynamic>) return TodayStats.fromJson(v);
        if (v is String) {
          // Si viene como string, intenta decodificarlo
          // (asumiendo que es un JSON string)
          try {
            final decoded =
                v.isNotEmpty ? Map<String, dynamic>.from(jsonDecode(v)) : null;
            if (decoded != null) return TodayStats.fromJson(decoded);
          } catch (e) {
            print('[ClockStatus][ERROR] Error decoding todayStats string: $e');
          }
        }
        return TodayStats(totalEntries: 0, totalExits: 0);
      })();
      final currentTime = (() {
        final v = json['current_time'];
        print('[ClockStatus][ClockStatus] currentTime (raw): $v');
        final result = v is String
            ? (DateTime.tryParse(v) ?? DateTime.now())
            : DateTime.now();
        print('[ClockStatus][ClockStatus] currentTime (parsed): $result');
        return result;
      })();
      final workCenterCode = (() {
        final v = json['work_center_code'];
        return v is String ? v : null;
      })();
      final workCenterName = (() {
        final v = json['work_center_name'];
        print('[ClockStatus][ClockStatus] workCenterName (raw): $v');
        final result = v is String ? v : null;
        print('[ClockStatus][ClockStatus] workCenterName (parsed): $result');
        return result;
      })();
      final pauseEventId = (() {
        final v = json['pause_event_id'];
        print('[ClockStatus][ClockStatus] pauseEventId (raw): $v');
        if (v == null) return null;
        if (v is int) return v;
        if (v is String) {
          final parsed = int.tryParse(v);
          return parsed;
        }
        return null;
      })();
      return ClockStatus(
        action: action,
        canClock: canClock,
        message: message,
        overtime: overtime,
        eventTypeId: eventTypeId,
        nextSlot: nextSlot,
        todayStats: todayStats,
        currentTime: currentTime,
        workCenterCode: workCenterCode,
        workCenterName: workCenterName,
        pauseEventId: pauseEventId,
      );
    } catch (e) {
      print('[ClockStatus][ERROR] General error in fromJson: $e');
      return ClockStatus(
        action: '',
        canClock: false,
        message: null,
        overtime: null,
        eventTypeId: null,
        nextSlot: null,
        todayStats: TodayStats(totalEntries: 0, totalExits: 0),
        currentTime: DateTime.now(),
        pauseEventId: null,
      );
    }
  }
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

  static NextSlot fromJson(Map<String, dynamic> json) {
    try {
      print(
          '[ClockStatus][DEBUG] JSON recibido en NextSlot: ' + json.toString());
      final start = (() {
        final v = json['start'];
        print('[ClockStatus][NextSlot] start (raw): $v');
        final result = v is String ? v : '';
        print('[ClockStatus][NextSlot] start (parsed): $result');
        return result;
      })();
      final end = (() {
        final v = json['end'];
        print('[ClockStatus][NextSlot] end (raw): $v');
        final result = v is String ? v : '';
        print('[ClockStatus][NextSlot] end (parsed): $result');
        return result;
      })();
      final minutesUntil = (() {
        final v = json['minutes_until'];
        print('[ClockStatus][NextSlot] minutesUntil (raw): $v');
        final result = v as int?;
        print('[ClockStatus][NextSlot] minutesUntil (parsed): $result');
        return result;
      })();
      print(
          '[ClockStatus][DEBUG] Valores convertidos NextSlot: start=$start, end=$end, minutesUntil=$minutesUntil');
      return NextSlot(start: start, end: end, minutesUntil: minutesUntil);
    } catch (e) {
      print('[ClockStatus][ERROR] General error in NextSlot.fromJson: $e');
      return NextSlot(start: '', end: '', minutesUntil: null);
    }
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
    try {
      print('[ClockStatus][DEBUG] JSON recibido en TodayStats: ' +
          json.toString());
      final totalEntries = (() {
        final v = json['total_entries'];
        print('[ClockStatus][TodayStats] totalEntries (raw): $v');
        final result = v is int ? v : 0;
        print('[ClockStatus][TodayStats] totalEntries (parsed): $result');
        return result;
      })();
      final totalExits = (() {
        final v = json['total_exits'];
        print('[ClockStatus][TodayStats] totalExits (raw): $v');
        final result = v is int ? v : 0;
        print('[ClockStatus][TodayStats] totalExits (parsed): $result');
        return result;
      })();
      final workedHours = (() {
        final v = json['worked_hours'];
        print('[ClockStatus][TodayStats] workedHours (raw): $v');
        final result = v is String ? v : null;
        print('[ClockStatus][TodayStats] workedHours (parsed): $result');
        return result;
      })();
      final currentStatus = (() {
        final v = json['current_status'];
        print('[ClockStatus][TodayStats] currentStatus (raw): $v');
        final result = v is String ? v : null;
        print('[ClockStatus][TodayStats] currentStatus (parsed): $result');
        return result;
      })();
      print(
          '[ClockStatus][DEBUG] Valores convertidos TodayStats: totalEntries=$totalEntries, totalExits=$totalExits, workedHours=$workedHours, currentStatus=$currentStatus');
      return TodayStats(
          totalEntries: totalEntries,
          totalExits: totalExits,
          workedHours: workedHours,
          currentStatus: currentStatus);
    } catch (e) {
      print('[ClockStatus][ERROR] General error in TodayStats.fromJson: $e');
      return TodayStats(totalEntries: 0, totalExits: 0);
    }
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
