export 'nfc_service_mobile.dart'
    if (dart.library.js_interop) 'nfc_service_web.dart'
    if (dart.library.html) 'nfc_service_web.dart';
