import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/work_center.dart';
import '../services/storage_service.dart';
import '../services/setup_service.dart';
import '../services/profile_service.dart';
import '../models/worker_data.dart';
import '../services/refresh_service.dart';
import '../services/clock_service.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _obscureUserCode = true;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _familyName1Controller = TextEditingController();
  final TextEditingController _familyName2Controller = TextEditingController();
  final TextEditingController _userCodeController = TextEditingController();
  final TextEditingController _workCenterCodeController =
      TextEditingController();
  final TextEditingController _workCenterNameController =
      TextEditingController();

  User? _currentUser;
  WorkCenter? _currentWorkCenter;
  WorkerData? _currentWorkerData;
  List<WorkCenter> _availableWorkCenters = [];
  List<ScheduleEntry> _schedules = [];
  List<Holiday> _holidays = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSwitchingTeam = false;
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
      // Prefer loading the full saved worker data if available
      _currentWorkerData = await SetupService.getSavedWorkerData();
      _lastUpdate = await StorageService.getWorkerLastUpdate();

      if (_currentWorkerData != null) {
        _currentUser = _currentWorkerData!.user;
        _schedules = _currentWorkerData!.schedule;
        _holidays = _currentWorkerData!.holidays;
        // Use the list of all work centers from the model
        _availableWorkCenters = _currentWorkerData!.allWorkCenters;
        
        // set current work center
        // Prefer the one explicitly saved in storage (user selection) over the default in workerData
        final savedWC = await StorageService.getWorkCenter();
        if (savedWC != null) {
          _currentWorkCenter = savedWC;
        } else {
          _currentWorkCenter = _currentWorkerData!.workCenter;
        }
      } else {
        _currentUser = await StorageService.getUser();
        _currentWorkCenter = await StorageService.getWorkCenter();
      }

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
      if (e is AuthException) {
        await StorageService.clearSession();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppConstants.routeLogin,
            (route) => false,
          );
        }
        return;
      }
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
      // First, update on the server
      final success = await ProfileService.updateProfile(
        userCode: _userCodeController.text.trim(),
        name: _nameController.text.trim(),
        familyName1: _familyName1Controller.text.trim().isNotEmpty
            ? _familyName1Controller.text.trim()
            : null,
        familyName2: _familyName2Controller.text.trim().isNotEmpty
            ? _familyName2Controller.text.trim()
            : null,
      );

      if (success) {
        // Also update work center locally (not sent to server)
        final updatedWorkCenter = WorkCenter(
          id: _currentWorkCenter?.id ?? 0,
          code: _workCenterCodeController.text.trim(),
          name: _workCenterNameController.text.trim(),
        );
        await StorageService.saveWorkCenter(updatedWorkCenter);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil actualizado correctamente'),
              backgroundColor: Color(AppConstants.successColorValue),
            ),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (e is AuthException) {
        await StorageService.clearSession();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppConstants.routeLogin,
            (route) => false,
          );
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando perfil: $e'),
            backgroundColor: Color(AppConstants.errorColorValue),
          ),
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
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _forceRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      // 1. Force refresh of worker data (lists of teams, etc.)
      final success = await RefreshService.forceRefresh(
          timeout: const Duration(seconds: 5));
      
      // 2. Get current status to see where the server thinks we are
      if (_currentUser != null) {
        try {
          final statusResponse = await ClockService.getStatus(userCode: _currentUser!.code);
          final status = statusResponse.data;
          
          if (status?.currentWorkCenterCode != null || status?.currentTeamName != null) {
             final workerData = await SetupService.getSavedWorkerData();
             final allCenters = workerData?.allWorkCenters ?? _availableWorkCenters;
             
             WorkCenter? targetWC;
             
             // Try to find by exact WC code
             if (status?.currentWorkCenterCode != null) {
               try {
                 targetWC = allCenters.firstWhere((wc) => wc.code == status!.currentWorkCenterCode);
               } catch (_) {}
             }
             
             // If not found, try to find by Team Name
             if (targetWC == null && status?.currentTeamName != null) {
               try {
                 targetWC = allCenters.firstWhere((wc) => wc.teamName == status!.currentTeamName);
               } catch (_) {}
             }
             
             // If we found a target and it's different, switch
             if (targetWC != null && targetWC.code != _currentWorkCenter?.code) {
               await StorageService.saveWorkCenter(targetWC);
               _currentWorkCenter = targetWC;
               
               if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(
                     content: Text('Sincronizado con servidor: ${targetWC.teamName}'),
                     backgroundColor: Colors.blue,
                   ),
                 );
               }
             }
          }
        } catch (e) {
          print('Error getting status during refresh: $e');
        }
      }

      _lastUpdate = await StorageService.getWorkerLastUpdate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(success
                  ? 'Sincronizaci?n completada'
                  : 'No se actualizaron los datos')),
        );
        // Reload the profile data to reflect any changes from the refresh
        await _loadProfileData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al forzar actualizaci?n: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Color _getHolidayTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'national':
        return Colors.red[700]!;
      case 'regional':
        return Colors.orange[700]!;
      case 'company':
        return Colors.blue[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
          backgroundColor: const Color(AppConstants.primaryColorValue),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
            const Text('Perfil'),
          ],
        ),
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
        // Save button temporarily disabled - backend API not yet implemented
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.save),
        //     onPressed: _isSaving ? null : _saveProfile,
        //   ),
        // ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informaci?n Personal
              const Text(
                'Informaci?n Personal',
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
                  obscureText: _obscureUserCode,
                  decoration: InputDecoration(
                    labelText: 'C?digo de usuario',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.badge),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureUserCode ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() => _obscureUserCode = !_obscureUserCode);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El c?digo de usuario es obligatorio';
                    }
                    return null;
                  },
                ),

              const SizedBox(height: 32),

              // ÿÿltima actualizaci?n y forzar refresh
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ÿÿltima actualizaci?n',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(_formatDateTime(_lastUpdate)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isRefreshing ? null : _forceRefresh,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
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

              // Equipo Dropdown
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _currentWorkCenter?.teamName,
                items: _availableWorkCenters
                    .map((wc) => wc.teamName)
                    .where((name) => name != null)
                    .toSet() // Unique
                    .map((name) => DropdownMenuItem(
                      value: name,
                      child: Text(name!, overflow: TextOverflow.ellipsis),
                    ))
                    .toList(),
                onChanged: _isSwitchingTeam ? null : (String? newTeamName) async {
                   if (newTeamName == null || newTeamName == _currentWorkCenter?.teamName) return;
                   
                   // Find first WC for this team to switch to immediately
                   final newWC = _availableWorkCenters.firstWhere(
                     (wc) => wc.teamName == newTeamName,
                     orElse: () => _availableWorkCenters.first
                   );
                   
                   setState(() => _isSwitchingTeam = true);
                  
                   try {
                    await ProfileService.switchTeam(
                      userCode: _currentUser!.code,
                      workCenterCode: newWC.code,
                    );
                    
                    setState(() {
                      _currentWorkCenter = newWC;
                    });
                    
                    await StorageService.saveWorkCenter(newWC);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Equipo cambiado correctamente'),
                          backgroundColor: Color(AppConstants.successColorValue),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al cambiar equipo: $e'),
                          backgroundColor: const Color(AppConstants.errorColorValue),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isSwitchingTeam = false);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Equipo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                  filled: true,
                  fillColor: Color(0xFFF5F5F5),
                ),
              ),
              const SizedBox(height: 16),

              // Centro de Trabajo Dropdown
              DropdownButtonFormField<WorkCenter>(
                isExpanded: true,
                value: _availableWorkCenters.any((wc) => wc.code == _currentWorkCenter?.code) 
                    ? _availableWorkCenters.firstWhere((wc) => wc.code == _currentWorkCenter?.code) 
                    : null,
                items: _availableWorkCenters
                    .where((wc) => wc.teamName == _currentWorkCenter?.teamName)
                    .map((wc) {
                      return DropdownMenuItem(
                        value: wc,
                        child: Text('${wc.name} (${wc.code})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                onChanged: _isSwitchingTeam ? null : (WorkCenter? newWorkCenter) async {
                  if (newWorkCenter == null || newWorkCenter.code == _currentWorkCenter?.code) return;
                  
                  setState(() => _isSwitchingTeam = true);
                  
                  try {
                    await ProfileService.switchTeam(
                      userCode: _currentUser!.code,
                      workCenterCode: newWorkCenter.code,
                    );
                    
                    setState(() {
                      _currentWorkCenter = newWorkCenter;
                    });
                    
                    await StorageService.saveWorkCenter(newWorkCenter);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Centro de trabajo cambiado correctamente'),
                          backgroundColor: Color(AppConstants.successColorValue),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al cambiar centro: $e'),
                          backgroundColor: const Color(AppConstants.errorColorValue),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isSwitchingTeam = false);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Centro de Trabajo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                  filled: true,
                  fillColor: Color(0xFFF5F5F5),
                ),
              ),

              const SizedBox(height: 32),

              const SizedBox(height: 16),
              
              const SizedBox(height: 16),

              // Horarios (read-only)
              const Text(
                'Horarios recibidos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(AppConstants.primaryColorValue),
                ),
              ),
              const SizedBox(height: 12),
              if (_schedules.isEmpty)
                const Text('No hay horarios guardados')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _schedules.length,
                  itemBuilder: (context, index) {
                    final s = _schedules[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text('${s.startTime} - ${s.endTime}'),
                        subtitle: Text(
                            s.dayOfWeek.isNotEmpty ? s.dayOfWeek : s.dayName),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // Festivos (read-only)
              const Text(
                'Festivos recibidos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(AppConstants.primaryColorValue),
                ),
              ),
              const SizedBox(height: 12),
              if (_holidays.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey),
                      SizedBox(width: 12),
                      Text(
                        'No hay festivos guardados',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(AppConstants.primaryColorValue).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: _holidays.length,
                    physics: const BouncingScrollPhysics(),
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final h = _holidays[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(AppConstants.primaryColorValue).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Color(AppConstants.primaryColorValue),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.name.isNotEmpty ? h.name : 'Festivo',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    h.date,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getHolidayTypeColor(h.type),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                h.typeName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 32),

              // Info message - editing temporarily disabled
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'La edici?n del perfil estar? disponible pr?ximamente',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Save button temporarily disabled - backend API not yet implemented
              // SizedBox(
              //   width: double.infinity,
              //   height: AppConstants.buttonHeight,
              //   child: ElevatedButton(
              //     onPressed: _isSaving ? null : _saveProfile,
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor:
              //           const Color(AppConstants.primaryColorValue),
              //       foregroundColor: Colors.white,
              //       shape: RoundedRectangleBorder(
              //         borderRadius:
              //             BorderRadius.circular(AppConstants.cardBorderRadius),
              //       ),
              //     ),
              //     child: _isSaving
              //         ? const CircularProgressIndicator(color: Colors.white)
              //         : const Text(
              //             'Guardar Cambios',
              //             style: TextStyle(
              //                 fontSize: 16, fontWeight: FontWeight.bold),
              //           ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
