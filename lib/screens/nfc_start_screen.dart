import '../models/work_center.dart';
import 'package:flutter/material.dart';
import '../services/nfc_service.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';
import 'user_login_screen.dart';
import 'manual_entry_screen.dart';

class NFCStartScreen extends StatefulWidget {
  @override
  _NFCStartScreenState createState() => _NFCStartScreenState();
}

class _NFCStartScreenState extends State<NFCStartScreen> {
  bool isScanning = false;
  bool isConfiguring = false;
  String statusMessage = 'Acerca tu dispositivo a la etiqueta NFC';

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    NFCService.stopNFCSession();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    // Verificar si hay configuración guardada
    try {
      final hasConfig = await NFCService.loadSavedConfiguration();
      if (hasConfig) {
        final serverUrl = await NFCService.getCurrentServerUrl();
        if (mounted) {
          setState(() {
            statusMessage = 'Servidor configurado: ${serverUrl ?? "URL desconocida"}';
          });
        }
      }
    } catch (e) {
      print('Error cargando configuración: $e');
    }

    await _checkNFCAvailability();
  }

  Future<void> _checkNFCAvailability() async {
    try {
      final isAvailable = await NFCService.isNFCAvailable();
      if (!mounted) return;

      if (!isAvailable) {
        setState(() {
          statusMessage = 'NFC no disponible en este dispositivo';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        statusMessage = 'Error verificando NFC: $e';
      });
    }
  }

  Future<void> _startNFCScan() async {
    if (isScanning || isConfiguring) return;

    setState(() {
      isScanning = true;
      statusMessage = 'Acerca tu dispositivo a la etiqueta NFC...';
    });

    try {
      final workCenter = await NFCService.scanWorkCenter();

      if (!mounted) return;

      if (workCenter != null) {
        // Navegar a pantalla de login con código de centro
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserLoginScreen(workCenter: workCenter),
          ),
        );
      } else {
        setState(() {
          statusMessage = 'Etiqueta NFC no válida. Inténtalo de nuevo.';
          isScanning = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Error desconocido';
      
      if (e is ConfigException) {
        setState(() {
          isConfiguring = true;
          statusMessage = 'Configurando servidor automáticamente...';
        });
        
        // Mostrar progreso de configuración
        await Future.delayed(Duration(seconds: 1));
        
        if (mounted) {
          setState(() {
            isConfiguring = false;
            statusMessage = 'Error de configuración: ${e.message}';
            isScanning = false;
          });
        }
        return;
      } else if (e is NFCVerificationException) {
        errorMessage = 'Verificación NFC: ${e.message}';
      } else if (e is APIException) {
        errorMessage = 'Error de servidor: ${e.message}';
      } else if (e is NFCException) {
        errorMessage = 'Error NFC: ${e.message}';
      } else {
        errorMessage = e.toString();
      }
      
      setState(() {
        statusMessage = errorMessage;
        isScanning = false;
      });
    }
  }

  Widget _buildStatusIcon() {
    if (isConfiguring) {
      return Icon(
        Icons.settings,
        size: 48,
        color: Colors.orange,
      );
    } else if (isScanning) {
      return Icon(
        Icons.nfc,
        size: 48,
        color: Color(AppConstants.primaryColorValue),
      );
    } else {
      return Icon(
        Icons.tap_and_play,
        size: 48,
        color: Colors.grey[600],
      );
    }
  }

  String _getButtonText() {
    if (isConfiguring) {
      return 'Configurando...';
    } else if (isScanning) {
      return 'Escaneando...';
    } else {
      return 'Escanear NFC';
    }
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
              Color(AppConstants.primaryColorValue),
              Color(AppConstants.primaryColorValue).withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacing * 1.5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Icon(
                  Icons.nfc,
                  size: 100,
                  color: Colors.white,
                ),

                const SizedBox(height: AppConstants.spacing * 1.5),

                Text(
                  AppConstants.appName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Sistema de Control de Tiempo y Horarios',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppConstants.spacing * 3),

                // NFC Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacing * 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppConstants.cardBorderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildStatusIcon(),
                      const SizedBox(height: AppConstants.spacing),
                      Text(
                        statusMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppConstants.spacing * 1.5),
                      SizedBox(
                        width: double.infinity,
                        height: AppConstants.buttonHeight,
                        child: ElevatedButton(
                          onPressed: (isScanning || isConfiguring) ? null : _startNFCScan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Color(AppConstants.primaryColorValue),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: (isScanning || isConfiguring)
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _getButtonText(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppConstants.spacing * 2),

                // Manual entry option
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManualEntryScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Introducir código manualmente',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.spacing),

                // Configuration status
                FutureBuilder<String?>(
                  future: NFCService.getCurrentServerUrl(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Servidor: ${snapshot.data}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
