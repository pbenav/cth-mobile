class ScheduleEntry {
  final List<String> days;
  final String start;
  final String end;

  ScheduleEntry({
    required this.days,
    required this.start,
    required this.end,
  });

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    return ScheduleEntry(
      days: (json['days'] as List?)?.map((e) => e.toString()).toList() ?? [],
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'days': days,
      'start': start,
      'end': end,
    };
  }
}

class WorkSchedule {
  final List<ScheduleEntry> schedule;
  final String timezone;

  WorkSchedule({
    required this.schedule,
    required this.timezone,
  });

  factory WorkSchedule.fromJson(Map<String, dynamic> json) {
    final scheduleData = json['schedule'] as List?;
    final List<ScheduleEntry> parsedSchedule = [];

    if (scheduleData != null) {
      for (var item in scheduleData) {
        if (item is Map<String, dynamic>) {
          parsedSchedule.add(ScheduleEntry.fromJson(item));
        }
      }
    }

    return WorkSchedule(
      schedule: parsedSchedule,
      timezone: json['timezone'] as String? ?? 'UTC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule': schedule.map((e) => e.toJson()).toList(),
      'timezone': timezone,
    };
  }
}
