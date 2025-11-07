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
    SystemUiOverlayStyle(
      statusBarColor: Color(AppConstants.primaryColorValue),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(CTHMobileApp());
}

class CTHMobileApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: MaterialColor(
          AppConstants.primaryColorValue,
          <int, Color>{
            50: Color(AppConstants.primaryColorValue).withOpacity(0.1),
            100: Color(AppConstants.primaryColorValue).withOpacity(0.2),
            200: Color(AppConstants.primaryColorValue).withOpacity(0.3),
            300: Color(AppConstants.primaryColorValue).withOpacity(0.4),
            400: Color(AppConstants.primaryColorValue).withOpacity(0.5),
            500: Color(AppConstants.primaryColorValue),
            600: Color(AppConstants.primaryColorValue).withOpacity(0.7),
            700: Color(AppConstants.primaryColorValue).withOpacity(0.8),
            800: Color(AppConstants.primaryColorValue).withOpacity(0.9),
            900: Color(AppConstants.primaryColorValue),
          },
        ),
        primaryColor: Color(AppConstants.primaryColorValue),
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
      final hasSession = await StorageService.hasValidSession();
      
      if (!mounted) return;
      
      if (hasSession) {
        final workCenter = await StorageService.getWorkCenter();
        final user = await StorageService.getUser();
        
        if (workCenter != null && user != null) {
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
        }
      }
      
      Navigator.pushReplacementNamed(context, AppConstants.routeLogin);
      
    } catch (e) {
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
              Color(AppConstants.primaryColorValue),
              Color(AppConstants.primaryColorValue).withOpacity(0.8),
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
                  child: Icon(
                    Icons.access_time,
                    size: 60,
                    color: Color(AppConstants.primaryColorValue),
                  ),
                ),
                const SizedBox(height: 32),
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
                const SizedBox(height: 48),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
