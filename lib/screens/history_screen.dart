import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/history_event.dart';
import '../models/user.dart';
import '../services/history_service.dart';
import '../utils/constants.dart';
import '../i18n/i18n_service.dart';

enum HistoryFilter { today, week, month, custom }

class HistoryScreen extends StatefulWidget {
  final User user;

  const HistoryScreen({
    super.key,
    required this.user,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryFilter _selectedFilter = HistoryFilter.today;
  List<HistoryEvent> _events = [];
  bool _isLoading = false;
  String? _errorMessage;
  HistoryPagination? _pagination;

import 'package:intl/date_symbol_data_local.dart';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null).then((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      HistoryResponse response;
      
      switch (_selectedFilter) {
        case HistoryFilter.today:
          response = await HistoryService.getTodayHistory(
            userCode: widget.user.code,
          );
          break;
        case HistoryFilter.week:
          response = await HistoryService.getWeekHistory(
            userCode: widget.user.code,
          );
          break;
        case HistoryFilter.month:
          response = await HistoryService.getMonthHistory(
            userCode: widget.user.code,
          );
          break;
        case HistoryFilter.custom:
          // TODO: Implement custom date picker
          response = await HistoryService.getMonthHistory(
            userCode: widget.user.code,
          );
          break;
      }

      if (mounted) {
        setState(() {
          _events = response.events;
          _pagination = response.pagination;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, List<HistoryEvent>> _groupEventsByDate() {
    final grouped = <String, List<HistoryEvent>>{};
    
    for (final event in _events) {
      if (event.start != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(event.start!.toLocal());
        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(event);
      }
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.of('history.title')),
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: I18n.of('history.filter.today'),
                    filter: HistoryFilter.today,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: I18n.of('history.filter.week'),
                    filter: HistoryFilter.week,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: I18n.of('history.filter.month'),
                    filter: HistoryFilter.month,
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required HistoryFilter filter,
  }) {
    final isSelected = _selectedFilter == filter;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filter;
          });
          _loadHistory();
        }
      },
      selectedColor: const Color(AppConstants.primaryColorValue).withOpacity(0.2),
      checkmarkColor: const Color(AppConstants.primaryColorValue),
      labelStyle: TextStyle(
        color: isSelected 
            ? const Color(AppConstants.primaryColorValue)
            : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              I18n.of('history.error'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: Text(I18n.of('common.retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.primaryColorValue),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              I18n.of('history.empty'),
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _buildEventsList(),
      ),
    );
  }

  List<Widget> _buildEventsList() {
    final groupedEvents = _groupEventsByDate();
    final sortedDates = groupedEvents.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Most recent first

    final widgets = <Widget>[];

    for (final dateKey in sortedDates) {
      final events = groupedEvents[dateKey]!;
      final date = DateTime.parse(dateKey);
      
      // Date header
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            _formatDateHeader(date),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(AppConstants.primaryColorValue),
            ),
          ),
        ),
      );

      // Events for this date
      for (final event in events) {
        widgets.add(_buildEventCard(event));
        widgets.add(const SizedBox(height: 12));
      }
    }

    return widgets;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) {
      return I18n.of('history.today');
    } else if (eventDate == yesterday) {
      return I18n.of('history.yesterday');
    } else {
      return DateFormat('EEEE, d MMMM yyyy', 'es').format(date);
    }
  }

  Widget _buildEventCard(HistoryEvent event) {
    final startTime = event.start != null
        ? DateFormat('HH:mm').format(event.start!.toLocal())
        : '--:--';
    final endTime = event.end != null
        ? DateFormat('HH:mm').format(event.end!.toLocal())
        : '--:--';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event type and status
            Row(
              children: [
                Icon(
                  _getEventIcon(event),
                  color: _getEventColor(event),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.type,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (event.isOpen)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      I18n.of('history.status.open'),
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Time range
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '$startTime - $endTime',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                if (event.durationFormatted != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    event.durationFormatted!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),

            // Observations
            if (event.observations != null && event.observations!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.observations!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Status badges
            if (event.isAuthorized || event.isExceptional) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (event.isAuthorized)
                    _buildStatusBadge(
                      I18n.of('history.status.authorized'),
                      Colors.blue,
                    ),
                  if (event.isExceptional)
                    _buildStatusBadge(
                      I18n.of('history.status.exceptional'),
                      Colors.orange,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withOpacity(1.0),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getEventIcon(HistoryEvent event) {
    if (event.type.toLowerCase().contains('pausa') ||
        event.type.toLowerCase().contains('break')) {
      return Icons.pause_circle;
    }
    return Icons.work;
  }

  Color _getEventColor(HistoryEvent event) {
    if (event.isOpen) {
      return Colors.green;
    }
    if (event.type.toLowerCase().contains('pausa') ||
        event.type.toLowerCase().contains('break')) {
      return Colors.orange;
    }
    return const Color(AppConstants.primaryColorValue);
  }
}
