import 'package:flutter/foundation.dart';
import '../models/recommendation.dart';
import 'api_service.dart';

class RecommendationService extends ChangeNotifier {
  final ApiService _api;

  RecommendationService(this._api);

  bool _isLoading = false;
  String? _errorMessage;
  RecommendationResponse? _lastResponse;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  RecommendationResponse? get lastResponse => _lastResponse;

  Future<RecommendationResponse?> getRecommendations(String message) async {
    final text = message.trim();
    if (text.isEmpty) return null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(
        '/recommendations/chat',
        body: {'message': text},
      );

      final result = RecommendationResponse.fromJson(response);
      _lastResponse = result;
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      if (_errorMessage!.isEmpty) {
        _errorMessage = 'No se pudo consultar al asistente de recomendaciones.';
      }
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  void clear() {
    _lastResponse = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
