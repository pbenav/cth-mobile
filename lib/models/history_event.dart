class HistoryEvent {
  final int id;
  final String type;
  final int eventTypeId;
  final DateTime? start;
  final DateTime? end;
  final int? durationSeconds;
  final String? durationFormatted;
  final bool isOpen;
  final bool isAuthorized;
  final bool isExceptional;
  final String? observations;
  final String? description;
  final DateTime? createdAt;

  HistoryEvent({
    required this.id,
    required this.type,
    required this.eventTypeId,
    this.start,
    this.end,
    this.durationSeconds,
    this.durationFormatted,
    required this.isOpen,
    required this.isAuthorized,
    required this.isExceptional,
    this.observations,
    this.description,
    this.createdAt,
  });

  factory HistoryEvent.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value == '1' || value.toLowerCase() == 'true';
      return false;
    }

    return HistoryEvent(
      id: json['id'] as int,
      type: json['type'] as String,
      eventTypeId: json['event_type_id'] as int,
      start: json['start'] != null ? DateTime.parse(json['start']) : null,
      end: json['end'] != null ? DateTime.parse(json['end']) : null,
      durationSeconds: json['duration_seconds'] as int?,
      durationFormatted: json['duration_formatted'] as String?,
      isOpen: parseBool(json['is_open']),
      isAuthorized: parseBool(json['is_authorized']),
      isExceptional: parseBool(json['is_exceptional']),
      observations: json['observations'] as String?,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'event_type_id': eventTypeId,
      'start': start?.toIso8601String(),
      'end': end?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'duration_formatted': durationFormatted,
      'is_open': isOpen,
      'is_authorized': isAuthorized,
      'is_exceptional': isExceptional,
      'observations': observations,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class HistoryResponse {
  final List<HistoryEvent> events;
  final HistoryPagination pagination;
  final HistoryFilters filters;

  HistoryResponse({
    required this.events,
    required this.pagination,
    required this.filters,
  });

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    
    return HistoryResponse(
      events: (data['events'] as List)
          .map((e) => HistoryEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: HistoryPagination.fromJson(
        data['pagination'] as Map<String, dynamic>
      ),
      filters: HistoryFilters.fromJson(
        data['filters'] as Map<String, dynamic>
      ),
    );
  }
}

class HistoryPagination {
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final bool hasMore;

  HistoryPagination({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.hasMore,
  });

  factory HistoryPagination.fromJson(Map<String, dynamic> json) {
    return HistoryPagination(
      currentPage: json['current_page'] as int,
      perPage: json['per_page'] as int,
      total: json['total'] as int,
      lastPage: json['last_page'] as int,
      hasMore: json['has_more'] as bool,
    );
  }
}

class HistoryFilters {
  final String startDate;
  final String endDate;

  HistoryFilters({
    required this.startDate,
    required this.endDate,
  });

  factory HistoryFilters.fromJson(Map<String, dynamic> json) {
    return HistoryFilters(
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
    );
  }
}
