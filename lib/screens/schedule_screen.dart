import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/work_schedule.dart';
import '../services/schedule_service.dart';
import '../i18n/i18n_service.dart';
import '../utils/constants.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  String? _errorMessage;
  WorkSchedule? _schedule;
  
  // Temporary schedule for editing
  List<ScheduleEntry> _editedSchedule = [];

  final List<Map<String, String>> _days = [
    {'id': '1', 'label': 'L', 'full': 'Lunes'},
    {'id': '2', 'label': 'M', 'full': 'Martes'},
    {'id': '3', 'label': 'X', 'full': 'Miércoles'},
    {'id': '4', 'label': 'J', 'full': 'Jueves'},
    {'id': '5', 'label': 'V', 'full': 'Viernes'},
    {'id': '6', 'label': 'S', 'full': 'Sábado'},
    {'id': '7', 'label': 'D', 'full': 'Domingo'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final schedule = await ScheduleService.getSchedule();
      setState(() {
        _schedule = schedule;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (_schedule == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final newSchedule = WorkSchedule(
        schedule: _editedSchedule,
        timezone: _schedule!.timezone,
      );
      
      await ScheduleService.updateSchedule(newSchedule);
      
      setState(() {
        _schedule = newSchedule;
        _isEditing = false;
        _isSaving = false;
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.of('schedule.save_success'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      // Deep copy of the schedule
      _editedSchedule = _schedule!.schedule.map((e) => ScheduleEntry(
        days: List.from(e.days),
        start: e.start,
        end: e.end,
      )).toList();
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editedSchedule = [];
    });
  }

  void _addSlot() {
    setState(() {
      _editedSchedule.add(ScheduleEntry(
        days: ['1', '2', '3', '4', '5'], // Default Mon-Fri
        start: '09:00',
        end: '17:00',
      ));
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _editedSchedule.removeAt(index);
    });
  }

  Future<void> _editTime(int index, bool isStart) async {
    final entry = _editedSchedule[index];
    final timeStr = isStart ? entry.start : entry.end;
    final timeParts = timeStr.split(':');
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
    );

    if (picked != null) {
      setState(() {
        final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _editedSchedule[index] = ScheduleEntry(
          days: entry.days,
          start: isStart ? newTime : entry.start,
          end: !isStart ? newTime : entry.end,
        );
      });
    }
  }

  void _toggleDay(int index, String dayId) {
    setState(() {
      final entry = _editedSchedule[index];
      final days = List<String>.from(entry.days);
      if (days.contains(dayId)) {
        days.remove(dayId);
      } else {
        days.add(dayId);
      }
      _editedSchedule[index] = ScheduleEntry(
        days: days,
        start: entry.start,
        end: entry.end,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.of('schedule.title')),
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && _schedule != null)
            if (_isEditing) ...[
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _isSaving ? null : _cancelEditing,
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _isSaving ? null : _saveSchedule,
              ),
            ] else
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _startEditing,
              ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _isEditing
          ? FloatingActionButton(
              onPressed: _addSlot,
              backgroundColor: const Color(AppConstants.primaryColorValue),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSchedule,
              child: Text(I18n.of('retry')),
            ),
          ],
        ),
      );
    }

    final currentSchedule = _isEditing ? _editedSchedule : _schedule!.schedule;

    if (currentSchedule.isEmpty) {
      return Center(
        child: Text(
          'Sin horario configurado',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: currentSchedule.length + 1,
      itemBuilder: (context, index) {
        if (index == currentSchedule.length) {
          return const SizedBox(height: 80);
        }

        final entry = currentSchedule[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tramo Horario',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(AppConstants.primaryColorValue),
                      ),
                    ),
                    if (_isEditing)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeSlot(index),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Inicio', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          _isEditing
                              ? InkWell(
                                  onTap: () => _editTime(index, true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 16),
                                        const SizedBox(width: 8),
                                        Text(entry.start, style: const TextStyle(fontSize: 16)),
                                      ],
                                    ),
                                  ),
                                )
                              : Text(entry.start, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fin', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          _isEditing
                              ? InkWell(
                                  onTap: () => _editTime(index, false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 16),
                                        const SizedBox(width: 8),
                                        Text(entry.end, style: const TextStyle(fontSize: 16)),
                                      ],
                                    ),
                                  ),
                                )
                              : Text(entry.end, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Días activos', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _days.map((day) {
                    final isSelected = entry.days.contains(day['id']);
                    return InkWell(
                      onTap: _isEditing ? () => _toggleDay(index, day['id']!) : null,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(AppConstants.primaryColorValue)
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          day['label']!,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
