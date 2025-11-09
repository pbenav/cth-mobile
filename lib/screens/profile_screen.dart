import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/work_center.dart';
import '../services/storage_service.dart';
import '../services/refresh_service.dart';
import '../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _familyName1Controller = TextEditingController();
  final TextEditingController _familyName2Controller = TextEditingController();
  final TextEditingController _userCodeController = TextEditingController();
  final TextEditingController _workCenterCodeController = TextEditingController();
  final TextEditingController _workCenterNameController = TextEditingController();

  User? _currentUser;
  WorkCenter? _currentWorkCenter;
  bool _isLoading = true;
  bool _isSaving = false;
  DateTime? _lastUpdate;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _familyName1Controller.dispose();
    _familyName2Controller.dispose();
    _userCodeController.dispose();
    _workCenterCodeController.dispose();
    _workCenterNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    try {
      _currentUser = await StorageService.getUser();
      _currentWorkCenter = await StorageService.getWorkCenter();
      _lastUpdate = await StorageService.getWorkerLastUpdate();

      if (_currentUser != null) {
        _nameController.text = _currentUser!.name;
        _familyName1Controller.text = _currentUser!.familyName1 ?? '';
        _familyName2Controller.text = _currentUser!.familyName2 ?? '';
        _userCodeController.text = _currentUser!.code;
      }

      if (_currentWorkCenter != null) {
        _workCenterCodeController.text = _currentWorkCenter!.code;
        _workCenterNameController.text = _currentWorkCenter!.name;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando perfil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Crear objetos actualizados
      final updatedUser = User(
        id: _currentUser?.id ?? 0,
        code: _userCodeController.text.trim(),
        name: _nameController.text.trim(),
        familyName1: _familyName1Controller.text.trim().isNotEmpty
            ? _familyName1Controller.text.trim()
            : null,
        familyName2: _familyName2Controller.text.trim().isNotEmpty
            ? _familyName2Controller.text.trim()
            : null,
      );

      final updatedWorkCenter = WorkCenter(
        id: _currentWorkCenter?.id ?? 0,
        code: _workCenterCodeController.text.trim(),
        name: _workCenterNameController.text.trim(),
      );

      // Guardar en almacenamiento local
      await StorageService.saveUser(updatedUser);
      await StorageService.saveWorkCenter(updatedWorkCenter);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando perfil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Nunca';
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2,'0')}-${local.day.toString().padLeft(2,'0')} ${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}';
  }

  Future<void> _forceRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      final success = await RefreshService.forceRefresh(timeout: const Duration(seconds: 5));
      _lastUpdate = await StorageService.getWorkerLastUpdate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Actualización completada' : 'No se actualizaron los datos')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al forzar actualización: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información Personal
              const Text(
                'Información Personal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(AppConstants.primaryColorValue),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _familyName1Controller,
                decoration: const InputDecoration(
                  labelText: 'Primer apellido',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _familyName2Controller,
                decoration: const InputDecoration(
                  labelText: 'Segundo apellido',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _userCodeController,
                decoration: const InputDecoration(
                  labelText: 'Código de usuario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El código de usuario es obligatorio';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Última actualización y forzar refresh
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Última actualización', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(_formatDateTime(_lastUpdate)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isRefreshing ? null : _forceRefresh,
                    icon: _isRefreshing ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)) : const Icon(Icons.refresh),
                    label: Text(_isRefreshing ? 'Actualizando...' : 'Forzar actualización'),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Centro de Trabajo
              const Text(
                'Centro de Trabajo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(AppConstants.primaryColorValue),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _workCenterCodeController,
                decoration: const InputDecoration(
                  labelText: 'Código del centro',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El código del centro es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _workCenterNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del centro',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business_center),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre del centro es obligatorio';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Botón de guardar
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConstants.primaryColorValue),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Guardar Cambios',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}