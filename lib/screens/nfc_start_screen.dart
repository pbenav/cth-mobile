import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/work_center.dart';
import '../models/user.dart';
import 'clock_screen.dart';

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
          const User(id: 0, code: 'defaultCode', name: 'Default User');
      final workCenter = const WorkCenter(id: 0, code: 'defaultCode', name: 'Default WorkCenter');

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
      body: Center(
        child: Text(
          statusMessage,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
