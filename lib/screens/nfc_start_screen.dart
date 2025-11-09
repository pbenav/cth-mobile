import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../i18n/i18n_service.dart';
import '../services/nfc_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';
import 'user_login_screen.dart';
import 'settings_screen.dart';
import 'clock_screen.dart';
import 'profile_screen.dart';

class NFCStartScreen extends StatefulWidget {
  const NFCStartScreen({super.key});

  @override
  _NFCStartScreenState createState() => _NFCStartScreenState();
}

class _NFCStartScreenState extends State<NFCStartScreen> {
  bool isScanning = false;
  bool isConfiguring = false;
  bool debugMode = false;
  String statusMessage = I18n.of('nfc.ready');
  String? lastNFCContent;
  final TextEditingController _pasteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    NFCService.stopNFCSession();
    _pasteController.dispose();
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
              statusMessage = I18n.of('nfc.server_configured', {'server': serverUrl ?? 'URL desconocida'});
            });
        }
      }
    } catch (e) {
      print('Error cargando configuración: $e');
    }

    await _checkNFCAvailability();
    // Iniciar escaneo automáticamente al entrar en la pantalla para que
    // el mero gesto de pasar la tarjeta por el lector dispare la acción
    // sin que el usuario tenga que pulsar el botón.
    // Esto cumple el comportamiento solicitado: tocar la etiqueta -> fichar.
    try {
      // Pequeño delay para que la UI termine de renderizar
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _startNFCScan();
      }
    } catch (e) {
      print('Error iniciando escaneo NFC automático: $e');
    }
  }

  Future<void> _checkNFCAvailability() async {
    try {
      final isAvailable = await NFCService.isNFCAvailable();
      if (!mounted) return;

      if (!isAvailable) {
        setState(() {
          statusMessage = I18n.of('nfc.not_available');
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        statusMessage = I18n.of('nfc.error_checking', {'error': e.toString()});
      });
    }
  }

  void _showNFCDebugDialog(String content, Map<String, dynamic>? data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(I18n.of('nfc.debug.title')),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(I18n.of('nfc.debug.title'), style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: EdgeInsets.all(8),
                  margin: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    content,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                if (data != null) ...[
                  SizedBox(height: 16),
                  Text('Datos parseados:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: EdgeInsets.all(8),
                    margin: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      data.toString(),
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startNFCScan() async {
    if (isScanning || isConfiguring) return;

    setState(() {
      isScanning = true;
      statusMessage = 'Acerca tu dispositivo a la etiqueta NFC...';
    });

    try {
      // Use scanAndPerformClock to immediately call the clock endpoint when possible
      final result = await NFCService.scanAndPerformClock(
        onDebug: debugMode ? (content, data) => _showNFCDebugDialog(content, data) : null,
      );

      if (!mounted) return;

      if (result != null && result.containsKey('response')) {
        final resp = result['response'];
        // resp is ApiResponse<ClockResponse>
        if (resp != null && resp.success == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resp.message ?? 'Fichaje realizado correctamente')),
          );
        } else if (resp != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fichaje fallido: ${resp.message}')),
          );
        }
        // Recargar estado si estamos en pantalla de Clock (no navegamos aquí)
        setState(() {
          isScanning = false;
          statusMessage = 'Fichaje procesado';
        });
      } else {
        // Si no hay usuario guardado, intentar redirigir al login mediante el workCenter
        // Para ello, debemos obtener el workCenter por separado
        final wc = await NFCService.scanWorkCenter(onNFCDebug: debugMode ? (c, d) => _showNFCDebugDialog(c, d) : null);
        if (wc != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserLoginScreen(
                workCenter: wc,
                autoClockAfterLogin: true,
              ),
            ),
          );
        } else {
          setState(() {
            statusMessage = 'Etiqueta NFC no válida. Inténtalo de nuevo.';
            isScanning = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Error desconocido';
      
      if (e is ConfigException) {
        setState(() {
          isConfiguring = true;
          statusMessage = I18n.of('nfc.configuring');
        });
        
        // Mostrar progreso de configuración
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          setState(() {
            isConfiguring = false;
            statusMessage = I18n.of('nfc.error_checking', {'error': e.message});
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
        errorMessage = 'Error: ${e.toString()}';
      }
      
      print('💥 NFC Scan Error: $errorMessage');
      setState(() {
        statusMessage = errorMessage;
        isScanning = false;
      });
    }
  }

  Future<void> _processPastedPayload() async {
    if (isScanning || isConfiguring) return;

    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pegue primero el payload en el campo')),
      );
      return;
    }

    setState(() {
      isScanning = true;
      statusMessage = 'Procesando payload...';
    });

    try {
      final workCenter = await NFCService.processPayloadString(
        text,
        onDebug: debugMode ? (content, data) => _showNFCDebugDialog(content, data) : null,
      );

      if (!mounted) return;

      if (workCenter != null) {
        final savedUser = await StorageService.getUser();
        final savedWorkCenter = await StorageService.getWorkCenter();

        if (savedUser != null) {
          if (savedWorkCenter == null) {
            try {
              await StorageService.saveWorkCenter(workCenter);
            } catch (e) {
              print('DEBUG: No se pudo guardar WorkCenter desde payload pegado: $e');
            }
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClockScreen(
                workCenter: workCenter,
                user: savedUser,
                autoClockOnNFC: true,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserLoginScreen(
                workCenter: workCenter,
                autoClockAfterLogin: true,
              ),
            ),
          );
        }
      } else {
        setState(() {
          statusMessage = 'Payload no válido o no reconocido';
          isScanning = false;
        });
      }
    } catch (e) {
      String errorMessage = 'Error procesando payload: ${e.toString()}';
      print('💥 _processPastedPayload Error: $errorMessage');
      if (!mounted) return;
      setState(() {
        statusMessage = errorMessage;
        isScanning = false;
      });
    }
  }

  Widget _buildStatusIcon() {
    if (isConfiguring) {
      return const Icon(
        Icons.settings,
        size: 48,
        color: Colors.orange,
      );
    } else if (isScanning) {
      return const Icon(
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
              const Color(AppConstants.primaryColorValue),
              const Color(AppConstants.primaryColorValue).withOpacity(0.8),
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
                const Icon(
                  Icons.nfc,
                  size: 100,
                  color: Colors.white,
                ),

                const SizedBox(height: AppConstants.spacing * 1.5),

                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  I18n.of('app.slogan'),
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
                                const Color(AppConstants.primaryColorValue),
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
                                  style: const TextStyle(
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

                // Opción de entrada manual eliminada por decisión de producto

                const SizedBox(height: AppConstants.spacing),

                // Profile button
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                  child: Text(
                    '⚙️ Preferencias',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.spacing),

                // --- Fallback manual: pegar payload NFC (temporal) ---
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pegar payload NFC (para pruebas)',
                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pasteController,
                        maxLines: 3,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Pegue aquí el contenido NDEF o CTH:OC-001:Oficina',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste, color: Colors.white70),
                            onPressed: () async {
                              final clip = await Clipboard.getData('text/plain');
                              if (clip != null && clip.text != null) {
                                setState(() {
                                  _pasteController.text = clip.text!;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: AppConstants.buttonHeight,
                        child: ElevatedButton(
                          onPressed: (isScanning || isConfiguring)
                              ? null
                              : _processPastedPayload,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Procesar payload'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Debug mode toggle
                TextButton(
                  onPressed: () {
                    setState(() {
                      debugMode = !debugMode;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          debugMode 
                            ? 'Modo debug NFC activado - Se mostrará el contenido de las etiquetas'
                            : 'Modo debug NFC desactivado'
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text(
                    debugMode ? '🔍 Debug NFC: ON' : '🔍 Debug NFC: OFF',
                    style: TextStyle(
                      color: debugMode ? Colors.yellow : Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: debugMode ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.spacing),
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
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: AppConstants.spacing),

                // Build date
                Text(
                  'Compilado: ${AppConstants.buildDate}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
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
