import 'dart:async';
import 'setup_service.dart';
import 'storage_service.dart';

class RefreshService {
  static Timer? _timer;

  /// Inicia un refresco periódico en foreground. Si ya está iniciado, no hace nada.
  static void startPeriodicRefresh({Duration interval = const Duration(minutes: 15)}) {
    if (_timer != null) return;

    // Lanzar un refresh inicial no bloqueante
    SetupService.refreshSavedWorkerData();

    _timer = Timer.periodic(interval, (_) {
      SetupService.refreshSavedWorkerData();
    });
  }

  static void stopPeriodicRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  /// Forzar un refresh bloqueante con timeout.
  /// Devuelve true si la fecha de última actualización cambió.
  static Future<bool> forceRefresh({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final before = await StorageService.getWorkerLastUpdate();

      await SetupService.refreshSavedWorkerData(blocking: true, timeout: timeout);

      final after = await StorageService.getWorkerLastUpdate();

      if (after == null) return false;
      if (before == null) return true;
      return after.isAfter(before);
    } catch (e) {
      return false;
    }
  }
}
