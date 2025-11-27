import 'package:flutter/material.dart';
import 'dart:async';
import '../i18n/i18n_service.dart';
import '../models/work_center.dart';
import '../models/user.dart';
import '../models/clock_status.dart';
import '../services/clock_service.dart';
import '../services/storage_service.dart';
import '../services/nfc_service.dart';
import '../utils/clock_messages.dart';
import '../utils/exceptions.dart';

import '../services/setup_service.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'schedule_screen.dart';
import '../utils/constants.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class ClockScreen extends StatefulWidget {
  final WorkCenter workCenter;
  final User user;
  final bool autoClockOnNFC;

  const ClockScreen({
    super.key,
    required this.workCenter,
    required this.user,
    this.autoClockOnNFC = false,
  });

  @override
  _ClockScreenState createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> with RouteAware {
  // RouteAware: refresca NFC al volver de otra pantalla
  @override
  void didPopNext() {
    _loadNFCEnabled();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
    _loadNFCEnabled();
  }

  @override
  void dispose() {
    // Desregistrar RouteObserver
    routeObserver.unsubscribe(this);
    _hoursUpdateTimer?.cancel();
    super.dispose();
  }

  // --- DIÁLOGOS DE CONFIRMACIÓN ---
  void _showExceptionalClockInDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fichaje excepcional'),
        content: const Text(
            'Estás fuera de tu horario laboral. ¿Confirmas el fichaje excepcional?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performClockWithAction('exceptional_clock_in');
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showClockOutDialog() {
    if (_nfcEnabled) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar salida'),
          content: const Text('¿Seguro que quieres fichar la salida?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performClockWithNFC(action: 'clock_out');
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
    } else {
      _performClockWithAction('clock_out');
    }
  }

  ClockStatus? clockStatus;
  bool isLoading = false;
  bool isPerformingClock = false;
  bool _nfcEnabled = true;
  bool _nfcAvailable = true;
  bool _isLocallyWithinSchedule = false;
  Timer? _hoursUpdateTimer;
  String? _calculatedWorkedHours;

  Future<void> _loadStatus() async {
    setState(() => isLoading = true);
    try {
      final response = await ClockService.getStatus(
        userCode: widget.user.code,
      );
      final isWithin = await _isWithinSchedule();
      setState(() {
        clockStatus = response.data;
        _isLocallyWithinSchedule = isWithin;
        _updateCalculatedHours();
      });
      
      _startHoursUpdateTimer();
    } catch (e) {
      String errorMessage = e.toString();
      if (e is ClockException && e.apiStatusCode != null) {
        errorMessage = ClockMessages.getMessage(e.apiStatusCode, fallbackMessage: e.message);
      }
      _showError(I18n.of('clock.loading_error', {'error': errorMessage}));
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Normaliza un día a su número ISO (1=Monday, 7=Sunday)
  /// Soporta: inglés completo, español completo, abreviaturas ES, números ISO
  int? _normalizeDayToISO(String day) {
    final normalized = day.trim().toLowerCase();
    
    // Mapeo completo de todos los formatos posibles
    final dayMap = {
      // Inglés completo
      'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
      'friday': 5, 'saturday': 6, 'sunday': 7,
      // Español completo
      'lunes': 1, 'martes': 2, 'miércoles': 3, 'miercoles': 3,
      'jueves': 4, 'viernes': 5, 'sábado': 6, 'sabado': 6, 'domingo': 7,
      // Abreviaturas españolas
      'l': 1, 'm': 2, 'x': 3, 'j': 4, 'v': 5, 's': 6, 'd': 7,
      // Abreviaturas inglesas
      'mon': 1, 'tue': 2, 'wed': 3, 'thu': 4, 'fri': 5, 'sat': 6, 'sun': 7,
    };
    
    // Intentar mapeo directo
    if (dayMap.containsKey(normalized)) {
      return dayMap[normalized];
    }
    
    // Intentar parsear como número ISO (1-7)
    final num = int.tryParse(normalized);
    if (num != null && num >= 1 && num <= 7) {
      return num;
    }
    
    return null;
  }

  Future<String> _getCurrentTimeSlot() async {
    try {
      final now = DateTime.now();
      final currentDayISO = now.weekday; // 1=Monday, 7=Sunday
      
      // Obtener todo el schedule guardado
      final allSchedule = await SetupService.getSavedSchedule();
      
      // Buscar una entrada que contenga el día actual
      for (var entry in allSchedule) {
        if (!entry.isActive) continue;
        
        // El campo dayOfWeek puede contener múltiples días separados por comas
        final daysParts = entry.dayOfWeek.split(',').map((d) => d.trim()).toList();
        
        // Normalizar cada día a número ISO y verificar si coincide
        for (var dayPart in daysParts) {
          final dayISO = _normalizeDayToISO(dayPart);
          if (dayISO == currentDayISO) {
            return '${entry.startTime} - ${entry.endTime}';
          }
        }
      }
      
      return 'Sin tramo horario';
    } catch (e) {
      return 'Sin tramo horario';
    }
  }

  Future<bool> _isWithinSchedule() async {
    try {
      final now = DateTime.now();
      final currentDayISO = now.weekday;

      
      final allSchedule = await SetupService.getSavedSchedule();

      
      for (var entry in allSchedule) {

        
        if (!entry.isActive) continue;
        
        final daysParts = entry.dayOfWeek.split(',').map((d) => d.trim()).toList();
        bool isToday = false;
        for (var dayPart in daysParts) {
          final normalized = _normalizeDayToISO(dayPart);

          if (normalized == currentDayISO) {
            isToday = true;
            break;
          }
        }
        
        if (isToday) {
          final inSlot = _isTimeInSlot(now, entry.startTime, entry.endTime);

          if (inSlot) {
            return true;
          }
        } else {

        }
      }

      return false;
    } catch (e) {

      return false;
    }
  }

  bool _isTimeInSlot(DateTime now, String startStr, String endStr) {
    try {
      if (startStr.isEmpty || endStr.isEmpty) return false;

      final nowMinutes = now.hour * 60 + now.minute;
      
      int parseTime(String timeStr) {
        String cleanTime = timeStr.trim();
        // Handle "YYYY-MM-DD HH:MM:SS" or "YYYY-MM-DDTHH:MM:SS"
        if (cleanTime.contains('T')) {
          cleanTime = cleanTime.split('T')[1];
        } else if (cleanTime.contains(' ')) {
          cleanTime = cleanTime.split(' ').last;
        }
        
        final parts = cleanTime.split(':');
        if (parts.isEmpty) throw FormatException('Empty time string');
        final h = int.parse(parts[0]);
        final m = parts.length > 1 ? int.parse(parts[1]) : 0;
        return h * 60 + m;
      }

      final startMinutes = parseTime(startStr);
      final endMinutes = parseTime(endStr);
      
      if (endMinutes < startMinutes) {
        // Crosses midnight (e.g. 22:00 to 06:00 -> 1320 to 360)
        return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
      } else {
        // Normal (e.g. 08:00 to 15:00 -> 480 to 900)
        return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
      }
    } catch (e) {

      return false;
    }
  }

  void _startHoursUpdateTimer() {
    _hoursUpdateTimer?.cancel();
    if (clockStatus?.todayStats.currentStatus == 'TRABAJANDO') {
      // Actualizar cada 10 segundos para una UI reactiva
      // NOTA: Esta actualización es puramente local (UI) y NO genera tráfico de red.
      _hoursUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (mounted) {
          setState(() {
            _updateCalculatedHours();
          });
        }
      });
    }
  }

  void _updateCalculatedHours() {
    if (clockStatus == null) {
      _calculatedWorkedHours = null;
      return;
    }

    // Si no hay eventos del día, usar el valor del servidor
    if (clockStatus!.todayRecords.isEmpty) {
      _calculatedWorkedHours = clockStatus!.todayStats.workedHours;
      return;
    }

    // Calcular las horas trabajadas basándose en los eventos del día
    Duration totalWorked = Duration.zero;
    
    // IMPORTANTE: El servidor envía timestamps en hora local pero marcados como UTC
    // Por eso usamos hora local para el cálculo
    final now = DateTime.now();

    // Ordenar eventos por timestamp
    final sortedEvents = List<ClockEvent>.from(clockStatus!.todayRecords)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final event in sortedEvents) {
      
      // IMPORTANTE: Solo contar eventos de trabajo, NO pausas
      // Las pausas suelen tener nombres como "Pausa", "Break", "Descanso", etc.
      final isBreakEvent = event.type.toLowerCase().contains('pausa') || 
                          event.type.toLowerCase().contains('break') ||
                          event.type.toLowerCase().contains('descanso');
      
      // Calcular duración del evento
      Duration eventDuration = Duration.zero;
      
      if (event.start != null) {
        // Convertir start/end de UTC a local
        final startLocal = event.start!.toLocal();
        
        if (event.end != null) {
          // Evento cerrado
          final endLocal = event.end!.toLocal();
          eventDuration = endLocal.difference(startLocal);
        } else if (event.isOpen == true) {
          // Evento abierto
          eventDuration = now.difference(startLocal);
        }
      }

      if (isBreakEvent) {

        totalWorked -= eventDuration;
      } else {

        totalWorked += eventDuration;
      }
    }

    // Si el cálculo da 0 pero el servidor tiene un valor, usar el del servidor
    if (totalWorked.inSeconds == 0 && clockStatus!.todayStats.workedHours != null) {
      _calculatedWorkedHours = clockStatus!.todayStats.workedHours;
    } else {
      final hours = totalWorked.inHours;
      final minutes = totalWorked.inMinutes.remainder(60);
      final seconds = totalWorked.inSeconds.remainder(60);
      
      // Si es menos de 1 minuto, mostrar segundos
      if (totalWorked.inMinutes == 0) {
        _calculatedWorkedHours = '0:00:${seconds.toString().padLeft(2, '0')}';
      } else {
        _calculatedWorkedHours = '${hours.toString().padLeft(1, '0')}:${minutes.toString().padLeft(2, '0')}';
      }
    }
    

  }

  Future<void> _ensureScheduleLoaded(String userCode) async {
    try {

      // Forzar actualización de datos del trabajador (incluyendo horario)
      await SetupService.refreshSavedWorkerData(
        blocking: true,
        timeout: const Duration(seconds: 5),

      );

    } catch (e) {

    }
  }

  Color _getStatusBackgroundColor(String? status) {
    if (status == null) return Colors.grey;
    final upper = status.toUpperCase();
    if (upper == 'INICIAR JORNADA' || upper == 'TRABAJANDO') {
      return const Color(AppConstants.successColorValue);
    }
    if (upper == 'INICIAR REGISTRO EXCEPCIONAL' ||
        upper.contains('EXCEPCIONAL') ||
        upper.contains('FUERA DE HORARIO')) {
      // Si localmente estamos en horario, mostramos verde (éxito) en lugar de naranja
      if (_isLocallyWithinSchedule) {
        return const Color(AppConstants.successColorValue);
      }
      return const Color(AppConstants.warningColorValue);
    }
    return Colors.grey;
  }

  // ...resto de la clase y métodos...
  @override
  void initState() {
    super.initState();
    _loadStatus();
    _checkNFCAvailability();
    _loadNFCEnabled();
  }

  Future<void> _checkNFCAvailability() async {
    // Simulación: aquí deberías usar un paquete como 'flutter_nfc_kit' para comprobar si el dispositivo soporta NFC
    // Por ahora, asumimos que existe un método NFCService.isAvailable()
    try {
      final available = await NFCService.isNFCAvailable();
      setState(() {
        _nfcAvailable = available;
        if (!available) {
          _nfcEnabled = false;
        }
      });
    } catch (e) {
      setState(() {
        _nfcAvailable = false;
        _nfcEnabled = false;
      });
    }
  }

  Future<void> _loadNFCEnabled() async {
    final enabled = await StorageService.getBool('nfc_enabled');
    setState(() {
      _nfcEnabled = enabled ?? true;
    });
  }

  // --- MÉTODOS DE UTILIDAD REFACTORIZADOS (DRY) ---

  Future<String> _getEffectiveUserCode() async {
    return (widget.user.code.trim().isNotEmpty)
        ? widget.user.code.trim()
        : (await StorageService.getUser())?.code ?? '';
  }

  Future<String> _getEffectiveWorkCenterCode() async {
    return (widget.workCenter.code.trim().isNotEmpty)
        ? widget.workCenter.code.trim()
        : (await StorageService.getWorkCenter())?.code ?? '';
  }

  Future<void> _performClockWithAction([String? action]) async {
    if (isPerformingClock) return;
    setState(() => isPerformingClock = true);
    try {
      final userCode = await _getEffectiveUserCode();
      final workCenterCode = await _getEffectiveWorkCenterCode();

      if (userCode.isEmpty) {
        if (mounted) _showError(I18n.of('clock.no_user'));
        return;
      }

      // Solo NFC si preferencia activada Y disponible
      // Validar también el caso de fichaje excepcional con NFC
      if ((action == 'clock_in' ||
          action == 'clock_out' ||
          action == 'exceptional_clock_in')) {
        if (_nfcEnabled && _nfcAvailable) {
          await _performClockWithNFC(action: action);
          return;
        } else {
          // Si NFC está desactivado o no disponible, mostrar confirmación antes de fichar
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(I18n.of('clock.clock_in')),
              content: Text(
                  '¿Seguro que quieres fichar el inicio/cierre de jornada?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(I18n.of('dialog.cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Confirmar'),
                ),
              ],
            ),
          );
          if (confirmed != true) {
            setState(() => isPerformingClock = false);
            return;
          }
        }
      }

      if (action == 'resume_workday') {
        int? pauseEventId = clockStatus?.pauseEventId;
        


        
        // Si no viene del backend, intentamos buscarlo localmente (fallback)
        if (pauseEventId == null) {

          const int pauseEventTypeId = 285; // Actualiza este valor según tu backend
          if (clockStatus != null && clockStatus!.todayRecords.isNotEmpty) {

            for (final event in clockStatus!.todayRecords) {

              if (event.eventTypeId == pauseEventTypeId && _isOpenStatus(event)) {
                pauseEventId = event.id;

                break;
              }
            }
          }
        }
        

        
        if (pauseEventId == null) {
          if (mounted) {
            _showError(
                'No se puede reanudar la jornada: falta el identificador de pausa.');
          }
          return;
        }
        await ClockService.performClock(
          workCenterCode: workCenterCode,
          userCode: userCode,
          action: action,
          pauseEventId: pauseEventId,
        );
      } else {
        // Si el dispositivo no soporta NFC, añade observación
        String? observations;
        if ((action == 'clock_in' || action == 'clock_out') && !_nfcAvailable) {
          observations = 'Evento creado sin comprobación/autorización NFC.';
        }
        // Para inicio de jornada (clock_in) nunca se debe enviar 'action'
        if (action == 'clock_in') {
          await ClockService.performClock(
            workCenterCode: workCenterCode,
            userCode: userCode,
            observations: observations,
          );
        } else {
          await ClockService.performClock(
            workCenterCode: workCenterCode,
            userCode: userCode,
            action: (action == 'clock_in') ? null : action,
            observations: observations,
          );
        }
      }

      if (mounted) {
        String actionText =
            (action == 'clock_in' || action == 'exceptional_clock_in')
                ? I18n.of('clock.clock_in')
                : I18n.of('clock.clock_out');
        _showSuccess(I18n.of('clock.fichaje_success', {'action': actionText}));
        await _loadStatus();
        // Si se reanuda jornada, puedes agregar aquí un log si lo necesitas
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (e is ClockException && e.apiStatusCode != null) {
          errorMessage = ClockMessages.getMessage(e.apiStatusCode, fallbackMessage: e.message);
        }
        _showError(I18n.of('clock.fichaje_error', {'error': errorMessage}));
      }
    } finally {
      if (mounted) {
        setState(() => isPerformingClock = false);
      }
    }
  }

  // --- MÉTODOS DE COMPARACIÓN DE EVENTOS LOCALIZADOS ---

  bool _isOpenStatus(dynamic event) {
    if (event == null) return false;
    if (event.isOpen != null) return event.isOpen == true;
    final status = (event.status ?? '').toString().toLowerCase();
    return status == 'open' || status == 'true' || status == 'abierto';
  }

  Future<void> _performClockWithNFC({String? action}) async {
    if (isPerformingClock) return;
    setState(() => isPerformingClock = true);
    try {
      final userCode = await _getEffectiveUserCode();
      final workCenterCode = await _getEffectiveWorkCenterCode();
      if (userCode.isEmpty) {
        if (mounted) _showError(I18n.of('clock.no_user'));
        return;
      }
      // Validación NFC: preferencia y disponibilidad
      if (_nfcEnabled) {
        if (!_nfcAvailable) {
          // Mostrar mensaje de que NFC no está disponible
          if (mounted) _showError(I18n.of('nfc.not_available'));
          // Pedir confirmación antes de fichar
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(I18n.of('clock.clock_in')),
              content:
                  Text('El dispositivo no soporta NFC. ¿Confirmas el fichaje?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(I18n.of('dialog.cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Confirmar'),
                ),
              ],
            ),
          );
          if (confirmed != true) {
            setState(() => isPerformingClock = false);
            return;
          }
        } else {
          _showSuccess(I18n.of('clock.nfc_prompt'));
          final nfcWorkCenter = await NFCService.scanWorkCenter();
          if (nfcWorkCenter == null || nfcWorkCenter.code != workCenterCode) {
            if (mounted) _showError(I18n.of('clock.nfc_invalid'));
            return;
          }
        }
      }
      await _ensureScheduleLoaded(userCode);
      
      // Determinar observaciones según horario y NFC
      String? observations;
      if (_nfcEnabled) {
        final isWithinSchedule = await _isWithinSchedule();
        if (!isWithinSchedule) {
          observations = 'Evento creado con comprobación/autorización NFC.';
        }
        // Si está dentro del horario, observations se mantiene null (sin excepcionalidad)
      } else {
        observations = 'Evento creado sin comprobación/autorización NFC.';
      }

      // Para inicio de jornada (clock_in) nunca se debe enviar 'action'
      if (action == 'clock_in') {
        await ClockService.performClock(
          workCenterCode: workCenterCode,
          userCode: userCode,
          observations: observations,
        );
      } else {
        await ClockService.performClock(
          workCenterCode: workCenterCode,
          userCode: userCode,
          action: action,
          observations: observations,
        );
      }
      if (mounted) {
        String actionText =
            (action == 'clock_in' || action == 'exceptional_clock_in')
                ? I18n.of('clock.clock_in')
                : I18n.of('clock.clock_out');
        _showSuccess(I18n.of('clock.fichaje_success', {'action': actionText}));
        await _loadStatus();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (e is ClockException && e.apiStatusCode != null) {
          errorMessage = ClockMessages.getMessage(e.apiStatusCode, fallbackMessage: e.message);
        }
        _showError(I18n.of('clock.fichaje_error', {'error': errorMessage}));
      }
    } finally {
      if (mounted) {
        setState(() => isPerformingClock = false);
      }
    }
  }

  // --- WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Opacity(
              opacity: 0.8,
              child: Image.asset(
                'assets/images/cth-logo.png',
                height: 28,
                width: 28,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Text(I18n.of('app.title')),
          ],
        ),
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _loadStatus,
          ),

          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              if (result == true) {
                await _loadStatus();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
              const Color(AppConstants.primaryColorValue).withOpacity(0.1),
              Colors.white,
            ])),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacing),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Línea 261 (Inicio de la lista de children)
                  // Work Center Info
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.cardBorderRadius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.spacing),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(AppConstants.primaryColorValue)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.business,
                              color: Color(AppConstants.primaryColorValue),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  clockStatus?.workCenterName?.isNotEmpty ==
                                          true
                                      ? clockStatus!.workCenterName!
                                      : widget.workCenter.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  clockStatus?.workCenterCode ??
                                      widget.workCenter.code,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.spacing),

                  // Usuario
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.cardBorderRadius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.spacing),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(AppConstants.successColorValue)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Color(AppConstants.successColorValue),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.user.name} ${widget.user.familyName1 ?? ''} ${widget.user.familyName2 ?? ''}'
                                      .trim(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                FutureBuilder<String>(
                                  future: _getCurrentTimeSlot(),
                                  builder: (context, snapshot) {
                                    final timeSlot = snapshot.data ?? 'Cargando...';
                                    return Text(
                                      'Tramo actual: $timeSlot',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.spacing * 1.5),

                  // Clock Status Section
                  isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : clockStatus != null
                          ? Column(
                              children: [
                                // Status Card
                                Card(
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppConstants.cardBorderRadius),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                        AppConstants.spacing * 1.5),
                                    child: Column(
                                      children: [
                                        Text(
                                          I18n.of('clock.status_title'),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusBackgroundColor(
                                                clockStatus
                                                    ?.todayStats.currentStatus),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            (ClockMessages.getMessage(
                                                        clockStatus?.statusCode,
                                                        fallbackMessage:
                                                            clockStatus?.message)
                                                    .isEmpty
                                                ? (clockStatus?.todayStats
                                                        .currentStatus ??
                                                    'DESCONOCIDO')
                                                : ClockMessages.getMessage(
                                                    clockStatus?.statusCode,
                                                    fallbackMessage:
                                                        clockStatus?.message))
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildStatItem(
                                              'clock.records',
                                              (clockStatus!.todayRecords.length)
                                                  .toString(),
                                              Icons.list,
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        HistoryScreen(user: widget.user),
                                                  ),
                                                );
                                              },
                                            ),
                                            _buildStatItem(
                                              'clock.hours',
                                              _calculatedWorkedHours ??
                                                  clockStatus!
                                                      .todayStats.workedHours ??
                                                  '0:00',
                                              Icons.access_time,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                    height: AppConstants.spacing * 2),
                                // Clock Button(s)
                                Builder(
                                  builder: (context) {
                                    final status =
                                        clockStatus!.todayStats.currentStatus;
                                    if (status == 'INICIAR JORNADA' ||
                                        status ==
                                            'INICIAR REGISTRO EXCEPCIONAL') {
                                      // Override exceptional status if we are locally within schedule
                                      final isExceptional = status ==
                                              'INICIAR REGISTRO EXCEPCIONAL' &&
                                          !_isLocallyWithinSchedule;
                                      return SizedBox(
                                        width: double.infinity,
                                        height: AppConstants.buttonHeight * 1.2,
                                        child: ElevatedButton(
                                          onPressed: (isPerformingClock)
                                              ? null
                                              : () async {
                                                  if (_nfcEnabled &&
                                                      _nfcAvailable) {
                                                    await _performClockWithNFC(
                                                        action: isExceptional
                                                            ? 'exceptional_clock_in'
                                                            : 'clock_in');
                                                  } else {
                                                    await _performClockWithAction(
                                                        isExceptional
                                                            ? 'exceptional_clock_in'
                                                            : 'clock_in');
                                                  }
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isExceptional
                                                ? Colors.orange
                                                : Theme.of(context)
                                                    .primaryColor,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: isPerformingClock
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.play_arrow,
                                                        size: 24),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      isExceptional
                                                          ? I18n.of(
                                                              'clock.exceptional_start')
                                                          : I18n.of(
                                                              'clock.start_workday'),
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      );
                                    } else if (status == 'TRABAJANDO') {
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: isPerformingClock
                                                  ? null
                                                  : () =>
                                                      _performClockWithAction(
                                                          'pause'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                    AppConstants
                                                        .warningColorValue),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                elevation: 6,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 16),
                                              ),
                                              child: isPerformingClock
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.pause,
                                                            size: 20),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          I18n.of(
                                                              'clock.pause'),
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: isPerformingClock
                                                  ? null
                                                  : () {
                                                      if (_nfcEnabled) {
                                                        _performClockWithNFC(
                                                            action:
                                                                'clock_out');
                                                      } else {
                                                        _showClockOutDialog();
                                                      }
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                    AppConstants
                                                        .errorColorValue),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                elevation: 6,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 16),
                                              ),
                                              child: isPerformingClock
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.logout,
                                                            size: 20),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          I18n.of(
                                                              'clock.clock_out'),
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ],
                                      );
                                    } else if (status == 'EN PAUSA') {
                                      return SizedBox(
                                        width: double.infinity,
                                        height: AppConstants.buttonHeight * 1.2,
                                        child: ElevatedButton(
                                          onPressed: (isPerformingClock ||
                                                  !clockStatus!.canClock)
                                              ? null
                                              : () => _performClockWithAction(
                                                  'resume_workday'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 6,
                                          ),
                                          child: isPerformingClock
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.play_arrow,
                                                        size: 24),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      I18n.of(
                                                          'clock.resume_workday'),
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      );
                                    } else {
                                      return SizedBox.shrink();
                                    }
                                  },
                                ),
                                SizedBox(height: AppConstants.spacing * 2),
                                // WebView Navigation
                                Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppConstants.cardBorderRadius),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                        AppConstants.spacing),
                                    child: Column(
                                      children: [
                                        Text(
                                          I18n.of('clock.more_functions'),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(
                                            height: AppConstants.spacing),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildNativeButton(
                                              icon: Icons.history,
                                              label: I18n.of(
                                                  'clock.history_title'),
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        HistoryScreen(user: widget.user),
                                                  ),
                                                );
                                              },
                                            ),
                                            _buildNativeButton(
                                              icon: Icons.schedule,
                                              label: I18n.of(
                                                  'clock.schedule_title'),
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const ScheduleScreen(),
                                                  ),
                                                );
                                              },
                                            ),

                                            _buildNativeButton(
                                              icon: Icons.person,
                                              label: I18n.of(
                                                  'clock.profile_title'),
                                              onTap: () async {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const ProfileScreen(),
                                                  ),
                                                );
                                                await _loadStatus();
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : SizedBox.shrink(),
                ], // Cierre de la lista 'children' de la Column principal
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildStatItem(String label, String value, IconData icon,
      {VoidCallback? onTap}) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(AppConstants.primaryColorValue).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(AppConstants.primaryColorValue),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            I18n.of(label),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }

    return content;
  }

  Widget _buildNativeButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 28),
          style: IconButton.styleFrom(
            backgroundColor:
                const Color(AppConstants.primaryColorValue).withOpacity(0.1),
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- MÉTODOS DE DIÁLOGO Y FEEDBACK ---

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(AppConstants.errorColorValue),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(AppConstants.successColorValue),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(I18n.of('dialog.logout_title')),
        content: Text(I18n.of('dialog.logout_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(I18n.of('dialog.cancel')),
          ),
          TextButton(
            onPressed: () async {
              await StorageService.clearSession();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppConstants.routeStart,
                  (route) => false,
                );
              }
            },
            child: Text(I18n.of('dialog.logout')),
          ),
        ],
      ),
    );
  }
}
