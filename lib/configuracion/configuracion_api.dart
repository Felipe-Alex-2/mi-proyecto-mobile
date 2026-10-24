import 'package:flutter/foundation.dart';

class ConfiguracionApi {
  // Backend en la nube (Railway)
  static const String _productionUrl = 'https://web-production-a23ec2.up.railway.app/api/v1';

  // Backend local (PC / Web / Windows desktop)
  static const String _localUrl = 'http://localhost:8000/api/v1';

  // Backend local para emulador de Android (10.0.2.2 apunta al localhost de la PC)
  static const String _androidEmulatorUrl = 'http://10.0.2.2:8000/api/v1';

  // Activa backend local por defecto para desarrollo.
  static const bool useLocal = true;

  static String get baseUrl {
    // Permite pasar URL por línea de comandos: flutter run --dart-define=API_URL=http://...
    const customUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (customUrl.isNotEmpty) return customUrl;

    if (!useLocal) return _productionUrl;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _androidEmulatorUrl;
    }
    return _localUrl;
  }
}
