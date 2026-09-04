class ApiConfig {
  // Railway live backend URL
  static const String _productionUrl = 'https://mi-proyecto-backend-production-9c3c.up.railway.app/api/v1';

  static String get baseUrl {
    // Apunta al backend en la nube desplegado en Railway para que funcione en cualquier dispositivo con internet
    return _productionUrl;
  }
}

