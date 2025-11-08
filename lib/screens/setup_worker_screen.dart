import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/setup_service.dart';
import '../models/worker_data.dart';
import 'nfc_start_screen.dart';

class SetupWorkerScreen extends StatefulWidget {
  const SetupWorkerScreen({super.key});

  @override
  _SetupWorkerScreenState createState() => _SetupWorkerScreenState();
}

class _SetupWorkerScreenState extends State<SetupWorkerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _workerCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  WorkerData? _workerData;

  @override
  void dispose() {
    _workerCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkerData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _workerData = null;
    });

    try {
      final workerCode = _workerCodeController.text.trim();
      final workerData = await SetupService.loadWorkerData(workerCode);

      if (!mounted) return;

      if (workerData != null) {
        setState(() {
          _workerData = workerData;
        });
      } else {
        setState(() {
          _errorMessage = 'No se encontraron datos para el código proporcionado.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al cargar datos: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeSetup() async {
    if (_workerData == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await SetupService.saveWorkerData(_workerData!);

      if (!mounted) return;

      // Navegar a la pantalla principal
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const NFCStartScreen(),
        ),
        (route) => false, // Eliminar todas las rutas anteriores
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al guardar configuración: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String? _validateWorkerCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El código del trabajador es obligatorio';
    }

    if (value.trim().length < 3) {
      return 'El código debe tener al menos 3 caracteres';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(AppConstants.primaryColorValue),
              const Color(AppConstants.primaryColorValue).withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacing * 1.5),
            child: Column(
              children: [
                // Indicador de progreso
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Color(AppConstants.primaryColorValue),
                        size: 16,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '2',
                          style: TextStyle(
                            color: Color(AppConstants.primaryColorValue),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppConstants.spacing * 2),

                // Título
                const Text(
                  'Configuración Inicial',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Paso 2 de 2: Configurar trabajador',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),

                const SizedBox(height: AppConstants.spacing * 3),

                // Formulario
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.spacing * 1.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Código del Trabajador',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Introduce tu código secreto de trabajador para cargar tus datos.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),

                          const SizedBox(height: AppConstants.spacing * 1.5),

                          Form(
                            key: _formKey,
                            child: TextFormField(
                              controller: _workerCodeController,
                              decoration: InputDecoration(
                                labelText: 'Código del trabajador',
                                hintText: 'Ej: EMP001',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: _validateWorkerCode,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _loadWorkerData(),
                            ),
                          ),

                          const SizedBox(height: AppConstants.spacing * 1.5),

                          if (_workerData == null) ...[
                            SizedBox(
                              width: double.infinity,
                              height: AppConstants.buttonHeight,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _loadWorkerData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(AppConstants.primaryColorValue),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Cargar Datos',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ] else ...[
                            // Mostrar datos del trabajador
                            Container(
                              padding: const EdgeInsets.all(AppConstants.spacing),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green[600],
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Datos cargados correctamente',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppConstants.spacing),
                                  _buildDataRow('Nombre', _workerData!.user.name),
                                  _buildDataRow('Centro de trabajo', _workerData!.workCenter.name),
                                  _buildDataRow('Horario', '${_workerData!.schedule.length} tramos configurados'),
                                  if (_workerData!.holidays.isNotEmpty)
                                    _buildDataRow('Festivos', '${_workerData!.holidays.length} días configurados'),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppConstants.spacing * 1.5),

                            SizedBox(
                              width: double.infinity,
                              height: AppConstants.buttonHeight,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _completeSetup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Completar Configuración',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],

                          if (_errorMessage != null) ...[
                            const SizedBox(height: AppConstants.spacing),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red[600],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.spacing),

                // Información adicional
                Text(
                  'Estos datos se guardarán localmente para uso offline.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}