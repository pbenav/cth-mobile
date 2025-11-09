import 'package:flutter/material.dart';
import '../models/work_center.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import 'clock_screen.dart';

class UserLoginScreen extends StatefulWidget {
  final WorkCenter workCenter;
  final bool autoClockAfterLogin;
  final String? initialUserCode;
  final String? initialUserName;

  const UserLoginScreen({
    super.key,
    required this.workCenter,
    this.autoClockAfterLogin = false,
    this.initialUserCode,
    this.initialUserName,
  });

  @override
  _UserLoginScreenState createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _prefillFromWidgetOrStorage();
  }

  Future<void> _prefillFromWidgetOrStorage() async {
    // If initial values were provided by the caller (e.g. NFC flow), use them
    if (widget.initialUserCode != null && widget.initialUserCode!.isNotEmpty) {
      _codeController.text = widget.initialUserCode!;
    }
    if (widget.initialUserName != null && widget.initialUserName!.isNotEmpty) {
      _nameController.text = widget.initialUserName!;
    }

    // If still empty, try to load saved user from preferences
    if ((_codeController.text.trim().isEmpty) || (_nameController.text.trim().isEmpty)) {
      try {
        final savedUser = await StorageService.getUser();
        if (savedUser != null) {
          if (_codeController.text.trim().isEmpty) {
            _codeController.text = savedUser.code;
          }
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = savedUser.name;
          }
          setState(() {});
        }
      } catch (e) {
        // ignore storage errors here
      }
    }
  }

  Future<void> _submitLogin() async {
    print('DEBUG: _submitLogin called');
    print('DEBUG: _codeController.text: "${_codeController.text}"');
    print('DEBUG: _nameController.text: "${_nameController.text}"');

    if (!_formKey.currentState!.validate()) {
      print('DEBUG: Form validation failed');
      return;
    }

    print('DEBUG: Form validation passed');
    setState(() => isLoading = true);

    try {
      final userCode = _codeController.text.trim();
      final userName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : userCode;

      print('DEBUG: Guardando usuario - Code: $userCode, Name: $userName');
      print('DEBUG: WorkCenter: ${widget.workCenter.code} - ${widget.workCenter.name}');

      final user = User(
        id: 0, // ID temporal, se asignará desde el servidor
        code: userCode,
        name: userName,
      );

      // Guardar datos en almacenamiento local
      await StorageService.saveWorkCenter(widget.workCenter);
      await StorageService.saveUser(user);

      // Verificar que se guardó correctamente
      final savedWorkCenter = await StorageService.getWorkCenter();
      final savedUser = await StorageService.getUser();
      final hasSession = await StorageService.hasValidSession();

      print('DEBUG: Datos guardados - WorkCenter: ${savedWorkCenter?.code}, User: ${savedUser?.code}, HasSession: $hasSession');

      if (!mounted) return;

      // Navegar a pantalla principal
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ClockScreen(
            workCenter: widget.workCenter,
            user: user,
            autoClockOnNFC: widget.autoClockAfterLogin,
          ),
        ),
      );
    } catch (e) {
      print('DEBUG: Error guardando datos: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error guardando datos: ${e.toString()}'),
          backgroundColor: const Color(AppConstants.errorColorValue),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identificación'),
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(AppConstants.primaryColorValue),
              const Color(AppConstants.primaryColorValue).withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacing * 1.5),
            child: Column(
              children: [
                // Info del centro de trabajo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacing),
                  margin:
                      const EdgeInsets.only(bottom: AppConstants.spacing * 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppConstants.cardBorderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
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
                              'Centro de Trabajo',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.workCenter.code} - ${widget.workCenter.name}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle,
                        color: Color(AppConstants.successColorValue),
                        size: 20,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding:
                            const EdgeInsets.all(AppConstants.spacing * 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                              AppConstants.cardBorderRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    color:
                                        Color(AppConstants.primaryColorValue),
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Identificación de Usuario',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        Text(
                                          'Introduce tu código de empleado',
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

                              const SizedBox(height: AppConstants.spacing * 2),

                              // Código del usuario (obligatorio)
                              Text(
                                'Código de Empleado *',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _codeController,
                                decoration: InputDecoration(
                                  hintText: 'Ej: 1234567',
                                  prefixIcon: const Icon(Icons.badge),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color:
                                          Color(AppConstants.primaryColorValue),
                                    ),
                                  ),
                                ),
                                keyboardType: TextInputType.text,
                                textCapitalization:
                                    TextCapitalization.characters,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'El código de empleado es obligatorio';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'El código debe tener al menos 3 caracteres';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(
                                  height: AppConstants.spacing * 1.5),

                              // Nombre del usuario (opcional)
                              Text(
                                'Nombre (opcional)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  hintText: 'Ej: Juan Pérez',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color:
                                          Color(AppConstants.primaryColorValue),
                                    ),
                                  ),
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),

                              const SizedBox(height: AppConstants.spacing * 2),

                              // Botón iniciar sesión
                              SizedBox(
                                width: double.infinity,
                                height: AppConstants.buttonHeight,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _submitLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(AppConstants.primaryColorValue),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Iniciar Sesión',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: AppConstants.spacing),

                              // Información adicional
                              // ...existing code...
                            ],
                          ),
                        ),
                      ),
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
}
