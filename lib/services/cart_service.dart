import 'session_notifier.dart';

import 'package:flutter/foundation.dart';

import '../models/cart.dart';
import 'api_service.dart';

class CartService extends SessionNotifier {
  final ApiService _apiService;
  CartResponse? _cart;
  bool _isLoading = false;
  String? _errorMessage;
  Future<CartResponse>? _pendingLoad;
  bool _hasLoaded = false;
  String? get errorMessage => _errorMessage;
  bool get hasLoaded => _hasLoaded;

  CartService(this._apiService);

  CartResponse? get cart => _cart;
  int get itemCount => _cart?.totalItems ?? 0;
  double get totalAmount => _cart?.totalAmount ?? 0.0;
  bool get isLoading => _isLoading;
  bool get isEmpty => (_cart?.items.isEmpty ?? true);

  Future<CartResponse> loadCart() {
    return _pendingLoad ??= _loadCart().whenComplete(() => _pendingLoad = null);
  }

  Future<CartResponse> _loadCart() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.get('/cart');
      _cart = CartResponse.fromJson(data);
      _hasLoaded = true;
      return _cart!;
    } catch (e) {
      debugPrint('Error loading cart: $e');
      _errorMessage = e.toString();
      return _cart ?? CartResponse(items: [], totalItems: 0, totalAmount: 0);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CartResponse> addToCart(String variantId, {int quantity = 1}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.post(
        '/cart/items',
        body: {'variant_id': variantId, 'quantity': quantity},
      );
      _cart = CartResponse.fromJson(data);
      return _cart!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CartResponse> updateQuantity(String itemId, int quantity) async {
    try {
      final data = await _apiService.put(
        '/cart/items/$itemId',
        body: {'quantity': quantity},
      );
      _cart = CartResponse.fromJson(data);
      notifyListeners();
      return _cart!;
    } catch (e) {
      debugPrint('Error updating item quantity: $e');
      rethrow;
    }
  }

  Future<CartResponse> removeItem(String itemId) async {
    try {
      final data = await _apiService.delete('/cart/items/$itemId');
      _cart = CartResponse.fromJson(data);
      notifyListeners();
      return _cart!;
    } catch (e) {
      debugPrint('Error removing cart item: $e');
      rethrow;
    }
  }

  Future<void> clearCart() async {
    try {
      final data = await _apiService.delete('/cart');
      _cart = CartResponse.fromJson(data);
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      rethrow;
    }
  }
}
