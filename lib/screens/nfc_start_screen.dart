import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/work_center.dart';
import '../models/user.dart';
import 'clock_screen.dart';
import 'setup_worker_screen.dart';

class NFCStartScreen extends StatefulWidget {
  const NFCStartScreen({super.key});

  @override
  _NFCStartScreenState createState() => _NFCStartScreenState();
}

class _NFCStartScreenState extends State<NFCStartScreen> {
  bool isConfiguring = false;
  String statusMessage = '';
  final String serverUrl = 'https://example.com';

  @override
  void initState() {
    super.initState();
    _navigateToStatusScreen();
  }

  Future<void> _navigateToStatusScreen() async {
    try {
      final user = await StorageService.getUser() ??
          const User(id: 0, code: '', name: 'Usuario por defecto');
      final workCenter = await StorageService.getWorkCenter() ??
          const WorkCenter(
              id: 0, code: '', name: 'Centro de trabajo por defecto');

      if (!mounted) return; // Verificar si el widget sigue montado

      if (serverUrl.isNotEmpty && user.code.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClockScreen(
              workCenter: workCenter,
              user: user,
            ),
          ),
        );
      } else {
        setState(() {
          statusMessage = 'Por favor, configure el servidor y el usuario.';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SetupWorkerScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        statusMessage = 'Error al navegar: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Start'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Escanea tu tarjeta NFC'),
            ElevatedButton(
              onPressed: () {
                // Acción del botón
              },
              child: const Text('Iniciar'),
            ),
          ],
        ),
      ),
      floatingActionButton: TextButton(
        onPressed: () {
          Navigator.pushNamed(context, '/settings');
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
    );
  }
}
