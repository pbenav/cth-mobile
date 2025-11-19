import 'user.dart';
import 'work_center.dart';

class WorkerData {
  final User user;
  final WorkCenter workCenter;
  final List<ScheduleEntry> schedule;
  final List<Holiday> holidays;

  const WorkerData({
    required this.user,
    required this.workCenter,
    required this.schedule,
    required this.holidays,
  });

  factory WorkerData.fromJson(Map<String, dynamic> json) {
    // Defensive extraction: accept multiple possible key names used by the API
    Map<String, dynamic> ensureMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      return <String, dynamic>{};
    }

    final Map<String, dynamic> userMap = ensureMap(json['user'] ?? json['worker'] ?? json['employee'] ?? json['empleado']);

    // The backend may return work_center as a single map or as a list under
    // the key 'work_centers'. If it's a list, take the first element.
    Map<String, dynamic> workCenterCandidate = ensureMap(json['work_center'] ?? json['workcenter'] ?? json['workCenter'] ?? json['centro']);
    if (workCenterCandidate.isEmpty) {
      final wc = json['work_centers'];
      if (wc is List<dynamic>) {
        // prefer first element that looks like a work center map
        for (final item in wc) {
          if (item is Map<String, dynamic>) {
            // sometimes item may be wrapped under 'data' or 'work_center'
            if (item.containsKey('id') || item.containsKey('code') || item.containsKey('name')) {
              workCenterCandidate = item;
              break;
            } else if (item.containsKey('work_center') && item['work_center'] is Map<String, dynamic>) {
              workCenterCandidate = item['work_center'] as Map<String, dynamic>;
              break;
            } else if (item.containsKey('data') && item['data'] is Map<String, dynamic>) {
              final inner = item['data'] as Map<String, dynamic>;
              if (inner.containsKey('id') || inner.containsKey('code')) {
                workCenterCandidate = inner;
                break;
              }
            }
          }
        }
      } else if (wc is Map<String, dynamic>) {
        // handle wrapper objects like { data: { ... } } or { data: [ ... ] }
        if (wc.containsKey('data')) {
          final d = wc['data'];
          if (d is Map<String, dynamic>) {
            workCenterCandidate = d;
          } else if (d is List<dynamic> && d.isNotEmpty && d.first is Map<String, dynamic>) {
            workCenterCandidate = d.first as Map<String, dynamic>;
          }
        } else {
          workCenterCandidate = wc;
        }
      }
    }
    final Map<String, dynamic> workCenterMap = ensureMap(workCenterCandidate);

  // Accept various keys for schedules used by backend: 'schedule',
  // 'schedules', or 'work_schedule'. Prefer the first one that exists.
  List<dynamic>? scheduleList;
  if (json['schedule'] is List<dynamic>) {
    scheduleList = json['schedule'] as List<dynamic>;
  } else if (json['schedules'] is List<dynamic>) {
    scheduleList = json['schedules'] as List<dynamic>;
  } else if (json['work_schedule'] is List<dynamic>) {
    scheduleList = json['work_schedule'] as List<dynamic>;
  } else if (json['work_schedule'] is Map<String, dynamic>) {
    // Some backends wrap schedule under an object, try common keys
    final ws = json['work_schedule'] as Map<String, dynamic>;
    // normalize nested 'data' wrappers too
    if (ws['data'] is List<dynamic>) {
      scheduleList = ws['data'] as List<dynamic>;
    } else if (ws['entries'] is List<dynamic>) {
      scheduleList = ws['entries'] as List<dynamic>;
    } else if (ws['items'] is List<dynamic>) {
      scheduleList = ws['items'] as List<dynamic>;
    } else if (ws['tramos'] is List<dynamic>) {
      scheduleList = ws['tramos'] as List<dynamic>;
    } else if (ws['schedule'] is List<dynamic>) {
      scheduleList = ws['schedule'] as List<dynamic>;
    } else {
      scheduleList = null;
    }
  } else {
    scheduleList = null;
  }

  final List<dynamic>? holidaysList = (json['holidays'] is List<dynamic>)
    ? json['holidays'] as List<dynamic>
    : (json['festivos'] is List<dynamic> ? json['festivos'] as List<dynamic> : null);

