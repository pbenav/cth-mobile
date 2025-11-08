import '../services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/work_center.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class CTHWebView extends StatefulWidget {
  final String url;
  final String title;
  final WorkCenter workCenter;
  final User user;

  const CTHWebView({
    super.key,
    required this.url,
    required this.title,
    required this.workCenter,
    required this.user,
  });

  @override
  _CTHWebViewState createState() => _CTHWebViewState();
}

class _CTHWebViewState extends State<CTHWebView> {
  late final WebViewController controller;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebViewWithCookie();
  }

  Future<String> getLaravelSessionValue() async {
  // Recupera la cookie laravel_session guardada tras el login
  return await StorageService.getLaravelSessionCookie() ?? '';
  }

  void _initializeWebViewWithCookie() async {
  final cookieManager = WebViewCookieManager();
    final laravelSessionValue = await getLaravelSessionValue();
    if (laravelSessionValue.isNotEmpty) {
      await cookieManager.setCookie(
        WebViewCookie(
          name: 'laravel_session',
          value: laravelSessionValue,
          domain: '.sientia.com',
          path: '/',
        ),
      );
    }
    _initializeWebView();
  }

  void _initializeWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                isLoading = true;
                errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => isLoading = false);
            }

            // Inyectar datos de autenticación en localStorage
            _injectAuthenticationData();
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                isLoading = false;
                errorMessage = 'Error cargando página: ${error.description}';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Permitir solo URLs de CTH
            if (request.url.contains(Uri.parse(AppConstants.webBaseUrl).host)) {
              return NavigationDecision.navigate;
            }

            // Bloquear navegación externa
            return NavigationDecision.prevent;
          },
        ),
      );

    // Cargar URL inicial
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      await controller.loadRequest(Uri.parse(widget.url));
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error cargando URL: $e';
        });
      }
    }
  }

  Future<void> _injectAuthenticationData() async {
    try {
      await controller.runJavaScript('''
        // Guardar datos en localStorage
        localStorage.setItem('cth_work_center_code', '${widget.workCenter.code}');
        localStorage.setItem('cth_work_center_name', '${widget.workCenter.name}');
        localStorage.setItem('cth_user_code', '${widget.user.code}');
        localStorage.setItem('cth_user_name', '${widget.user.name}');
        localStorage.setItem('cth_mobile_app', 'true');
        
        // Llamar función de autenticación si existe
        if (typeof window.setWorkCenter === 'function') {
          window.setWorkCenter('${widget.workCenter.code}', '${widget.workCenter.name}');
        }
        
        if (typeof window.setUser === 'function') {
          window.setUser('${widget.user.code}', '${widget.user.name}');
        }
        
        // Notificar que los datos están listos
        if (typeof window.onCTHDataReady === 'function') {
          window.onCTHDataReady();
        }
        
        // Disparar evento personalizado
        window.dispatchEvent(new CustomEvent('cthDataReady', {
          detail: {
            workCenter: {
              code: '${widget.workCenter.code}',
              name: '${widget.workCenter.name}'
            },
            user: {
              code: '${widget.user.code}',
              name: '${widget.user.name}'
            }
          }
        }));
      ''');
    } catch (e) {
      print('Error inyectando datos de autenticación: $e');
    }
  }

  Future<void> _refresh() async {
    await controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView content
          if (errorMessage == null)
            WebViewWidget(controller: controller)
          else
            _buildErrorView(),

          // Loading indicator
          if (isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(AppConstants.primaryColorValue),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cargando ${widget.title}...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing * 2),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(AppConstants.errorColorValue),
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Error desconocido',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      errorMessage = null;
                    });
                    _loadUrl();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConstants.primaryColorValue),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
