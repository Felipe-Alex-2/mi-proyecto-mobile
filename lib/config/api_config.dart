import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Railway live backend URL
  static const String _productionUrl = 'https://probando1-production-f535.up.railway.app/api/v1';

  static String get baseUrl {
    // Apunta al backend en la nube desplegado en Railway para que funcione en cualquier dispositivo con internet
    return _productionUrl;
  }
}

