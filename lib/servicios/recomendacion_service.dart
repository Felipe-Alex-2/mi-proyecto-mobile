import 'sesion_notifier.dart';

import '../modelos/recomendacion.dart';
import '../modelos/producto.dart';
import 'api_service.dart';
import 'asistente_catalogo_local.dart';
import 'carlitos_modelo_local.dart';

class RecomendacionService extends SesionNotifier {
  final ApiService _api;

  final CarlitosModeloLocal localModel = CarlitosModeloLocal();

  RecomendacionService(this._api);

  bool _isLoading = false;
  String? _errorMessage;
  RecomendacionResponse? _lastResponse;
  bool _isLocalResponse = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  RecomendacionResponse? get lastResponse => _lastResponse;
  bool get isLocalResponse => _isLocalResponse;

  Future<RecomendacionResponse> _local(String text) async {
    final offline = _api.offline;
    final owner = offline?.owner;
    final assistant = AsistenteLocalCatalogo();
    // FAQs are bundled with the app and do not depend on SQLite or a model.
    if (assistant.faq(text) != null) {
      _isLocalResponse = true;
      return assistant.respond(text, []);
    }
    final cached = await offline?.cached('/products');
    if (owner != _api.offline?.owner) {
      throw ApiException(
        'La sesión cambió. Vuelve a iniciar sesión.',
        statusCode: 401,
      );
    }
    final products = (cached as List? ?? [])
        .map(
          (item) => Producto.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    _isLocalResponse = true;
    final result = assistant.respond(text, products);
    if (assistant.faq(text) == null &&
        result.matchedFilters.isEmpty &&
        result.recommendations.isEmpty) {
      final answer = await localModel.answer(text);
      if (owner != _api.offline?.owner) {
        throw ApiException(
          'La sesión cambió. Vuelve a iniciar sesión.',
          statusCode: 401,
        );
      }
      if (answer != null) {
        return RecomendacionResponse(
          message: 'Modelo local · $answer',
          interpretation: result.interpretation,
          matchedFilters: result.matchedFilters,
          recommendations: result.recommendations,
        );
      }
    }
    return result;
  }

  Future<RecomendacionResponse?> getRecommendations(String message) async {
    final text = message.trim();
    if (text.isEmpty) return null;

    _isLoading = true;
    _errorMessage = null;
    _lastResponse = null;
    _isLocalResponse = false;
    notifyListeners();

    try {
      RecomendacionResponse result;
      if (_api.offline?.offline ?? false) {
        result = await _local(text);
      } else {
        try {
          final response = await _api.post(
            '/recommendations/chat',
            body: {'message': text},
          );
          result = RecomendacionResponse.fromJson(response);
        } on ApiException catch (error) {
          if (error.statusCode != 0 &&
              error.statusCode != 408 &&
              error.statusCode < 500) {
            rethrow;
          }
          result = await _local(text);
        }
      }
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

  @override
  void dispose() {
    localModel.dispose();
    super.dispose();
  }

  void clear() {
    _lastResponse = null;
    _errorMessage = null;
    _isLoading = false;
    _isLocalResponse = false;
    notifyListeners();
  }
}
