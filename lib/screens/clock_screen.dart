import '../services/storage_service.dart';
import '../i18n/i18n_service.dart';
import 'package:flutter/material.dart';
import '../models/work_center.dart';
import '../models/user.dart';
import '../models/clock_status.dart';
import '../services/clock_service.dart';
import '../services/webview_service.dart';
import '../services/nfc_service.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import '../utils/constants.dart';

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

class _ClockScreenState extends State<ClockScreen> {
    // --- DIÁLOGOS DE CONFIRMACIÓN ---
    void _showExceptionalClockInDialog() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fichaje excepcional'),
          content: const Text('Estás fuera de tu horario laboral. ¿Confirmas el fichaje excepcional?'),
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
                if (_nfcEnabled) {
                  await _performClockWithNFC(action: 'clock_out');
                } else {
                  await _performClockWithAction('clock_out');
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
    }
  ClockStatus? clockStatus;
  bool isLoading = false;
  bool isPerformingClock = false;
  bool _nfcEnabled = true;

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
  void initState() {
    super.initState();
    _loadStatus();
    _loadNFCEnabled();
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

  Future<void> _performClockWithAction(String action) async {
    if (isPerformingClock) return;

    setState(() => isPerformingClock = true);
    try {
      final userCode = await _getEffectiveUserCode();
      final workCenterCode = await _getEffectiveWorkCenterCode();

      if (userCode.isEmpty) {
        if (mounted) _showError(I18n.of('clock.no_user'));
        return;
      }

      if (action == 'resume_workday') {
        final pauseEventId = clockStatus?.pauseEventId;
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
      } else if (action == 'clock_in') {
        final eventTypeId = clockStatus?.eventTypeId;
        if (eventTypeId == null) {
          if (mounted) {
            _showError('No se puede fichar entrada: falta el tipo de evento.');
          }
          return;
        }
        await ClockService.performClock(
          workCenterCode: workCenterCode,
          userCode: userCode,
          action: action,
          eventTypeId: eventTypeId,
        );
      } else {
        await ClockService.performClock(
          workCenterCode: workCenterCode,
          userCode: userCode,
          action: action,
        );
      }

      if (mounted) {
        print('[ClockScreen][_performClockWithAction] SUCCESS');
        String actionText = action == 'pause'
            ? I18n.of('clock.pause')
            : I18n.of('clock.clock_out');
        _showSuccess(I18n.of('clock.fichaje_success', {'action': actionText}));
        // Forzar recarga de estado para actualizar contadores
        await _loadStatus();
      }
    } catch (e, stack) {
      if (mounted) {
        print(
            '[ClockScreen][_performClockWithAction] ERROR: ${e.toString()} | ${stack.toString().split('\n')[0]}');
        _showError(I18n.of('clock.fichaje_error', {'error': e.toString()}));
      }
    } finally {
      if (mounted) {
        setState(() => isPerformingClock = false);
      }
    }
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
      // Solicitar NFC
      _showSuccess('Acerque el lector a la tarjeta');
      final nfcWorkCenter = await NFCService.scanWorkCenter();
      if (nfcWorkCenter == null || nfcWorkCenter.code != workCenterCode) {
        if (mounted) _showError(I18n.of('clock.nfc_invalid'));
        return;
      }
      await _ensureScheduleLoaded(userCode);
      await ClockService.performClock(
        workCenterCode: workCenterCode,
        userCode: userCode,
        action: action,
      );
      if (mounted) {
        print('[ClockScreen][_performClockWithNFC] SUCCESS');
        String actionText = (action == 'clock_in')
            ? I18n.of('clock.clock_in')
            : I18n.of('clock.clock_out');
        _showSuccess(I18n.of('clock.fichaje_success', {'action': actionText}));
        await _loadStatus();
      }
    } catch (e, stack) {
      if (mounted) {
        print(
            '[ClockScreen][_performClockWithNFC] ERROR: ${e.toString()} | ${stack.toString().split('\n')[0]}');
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
            tooltip: I18n.of('clock.open_web'),
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              await WebViewService.openAuthenticatedWebView(
                context: context,
                workCenter: widget.workCenter,
                user: widget.user,
                path: AppConstants.webViewHome,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _loadStatus,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
              if (result == true) {
                await _loadStatus();
              }
            },
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
                                        status == 'INICIAR REGISTRO EXCEPCIONAL') {
                                      final isExceptional = status == 'INICIAR REGISTRO EXCEPCIONAL';
                                      return SizedBox(
                                        width: double.infinity,
                                        height: AppConstants.buttonHeight * 1.2,
                                        child: ElevatedButton(
                                          onPressed: (isPerformingClock ||
                                                  (status != 'INICIAR REGISTRO EXCEPCIONAL' && !clockStatus!.canClock))
                                              ? null
                                              : () {
                                                  if (status == 'INICIAR REGISTRO EXCEPCIONAL') {
                                                    _showExceptionalClockInDialog();
                                                  } else {
                                                    if (_nfcEnabled) {
                                                      _performClockWithNFC(action: 'clock_in');
                                                    } else {
                                                      _performClockWithAction('clock_in');
                                                    }
                                                  }
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isExceptional
                                                ? const Color(AppConstants.warningColorValue)
                                                : const Color(AppConstants.successColorValue),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            elevation: 6,
                                          ),
                                          child: isPerformingClock
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.login, size: 24),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      status ?? '',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      );
                                    }
                                    if (status == 'TRABAJANDO') {
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: isPerformingClock
                                                  ? null
                                                  : () => _performClockWithAction('pause'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(AppConstants.warningColorValue),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 6,
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                              ),
                                              child: isPerformingClock
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.pause, size: 20),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          I18n.of('clock.pause'),
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
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
                                                  : () => _showClockOutDialog(),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(AppConstants.errorColorValue),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 6,
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                              ),
                                              child: isPerformingClock
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.logout, size: 20),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          I18n.of('clock.clock_out'),
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    if (status == 'EN PAUSA') {
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
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                                const SizedBox(
                                    height: AppConstants.spacing * 2),
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
                          : const SizedBox.shrink(),
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
          onPressed: () {
            WebViewService.openAuthenticatedWebView(
              context: context,
              workCenter: path == AppConstants.webViewHistory
                  ? null
                  : widget.workCenter,
              user: widget.user,
              path: path,
            );
          },
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