  // Additional possible shape: schedules wrapped under 'data' at root
  if (scheduleList == null) {
    if (json['data'] is Map<String, dynamic>) {
      final rootData = json['data'] as Map<String, dynamic>;
      if (rootData['work_schedule'] is List<dynamic>) {
        scheduleList = rootData['work_schedule'] as List<dynamic>;
      } else if (rootData['schedule'] is List<dynamic>) scheduleList = rootData['schedule'] as List<dynamic>;
      else if (rootData['schedules'] is List<dynamic>) scheduleList = rootData['schedules'] as List<dynamic>;
      else if (rootData['work_schedule'] is Map<String, dynamic>) {
        final ws = rootData['work_schedule'] as Map<String, dynamic>;
        if (ws['data'] is List<dynamic>) scheduleList = ws['data'] as List<dynamic>;
      }
    }
  }

    return WorkerData(
      user: User.fromJson(userMap),
      workCenter: WorkCenter.fromJson(workCenterMap),
      schedule: scheduleList?.map((e) => ScheduleEntry.fromJson(e is Map<String, dynamic> ? e : <String, dynamic>{})).toList() ?? [],
      holidays: holidaysList?.map((e) => Holiday.fromJson(e is Map<String, dynamic> ? e : <String, dynamic>{})).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'work_center': workCenter.toJson(),
      'schedule': schedule.map((e) => e.toJson()).toList(),
      'holidays': holidays.map((e) => e.toJson()).toList(),
    };
  }
}

class ScheduleEntry {
  final int id;
  final String dayOfWeek; // 'monday', 'tuesday', etc.
  final String startTime; // '08:00'
  final String endTime; // '17:00'
  final bool isActive;

  const ScheduleEntry({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isActive,
  });

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    String extractDay(Map<String, dynamic> j) {
      if (j['day_of_week'] != null) return j['day_of_week'];
      if (j['day'] != null) return j['day'];
      if (j['weekday'] != null) return j['weekday'];
      if (j['dia'] != null) return j['dia'];
      if (j['dia_semana'] != null) return j['dia_semana'];
      // Some APIs return an array of days under 'days' (e.g. ["L","M","X"]).
      if (j['days'] is List<dynamic>) {
        try {
          return (j['days'] as List<dynamic>).map((e) => e.toString()).join(',');
        } catch (_) {
          return '';
        }
      }
      return '';
    }

    String extractStart(Map<String, dynamic> j) {
      return j['start_time'] ?? j['start'] ?? j['hora_inicio'] ?? j['inicio'] ?? '';
    }

    String extractEnd(Map<String, dynamic> j) {
      return j['end_time'] ?? j['end'] ?? j['hora_fin'] ?? j['fin'] ?? '';
    }

    bool extractActive(Map<String, dynamic> j) {
      if (j.containsKey('is_active')) return j['is_active'] == true;
      if (j.containsKey('active')) return j['active'] == true;
      if (j.containsKey('activo')) return j['activo'] == true;
      return true;
    }

    return ScheduleEntry(
      id: json['id'] ?? json['schedule_id'] ?? 0,
      dayOfWeek: extractDay(json),
      startTime: extractStart(json),
      endTime: extractEnd(json),
      isActive: extractActive(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'is_active': isActive,
    };
  }

  String get dayName {
    switch (dayOfWeek.toLowerCase()) {
      case 'monday': return 'Lunes';
      case 'tuesday': return 'Martes';
      case 'wednesday': return 'Miércoles';
      case 'thursday': return 'Jueves';
      case 'friday': return 'Viernes';
      case 'saturday': return 'Sábado';
      case 'sunday': return 'Domingo';
      default: return dayOfWeek;
    }
  }
}

class Holiday {
  final int id;
  final String date; // '2025-01-01'
  final String name; // 'Año Nuevo'
  final String type; // 'national', 'regional', 'company'

  const Holiday({
    required this.id,
    required this.date,
    required this.name,
    required this.type,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'national',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'name': name,
      'type': type,
    };
  }

  String get typeName {
    switch (type.toLowerCase()) {
      case 'national': return 'Nacional';
      case 'regional': return 'Regional';
      case 'company': return 'Empresa';
      default: return type;
    }
  }
}