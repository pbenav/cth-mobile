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
    // Defensive extraction: ensure nested objects are maps/lists before passing
    final Map<String, dynamic> userMap = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    final Map<String, dynamic> workCenterMap = (json['work_center'] is Map<String, dynamic>)
        ? json['work_center'] as Map<String, dynamic>
        : <String, dynamic>{};

    final List<dynamic>? scheduleList = (json['schedule'] is List<dynamic>) ? json['schedule'] as List<dynamic> : null;
    final List<dynamic>? holidaysList = (json['holidays'] is List<dynamic>) ? json['holidays'] as List<dynamic> : null;

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
    return ScheduleEntry(
      id: json['id'] ?? 0,
      dayOfWeek: json['day_of_week'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      isActive: json['is_active'] ?? true,
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