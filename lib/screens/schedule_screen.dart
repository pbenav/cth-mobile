import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/work_schedule.dart';
import '../services/schedule_service.dart';
import '../i18n/i18n_service.dart';
import '../utils/constants.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

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
  Map<String, List<String>> _editedSchedule = {};

  final List<String> _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.of('schedule.save_success') ?? 'Horario guardado correctamente')),
      );
    } catch (e) {
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
      _editedSchedule = {};
      _schedule!.schedule.forEach((key, value) {
        _editedSchedule[key] = List.from(value);
      });
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editedSchedule = {};
    });
  }

  void _addSlot(String day) {
    setState(() {
      _editedSchedule[day] = [...(_editedSchedule[day] ?? []), "09:00-14:00"];
    });
  }

  void _removeSlot(String day, int index) {
    setState(() {
      _editedSchedule[day]?.removeAt(index);
    });
  }

  Future<void> _editTime(String day, int index, bool isStart) async {
    final currentSlot = _editedSchedule[day]![index];
    final parts = currentSlot.split('-');
    final timeStr = isStart ? parts[0] : parts[1];
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
        if (isStart) {
          _editedSchedule[day]![index] = '$newTime-${parts[1]}';
        } else {
          _editedSchedule[day]![index] = '${parts[0]}-$newTime';
        }
      });
    }
  }

  String _getDayName(String dayKey) {
    // Simple translation map, ideally use I18n
    const map = {
      'monday': 'Lunes',
      'tuesday': 'Martes',
      'wednesday': 'Miércoles',
      'thursday': 'Jueves',
      'friday': 'Viernes',
      'saturday': 'Sábado',
      'sunday': 'Domingo',
    };
    return map[dayKey] ?? dayKey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.of('schedule.title') ?? 'Horario'),
        actions: [
          if (!_isLoading && _schedule != null)
            if (_isEditing)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _isSaving ? null : _saveSchedule,
              )
            else
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _startEditing,
              ),
        ],
      ),
      body: _buildBody(),
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
              child: Text(I18n.of('retry') ?? 'Reintentar'),
            ),
          ],
        ),
      );
    }

    final currentSchedule = _isEditing ? _editedSchedule : _schedule!.schedule;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _days.length + 1, // +1 for bottom padding
      itemBuilder: (context, index) {
        if (index == _days.length) {
          return const SizedBox(height: 80); // Space for FAB if needed
        }

        final day = _days[index];
        final slots = currentSchedule[day] ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getDayName(day),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isEditing)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                        onPressed: () => _addSlot(day),
                      ),
                  ],
                ),
                const Divider(),
                if (slots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sin horario',
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  ...slots.asMap().entries.map((entry) {
                    final i = entry.key;
                    final slot = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          if (_isEditing) ...[
                            _buildTimeButton(day, i, slot.split('-')[0], true),
                            const Text(' - '),
                            _buildTimeButton(day, i, slot.split('-')[1], false),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => _removeSlot(day, i),
                            ),
                          ] else
                            Text(
                              slot,
                              style: const TextStyle(fontSize: 16),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeButton(String day, int index, String time, bool isStart) {
    return InkWell(
      onTap: () => _editTime(day, index, isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          time,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
