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


  Future<void> _loadCurrentUrl() async {
    final url = await ConfigService.getCurrentServerUrl();
    setState(() {
      _urlController.text = url ?? '';
    });
  }


  Future<void> _saveUrl() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    await StorageService.setBool('nfc_enabled', _nfcEnabled);

    try {
        final success = await ConfigService.configureServer(_urlController.text);
      if (success) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL del servidor',
                  hintText:
                      'Ej: https://mi-servidor.com o https://mi-servidor.com/api/v1',
                  helperText:
                      'Introduce solo el dominio base o hasta /api/v1. La app añadirá automáticamente /mobile para las operaciones.',
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
                    onChanged: (value) async {
                      setState(() {
                        _nfcEnabled = value;
                      });
                      await StorageService.setBool('nfc_enabled', value);
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
            ],
          ),
        ),
      ),
    );
  }
}
