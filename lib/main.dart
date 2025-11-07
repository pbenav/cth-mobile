import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/storage_service.dart';
import 'screens/nfc_start_screen.dart';
import 'screens/clock_screen.dart';
import 'screens/manual_entry_screen.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar servicios
  await StorageService.init();
  
  // Configurar orientación de pantalla
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Configurar barra de estado
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(AppConstants.primaryColorValue),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(CTHMobileApp());
}

class CTHMobileApp extends StatelessWidget {
  const CTHMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: MaterialColor(
          AppConstants.primaryColorValue,
          <int, Color>{
            50: const Color(AppConstants.primaryColorValue).withOpacity(0.1),
            100: const Color(AppConstants.primaryColorValue).withOpacity(0.2),
            200: const Color(AppConstants.primaryColorValue).withOpacity(0.3),
            300: const Color(AppConstants.primaryColorValue).withOpacity(0.4),
            400: const Color(AppConstants.primaryColorValue).withOpacity(0.5),
            500: const Color(AppConstants.primaryColorValue),
            600: const Color(AppConstants.primaryColorValue).withOpacity(0.7),
            700: const Color(AppConstants.primaryColorValue).withOpacity(0.8),
            800: const Color(AppConstants.primaryColorValue).withOpacity(0.9),
            900: const Color(AppConstants.primaryColorValue),
          },
        ),
        primaryColor: const Color(AppConstants.primaryColorValue),
        useMaterial3: true,
      ),
      initialRoute: AppConstants.routeStart,
      routes: {
        AppConstants.routeStart: (context) => SplashScreen(),
        AppConstants.routeLogin: (context) => NFCStartScreen(),
        AppConstants.routeManualEntry: (context) => ManualEntryScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => NFCStartScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }
  
  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      print('DEBUG: Verificando sesión...');
      final hasSession = await StorageService.hasValidSession();
      print('DEBUG: HasValidSession: $hasSession');

      if (!mounted) return;

      if (hasSession) {
        final workCenter = await StorageService.getWorkCenter();
        final user = await StorageService.getUser();

        print('DEBUG: Datos cargados - WorkCenter: ${workCenter?.code}, User: ${user?.code}');

        if (workCenter != null && user != null) {
          print('DEBUG: Navegando a ClockScreen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ClockScreen(
                workCenter: workCenter,
                user: user,
              ),
            ),
          );
          return;
        } else {
          print('DEBUG: WorkCenter o User son null, navegando a login');
        }
      } else {
        print('DEBUG: No hay sesión válida, navegando a login');
      }

      Navigator.pushReplacementNamed(context, AppConstants.routeLogin);

    } catch (e) {
      print('DEBUG: Error en _checkSession: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppConstants.routeLogin);
      }
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(60),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.access_time,
                    size: 60,
                    color: Color(AppConstants.primaryColorValue),
                  ),
                ),
                const SizedBox(height: 32),
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
                  'Sistema de Control de Tiempo y Horarios',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cargando...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Text(
                    'Versión ${AppConstants.appVersion}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
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
