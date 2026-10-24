import 'sesion_notifier.dart';

import 'package:flutter/foundation.dart';

import '../modelos/carrito.dart';
import 'api_service.dart';

class CarritoService extends SesionNotifier {
  final ApiService _apiService;
  CarritoResponse? _cart;
  bool _isLoading = false;
  String? _errorMessage;
  Future<CarritoResponse>? _pendingLoad;
  bool _hasLoaded = false;
  String? get errorMessage => _errorMessage;
  bool get hasLoaded => _hasLoaded;

  CarritoService(this._apiService) {
    _apiService.offline?.addListener(_syncChanged);
  }
  int _revision = -1;
  void _syncChanged() {
    final sync = _apiService.offline!;
    if (_revision == sync.revision) return;
    _revision = sync.revision;
    if (_hasLoaded && !sync.syncing) loadCart();
  }

  @override
  void dispose() {
    _apiService.offline?.removeListener(_syncChanged);
    super.dispose();
  }

  CarritoResponse? get cart => _cart;
  int get itemCount => _cart?.totalItems ?? 0;
  double get totalAmount => _cart?.totalAmount ?? 0.0;
  bool get isLoading => _isLoading;
  bool get isEmpty => (_cart?.items.isEmpty ?? true);

  Future<CarritoResponse> loadCart() {
    return _pendingLoad ??= _loadCart().whenComplete(() => _pendingLoad = null);
  }

  Future<CarritoResponse> _loadCart() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.get('/cart');
      _cart = CarritoResponse.fromJson(data);
      _hasLoaded = true;
      return _cart!;
    } catch (e) {
      debugPrint('Error loading cart: $e');
      _errorMessage = e.toString();
      return _cart ?? CarritoResponse(items: [], totalItems: 0, totalAmount: 0);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CarritoResponse> addToCart(String variantId, {int quantity = 1}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.post(
        '/cart/items',
        body: {'variant_id': variantId, 'quantity': quantity},
      );
      _cart = CarritoResponse.fromJson(data);
      return _cart!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CarritoResponse> updateQuantity(String itemId, int quantity) async {
    try {
      final data = await _apiService.put(
        '/cart/items/$itemId',
        body: {'quantity': quantity},
      );
      _cart = CarritoResponse.fromJson(data);
      notifyListeners();
      return _cart!;
    } catch (e) {
      debugPrint('Error updating item quantity: $e');
      rethrow;
    }
  }

  Future<CarritoResponse> removeItem(String itemId) async {
    try {
      final data = await _apiService.delete('/cart/items/$itemId');
      _cart = CarritoResponse.fromJson(data);
      notifyListeners();
      return _cart!;
    } catch (e) {
      debugPrint('Error removing cart item: $e');
      rethrow;
    }
  }

  Future<CarritoResponse> clearCart() async {
    try {
      final data = await _apiService.delete('/cart');
      _cart = CarritoResponse.fromJson(data);
      notifyListeners();
      return _cart!;
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      rethrow;
    }
  }
}
