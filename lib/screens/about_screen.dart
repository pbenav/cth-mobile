import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import '../i18n/i18n_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      // Direct launch without canLaunchUrl check which can fail on Android 11+
      // if queries are not perfect or for some schemes.
      await launchUrl(
        uri, 
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${I18n.of('status.ERROR')}: $e'),
            backgroundColor: const Color(AppConstants.errorColorValue),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the web URL from constants
    final String webUrl = AppConstants.webBaseUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.of('about.title')),
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.watch_later_outlined,
                  size: 100,
                  color: Color(AppConstants.primaryColorValue),
                ),
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
              // Description/Copyright Card
              Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.cardBorderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spacing),
                  child: Column(
                    children: [
                      const Text(
                        '🄯 2024 - 2026',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 40),
              // Support Section
              Text(
                I18n.of('about.support_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _launchUrl(
                    context, 'https://www.patreon.com/cw/sientia'),
                icon: const Icon(Icons.favorite, color: Colors.white),
                label: Text(I18n.of('about.support_patreon')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(220, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              // Always show "Back to Web" on mobile platforms to avoid confusion
              // even if kIsWeb check was failing or being misinterpreted.
              // But strictly kIsWeb is the correct way to hide it on web.
              if (!kIsWeb) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _launchUrl(context, webUrl),
                  icon: const Icon(Icons.web),
                  label: Text(I18n.of('about.back_to_web')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(220, 50),
                    side: const BorderSide(
                        color: Color(AppConstants.primaryColorValue)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 60),
              // Build info
              Text(
                'Build: ${AppConstants.buildDate}',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
