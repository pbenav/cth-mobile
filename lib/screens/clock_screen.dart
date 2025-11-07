import 'package:flutter/material.dart';
import '../models/work_center.dart';
import '../models/user.dart';
import '../models/clock_status.dart';
import '../services/clock_service.dart';
import '../services/webview_service.dart';
import '../utils/constants.dart';

class ClockScreen extends StatefulWidget {
  final WorkCenter workCenter;
  final User user;

  const ClockScreen({
    Key? key,
    required this.workCenter,
    required this.user,
  }) : super(key: key);

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

  Future<void> _loadStatus() async {
    setState(() => isLoading = true);
    try {
      final response = await ClockService.getStatus(
        workCenterCode: widget.workCenter.code,
        userCode: widget.user.code,
      );

      if (mounted) {
        setState(() => clockStatus = response.data);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error cargando estado: ${e.toString()}');
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
      final response = await ClockService.performClock(
        workCenterCode: widget.workCenter.code,
        userCode: widget.user.code,
      );

      if (mounted) {
        _showSuccess(
            '${response.data!.action.toUpperCase()} registrada correctamente');
        await _loadStatus(); // Recargar estado
      }
    } catch (e) {
      if (mounted) {
        _showError('Error en fichaje: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => isPerformingClock = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CTH Fichaje'),
        backgroundColor: Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _loadStatus,
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
              Color(AppConstants.primaryColorValue).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacing),
            child: Column(
              children: [
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
                            color: Color(AppConstants.primaryColorValue)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
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
                                widget.workCenter.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Código: ${widget.workCenter.code}',
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

                // User Info
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
                            color: Color(AppConstants.successColorValue)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
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
                                widget.user.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'ID: ${widget.user.code}',
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
                if (isLoading) ...[
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (clockStatus != null) ...[
                  // Status Card
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.cardBorderRadius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.spacing * 1.5),
                      child: Column(
                        children: [
                          Text(
                            'Estado Actual',
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
                              color: clockStatus!.todayStats.currentStatus ==
                                      'trabajando'
                                  ? Color(AppConstants.successColorValue)
                                      .withOpacity(0.1)
                                  : Color(AppConstants.warningColorValue)
                                      .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              clockStatus!.todayStats.currentStatus
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: clockStatus!.todayStats.currentStatus ==
                                        'trabajando'
                                    ? Color(AppConstants.successColorValue)
                                    : Color(AppConstants.warningColorValue),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                'Entradas',
                                clockStatus!.todayStats.entriesCount.toString(),
                                Icons.login,
                              ),
                              _buildStatItem(
                                'Salidas',
                                clockStatus!.todayStats.exitsCount.toString(),
                                Icons.logout,
                              ),
                              _buildStatItem(
                                'Horas',
                                clockStatus!.todayStats.workedHours,
                                Icons.access_time,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.spacing * 2),

                  // Clock Button
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight * 1.2,
                    child: ElevatedButton(
                      onPressed: (isPerformingClock || !clockStatus!.canClock)
                          ? null
                          : _performClock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: clockStatus!.nextAction == 'entrada'
                            ? Color(AppConstants.successColorValue)
                            : Color(AppConstants.errorColorValue),
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
                                Icon(
                                  clockStatus!.nextAction == 'entrada'
                                      ? Icons.login
                                      : Icons.logout,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  clockStatus!.nextAction == 'entrada'
                                      ? 'FICHAR ENTRADA'
                                      : 'FICHAR SALIDA',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],

                const Spacer(),

                // WebView Navigation
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.cardBorderRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.spacing),
                    child: Column(
                      children: [
                        Text(
                          'Más funciones',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacing),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildWebViewButton(
                              icon: Icons.history,
                              label: 'Historial',
                              path: AppConstants.webViewHistory,
                            ),
                            _buildWebViewButton(
                              icon: Icons.schedule,
                              label: 'Horarios',
                              path: AppConstants.webViewSchedule,
                            ),
                            _buildWebViewButton(
                              icon: Icons.assessment,
                              label: 'Informes',
                              path: AppConstants.webViewReports,
                            ),
                            _buildWebViewButton(
                              icon: Icons.person,
                              label: 'Perfil',
                              path: AppConstants.webViewProfile,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Color(AppConstants.primaryColorValue),
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
          label,
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
          onPressed: () => WebViewService.openAuthenticatedWebView(
            context: context,
            workCenter: widget.workCenter,
            user: widget.user,
            path: path,
          ),
          icon: Icon(icon, size: 28),
          style: IconButton.styleFrom(
            backgroundColor:
                Color(AppConstants.primaryColorValue).withOpacity(0.1),
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(AppConstants.errorColorValue),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(AppConstants.successColorValue),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar la sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppConstants.routeStart,
                (route) => false,
              );
            },
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}
