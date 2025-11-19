import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isSaving = false;
  String? _error;
  List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _nfcEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
    _loadNFCEnabled();
  }

  Future<void> _loadNFCEnabled() async {
    final enabled = await StorageService.getBool('nfc_enabled');
    setState(() {
      _nfcEnabled = enabled ?? true;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await ConfigService.getCurrentServerUrl();
    setState(() {
      _urlController.text = url ?? '';
    });
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().split('.').first}] $message');
    });
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveUrl() async {
    setState(() {
      _isSaving = true;
      _error = null;
      _logs.clear();
    });

    _addLog('Iniciando configuración del servidor...');
    await StorageService.setBool('nfc_enabled', _nfcEnabled);

    try {
      final success = await ConfigService.configureServer(_urlController.text, onLog: _addLog);
      if (success) {
        _addLog('✅ Configuración completada exitosamente');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _addLog('❌ Error: ${e.toString()}');
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de servidor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL del servidor',
                hintText: 'Ej: https://mi-servidor.com o https://mi-servidor.com/api/v1',
                helperText: 'Introduce solo el dominio base o hasta /api/v1. La app añadirá automáticamente /mobile para las operaciones.',
                errorText: _error,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fichaje por NFC', style: TextStyle(fontSize: 16)),
                Switch(
                  value: _nfcEnabled,
                  onChanged: (value) {
                    setState(() {
                      _nfcEnabled = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveUrl,
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : const Text('Guardar'),
            ),
            const SizedBox(height: 24),
            if (_logs.isNotEmpty) ...[
              const Text(
                'Logs de configuración:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _logs[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
