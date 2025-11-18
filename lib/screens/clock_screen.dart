import '../services/storage_service.dart';
import '../i18n/i18n_service.dart';
import 'package:flutter/material.dart';
import '../models/work_center.dart';
import '../models/user.dart';
import '../models/clock_status.dart';
import '../services/clock_service.dart';
import '../services/setup_service.dart';
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
    super.key,
    required this.workCenter,
    required this.user,
    this.autoClockOnNFC = false,
  });

  @override
  _ClockScreenState createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  ClockStatus? clockStatus;
  bool isLoading = false;
  bool isPerformingClock = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
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

  /// Tries to fetch and save worker schedule if not already loaded.
  Future<void> _ensureScheduleLoaded(String userCode) async {
    final savedSchedule = await SetupService.getSavedSchedule();
    if (savedSchedule.isEmpty) {
      try {
        final fetched = await SetupService.loadWorkerData(userCode);
        if (fetched != null) {
          await SetupService.saveWorkerData(fetched);
        }
      } catch (e) {
        print('[ClockScreen] DEBUG: Could not fetch schedule from server: $e');
      }
    }
  }

  // --- LÓGICA DE ESTADO Y FICHAJE ---

  Future<void> _loadStatus() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final userCode = await _getEffectiveUserCode();
      if (userCode.isEmpty) {
        if (mounted) _showError(I18n.of('clock.no_user'));
        return;
      }

      await _ensureScheduleLoaded(userCode);

      final response = await ClockService.getStatus(userCode: userCode);

      if (mounted) {
        clockStatus = response.data;
        setState(() {});

        if (widget.autoClockOnNFC && clockStatus?.canClock == true) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _performClock();
            }
          });
        }
      }
    } catch (e, stack) {
      if (mounted) {
        print(
            '[ClockScreen][_loadStatus] ERROR: ${e.toString()} | ${stack.toString().split('\n')[0]}');
        _showError(I18n.of('clock.loading_error', {'error': e.toString()}));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _performClock() async {
    if (isPerformingClock) return;

    setState(() => isPerformingClock = true);
    try {
      final userCode = await _getEffectiveUserCode();
      final workCenterCode = await _getEffectiveWorkCenterCode();

      if (userCode.isEmpty) {
        if (mounted) _showError(I18n.of('clock.no_user'));
        return;
      }

      await _ensureScheduleLoaded(userCode);

      await ClockService.performClock(
        workCenterCode: workCenterCode,
        userCode: userCode,
      );

      if (mounted) {
        print('[ClockScreen][_performClock] SUCCESS');
        _showSuccess(I18n.of('clock.action_success'));
        await _loadStatus();
      }
    } catch (e, stack) {
      if (mounted) {
        print(
            '[ClockScreen][_performClock] ERROR: ${e.toString()} | ${stack.toString().split('\n')[0]}');
        _showError(I18n.of('clock.fichaje_error', {'error': e.toString()}));
      }
    } finally {
      if (mounted) {
        setState(() => isPerformingClock = false);
      }
    }
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

      await ClockService.performClock(
        workCenterCode: workCenterCode,
        userCode: userCode,
        action: action,
      );

      if (mounted) {
        print('[ClockScreen][_performClockWithAction] SUCCESS');
        String actionText = action == 'pause'
            ? I18n.of('clock.pause')
            : I18n.of('clock.clock_out');
        _showSuccess(I18n.of('clock.action_success', {'action': actionText}));
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
      _showSuccess(I18n.of('clock.nfc_prompt'));
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
        _showSuccess(I18n.of('clock.action_success'));
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
                                clockStatus?.workCenterName?.isNotEmpty == true
                                    ? clockStatus!.workCenterName!
                                    : widget.workCenter.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                clockStatus?.workCenterCode?.isNotEmpty == true
                                    ? clockStatus!.workCenterCode!
                                    : widget.workCenter.code,
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
                                          color: clockStatus!.todayStats
                                                      .currentStatus ==
                                                  'trabajando'
                                              ? const Color(AppConstants
                                                      .successColorValue)
                                                  .withOpacity(0.1)
                                              : const Color(AppConstants
                                                      .warningColorValue)
                                                  .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          (clockStatus!.todayStats
                                                      .currentStatus ??
                                                  'UNKNOWN')
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: clockStatus!.todayStats
                                                        .currentStatus ==
                                                    'trabajando'
                                                ? const Color(AppConstants
                                                    .successColorValue)
                                                : const Color(AppConstants
                                                    .warningColorValue),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildStatItem(
                                            'clock.entries',
                                            clockStatus!.todayStats.totalEntries
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
                              const SizedBox(height: AppConstants.spacing * 2),
                              // Clock Button(s)
                              Builder(
                                builder: (context) {
                                  if (clockStatus!.action == 'clock_in') {
                                    return SizedBox(
                                      width: double.infinity,
                                      height: AppConstants.buttonHeight * 1.2,
                                      child: ElevatedButton(
                                        onPressed: (isPerformingClock ||
                                                !clockStatus!.canClock)
                                            ? null
                                            : () => _performClockWithNFC(
                                                action: 'clock_in'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                              AppConstants.successColorValue),
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
                                                  const Icon(Icons.login,
                                                      size: 24),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    I18n.of('clock.clock_in'),
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
                                  } else if (clockStatus!.action ==
                                          'working_options' ||
                                      clockStatus!.todayStats.currentStatus ==
                                          'trabajando') {
                                    return Row(
                                      children: [
                                        SizedBox(
                                          width: MediaQuery.of(context).size.width * 0.45,
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
                                        SizedBox(
                                          width: MediaQuery.of(context).size.width * 0.45,
                                          child: ElevatedButton(
                                            onPressed: isPerformingClock
                                                ? null
                                                : () => _performClockWithAction('clock_out'),
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
                                  } else {
                                    return SizedBox(
                                      width: double.infinity,
                                      height: AppConstants.buttonHeight * 1.2,
                                      child: ElevatedButton(
                                        onPressed: (isPerformingClock ||
                                                !clockStatus!.canClock)
                                            ? null
                                            : () => _performClockWithNFC(
                                                action: 'clock_out'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                              AppConstants.errorColorValue),
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
                                                  const Icon(Icons.logout,
                                                      size: 24),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    I18n.of('clock.clock_out'),
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
                                },
                              ),
                              const SizedBox(height: AppConstants.spacing * 2),
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
                                            label:
                                                I18n.of('clock.history_title'),
                                            path: AppConstants.webViewHistory,
                                          ),
                                          _buildWebViewButton(
                                            icon: Icons.schedule,
                                            label:
                                                I18n.of('clock.schedule_title'),
                                            path: AppConstants.webViewSchedule,
                                          ),
                                          _buildWebViewButton(
                                            icon: Icons.assessment,
                                            label:
                                                I18n.of('clock.reports_title'),
                                            path: AppConstants.webViewReports,
                                          ),
                                          _buildWebViewButton(
                                            icon: Icons.person,
                                            label:
                                                I18n.of('clock.profile_title'),
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
