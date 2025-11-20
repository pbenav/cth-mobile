class WorkSchedule {
  final Map<String, List<String>> schedule;
  final String timezone;

  WorkSchedule({
    required this.schedule,
    required this.timezone,
  });

  factory WorkSchedule.fromJson(Map<String, dynamic> json) {
    final scheduleData = json['schedule'] as Map<String, dynamic>? ?? {};
    final Map<String, List<String>> parsedSchedule = {};

    scheduleData.forEach((key, value) {
      if (value is List) {
        parsedSchedule[key] = value.map((e) => e.toString()).toList();
      }
    });

    return WorkSchedule(
      schedule: parsedSchedule,
      timezone: json['timezone'] as String? ?? 'UTC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule': schedule,
      'timezone': timezone,
    };
  }

  List<String> getForDay(String day) {
    return schedule[day.toLowerCase()] ?? [];
  }
}
