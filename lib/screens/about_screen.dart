import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../i18n/i18n_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.of('about.title')),
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacing * 1.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // App Logo
              Image.asset(
                'assets/images/cth-logo.png',
                height: 100,
                width: 100,
              ),
              const SizedBox(height: 20),
              // App Name & Version
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(AppConstants.primaryColorValue),
                ),
              ),
              Text(
                '${I18n.of('about.version')}: ${AppConstants.appVersion}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              // Description/Copyright
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spacing),
                  child: Column(
                    children: [
                      const Text(
                        '🄯 2024 - 2025',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        I18n.of('about.developed_by'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Text(
                        'Sientia::Soluciones Informáticas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(AppConstants.primaryColorValue),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        I18n.of('about.tech_ai'),
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Patreon Support
              const Text(
                '¿Te gusta la aplicación?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _launchUrl('https://www.patreon.com/cw/CTH_ControlHorario'),
                icon: const Icon(Icons.favorite, color: Colors.white),
                label: Text(I18n.of('about.support_patreon')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Back to Web Button
              OutlinedButton.icon(
                onPressed: () => _launchUrl('https://cth.pbenav.com'), // Assuming this is the web URL or use a constant
                icon: const Icon(Icons.web),
                label: const Text('Ir a la Web'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 50),
              // Build info
              Text(
                'Build Date: ${AppConstants.buildDate}',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
