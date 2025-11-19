import 'package:flutter/material.dart';
import '../i18n/i18n_service.dart';
import '../models/work_center.dart';
import '../models/user.dart';
import '../models/clock_status.dart';
import '../services/clock_service.dart';
import '../services/storage_service.dart';
import '../services/nfc_service.dart';
import '../utils/constants.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class ClockScreen extends StatefulWidget {
  final WorkCenter workCenter;
  final User user;
  final bool autoClockOnNFC;

  const ClockScreen({
    Key? key,
    required this.workCenter,
    required this.user,
    this.autoClockOnNFC = false,
  }) : super(key: key);

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

  Future<void> _loadStatus() async {
    setState(() => isLoading = true);
    try {
      final response = await ClockService.getStatus(
        userCode: widget.user.code,
      );
      setState(() {
        clockStatus = response.data;
      });
    } catch (e) {
      _showError(I18n.of('clock.loading_error', {'error': e.toString()}));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _ensureScheduleLoaded(String userCode) async {
    // Stub: Aquí se puede agregar lógica para cargar el horario si es necesario
    return;
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
      if ((action == 'clock_in' || action == 'clock_out')) {
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
        int? pauseEventId;
        const int pauseEventTypeId =
            285; // Actualiza este valor según tu backend
        if (clockStatus != null && clockStatus!.todayRecords.isNotEmpty) {
          for (final event in clockStatus!.todayRecords) {
            if (event.eventTypeId == pauseEventTypeId && _isOpenStatus(event)) {
              pauseEventId = event.id;
              break;
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
        final resp = await ClockService.performClock(
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
        String actionText = action == 'pause'
            ? I18n.of('clock.pause')
            : (action == 'resume_workday'
                ? I18n.of('clock.resume_workday')
                : (action == 'clock_in'
                    ? I18n.of('clock.clock_in')
                    : I18n.of('clock.clock_out')));
        _showSuccess(I18n.of('clock.fichaje_success', {'action': actionText}));
        await _loadStatus();
        // Si se reanuda jornada, puedes agregar aquí un log si lo necesitas
      }
    } catch (e) {
      if (mounted) {
        _showError(I18n.of('clock.fichaje_error', {'error': e.toString()}));
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
      // Para inicio de jornada (clock_in) nunca se debe enviar 'action'
      if (action == 'clock_in') {
        await ClockService.performClock(
          workCenterCode: workCenterCode,
          userCode: userCode,
          observations: _nfcEnabled
              ? 'Evento creado con comprobación/autorización NFC.'
              : 'Evento creado sin comprobación/autorización NFC.',
        );
      } else {
        await ClockService.performClock(
          workCenterCode: workCenterCode,
          userCode: userCode,
          action: action,
          observations: _nfcEnabled
              ? 'Evento creado con comprobación/autorización NFC.'
              : 'Evento creado sin comprobación/autorización NFC.',
        );
      }
      if (mounted) {
        String actionText = (action == 'clock_in')
            ? I18n.of('clock.clock_in')
            : I18n.of('clock.clock_out');
        _showSuccess(I18n.of('clock.fichaje_success', {'action': actionText}));
        await _loadStatus();
      }
    } catch (e) {
      if (mounted) {
        _showError(I18n.of('clock.fichaje_error', {'error': e.toString()}));
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
        title: Text(I18n.of('app.title')),
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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
                                Text(
                                  (clockStatus?.nextSlot != null)
                                      ? '${clockStatus!.nextSlot!.start} - ${clockStatus!.nextSlot!.end}'
                                      : 'Sin tramo horario',
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
                                            (clockStatus?.message ??
                                                    clockStatus!.todayStats
                                                        .currentStatus ??
                                                    'DESCONOCIDO')
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
                                              'clock.entries',
                                              clockStatus!
                                                  .todayStats.totalEntries
                                                  .toString(),
                                              Icons.login,
                                            ),
                                            _buildStatItem(
                                              'clock.exits',
                                              clockStatus!.todayStats.totalExits
                                                  .toString(),
                                              Icons.logout,
                                            ),
                                            _buildStatItem(
                                              'clock.hours',
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
                                      final isExceptional = status ==
                                          'INICIAR REGISTRO EXCEPCIONAL';
                                      return SizedBox(
                                        width: double.infinity,
                                        height: AppConstants.buttonHeight * 1.2,
                                        child: ElevatedButton(
                                          onPressed: (isPerformingClock)
                                              ? null
                                              : () async {
                                                  if (isExceptional) {
                                                    _showExceptionalClockInDialog();
                                                  } else {
                                                    // Lógica corregida para preferencia NFC
                                                    if (_nfcEnabled) {
                                                      if (_nfcAvailable) {
                                                        await _performClockWithNFC(
                                                            action: 'clock_in');
                                                      } else {
                                                        // NFC habilitado pero no disponible: mostrar confirmación
                                                        final confirmed =
                                                            await showDialog<
                                                                bool>(
                                                          context: context,
                                                          builder: (context) =>
                                                              AlertDialog(
                                                            title: Text(I18n.of(
                                                                'clock.clock_in')),
                                                            content: Text(
                                                                'El dispositivo no soporta NFC. ¿Confirmas el fichaje?'),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        false),
                                                                child: Text(I18n.of(
                                                                    'dialog.cancel')),
                                                              ),
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        true),
                                                                child: Text(
                                                                    'Confirmar'),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                        if (confirmed == true) {
                                                          await _performClockWithAction(
                                                              null);
                                                        }
                                                      }
                                                    } else {
                                                      // NFC deshabilitado: siempre pedir confirmación
                                                      final confirmed =
                                                          await showDialog<
                                                              bool>(
                                                        context: context,
                                                        builder: (context) =>
                                                            AlertDialog(
                                                          title: Text(I18n.of(
                                                              'clock.clock_in')),
                                                          content: Text(
                                                              '¿Seguro que quieres fichar el inicio de jornada?'),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      context,
                                                                      false),
                                                              child: Text(I18n.of(
                                                                  'dialog.cancel')),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      context,
                                                                      true),
                                                              child: Text(
                                                                  'Confirmar'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirmed == true) {
                                                        await _performClockWithAction(
                                                            null);
                                                      }
                                                    }
                                                  }
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
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
                                            _buildWebViewButton(
                                              icon: Icons.history,
                                              label: I18n.of(
                                                  'clock.history_title'),
                                              path: AppConstants.webViewHistory,
                                            ),
                                            _buildWebViewButton(
                                              icon: Icons.schedule,
                                              label: I18n.of(
                                                  'clock.schedule_title'),
                                              path:
                                                  AppConstants.webViewSchedule,
                                            ),
                                            _buildWebViewButton(
                                              icon: Icons.assessment,
                                              label: I18n.of(
                                                  'clock.reports_title'),
                                              path: AppConstants.webViewReports,
                                            ),
                                            _buildWebViewButton(
                                              icon: Icons.person,
                                              label: I18n.of(
                                                  'clock.profile_title'),
                                              path: AppConstants.webViewProfile,
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

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(AppConstants.primaryColorValue),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          I18n.of(label),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildWebViewButton({
    required IconData icon,
    required String label,
    required String path,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: () {},
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
