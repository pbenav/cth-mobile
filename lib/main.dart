import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/storage_service.dart';
import 'screens/nfc_start_screen.dart';
import 'screens/clock_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_server_screen.dart';
import 'screens/setup_worker_screen.dart';
import 'services/setup_service.dart';
import 'services/refresh_service.dart';
import 'models/work_center.dart';
import 'models/user.dart';
import 'utils/constants.dart';
import 'i18n/i18n_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar servicios
  await StorageService.init();
  // Inicializar i18n (por defecto 'es')
  await I18n.init('es');
  
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
  // Iniciar refresco periódico en background (foreground while app runs)
  RefreshService.startPeriodicRefresh();
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
      home: SplashScreen(), // Usar SplashScreen como home
      routes: {
        AppConstants.routeStart: (context) => SplashScreen(),
        AppConstants.routeLogin: (context) => NFCStartScreen(),
        AppConstants.routeClock: (context) {
          // Esta ruta debería usarse solo cuando ya hay sesión válida
          // En caso contrario, redirigir al inicio
          return FutureBuilder<bool>(
            future: StorageService.hasValidSession(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.data == true) {
                return FutureBuilder(
                  future: Future.wait([
                    StorageService.getWorkCenter(),
                    StorageService.getUser(),
                  ]),
                  builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }
                    final workCenter = snapshot.data?[0] as WorkCenter?;
                    final user = snapshot.data?[1] as User?;
                    if (workCenter != null && user != null) {
                      return ClockScreen(
                        workCenter: workCenter,
                        user: user,
                      );
                    }
                    return NFCStartScreen();
                  },
                );
              }
              return NFCStartScreen();
            },
          );
        },
        AppConstants.routeProfile: (context) => const ProfileScreen(),
        AppConstants.routeSettings: (context) => const SettingsScreen(),
        // Nuevas rutas para el asistente de configuración
        'setup_server': (context) => const SetupServerScreen(),
        'setup_worker': (context) => const SetupWorkerScreen(),
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
      print('DEBUG: Verificando configuración inicial...');
      final isSetupCompleted = await SetupService.isSetupCompleted();

      if (!isSetupCompleted) {
        print('DEBUG: Configuración no completada, iniciando asistente...');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const SetupServerScreen(),
            ),
          );
        }
        return;
      }

      print('DEBUG: Configuración completada, verificando sesión...');
      final hasSession = await StorageService.hasValidSession();
      print('DEBUG: HasValidSession: $hasSession');

      if (!mounted) return;

      if (hasSession == true) {
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
