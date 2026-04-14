import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/setup_service.dart';
import '../services/auth_service.dart';
import '../models/worker_data.dart';
import 'clock_screen.dart';

class SetupWorkerScreen extends StatefulWidget {
  const SetupWorkerScreen({super.key});

  @override
  _SetupWorkerScreenState createState() => _SetupWorkerScreenState();
}

class _SetupWorkerScreenState extends State<SetupWorkerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  WorkerData? _workerData;
  final List<String> _debugLogs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().split('.')[0];
      _debugLogs.add('[$timestamp] $message');
      // Scroll al final
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  Future<void> _loginAndLoadWorkerData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _workerData = null;
      _debugLogs.clear();
    });

    _addLog('🔄 Iniciando sesión...');

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      _addLog('📧 Email: $email');
      _addLog('⏳ Autenticando en el servidor...');

      // 1) Login y guardar token/usuario
      final user = await AuthService.login(
        email: email,
        password: password,
        deviceName: 'cth_mobile',
        onLog: _addLog,
      );

      _addLog('✅ Autenticación exitosa');
      _addLog('👤 Usuario: ${user.code} - ${user.name}');
      _addLog('⏳ Cargando datos del trabajador...');

      // 2) Cargar worker data autenticado (mismo código del usuario)
      final workerData = await SetupService.loadWorkerData(user.code);

      if (!mounted) return;

      if (workerData != null) {
        _addLog('✅ Datos del trabajador cargados');
        setState(() {
          _workerData = workerData;
        });
      } else {
        _addLog('❌ No se encontraron datos del trabajador');
        setState(() {
          _errorMessage = 'No se encontraron datos del trabajador para tu cuenta.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      _addLog('❌ Error: ${e.toString()}');
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
          builder: (context) => ClockScreen(
            workCenter: _workerData!.workCenter,
            user: _workerData!.user,
          ),
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

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El email es obligatorio';
    }
    if (!value.contains('@')) {
      return 'Email inválido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                      'Paso 2 de 2: Iniciar sesión',
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
                                'Acceso',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                'Introduce tus credenciales para autenticarte y cargar tus datos.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),

                              const SizedBox(height: AppConstants.spacing * 1.5),

                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'tu@email.com',
                                        prefixIcon: const Icon(Icons.email),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      validator: _validateEmail,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                    ),
                                    const SizedBox(height: AppConstants.spacing),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: 'Contraseña',
                                        prefixIcon: const Icon(Icons.lock),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      validator: _validatePassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _loginAndLoadWorkerData(),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: AppConstants.spacing * 1.5),

                              if (_workerData == null) ...[
                                SizedBox(
                                  width: double.infinity,
                                  height: AppConstants.buttonHeight,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _loginAndLoadWorkerData,
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
                                            'Iniciar sesión',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                                // Logs de depuración
                                if (_debugLogs.isNotEmpty) ...[
                                  const SizedBox(height: AppConstants.spacing),
                                  Container(
                                    height: 150,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[900],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[700]!),
                                    ),
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      itemCount: _debugLogs.length,
                                      itemBuilder: (context, index) {
                                        return Text(
                                          _debugLogs[index],
                                          style: const TextStyle(
                                            color: Colors.lightGreenAccent,
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
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
                                          Expanded(
                                            child: Text(
                                              'Datos cargados correctamente',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                              overflow: TextOverflow.ellipsis,
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
          // Logo positioned in top-right corner
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: Opacity(
                opacity: 0.6,
                child: Image.asset(
                  'assets/images/cth-logo.png',
                  height: 28,
                  width: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
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