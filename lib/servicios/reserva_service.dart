import 'sesion_notifier.dart';

import 'package:flutter/foundation.dart';

import '../modelos/reserva.dart';
import 'api_service.dart';

class ReservaService extends SesionNotifier {
  final ApiService _apiService;
  List<Reserva> _reservations = [];
  bool _isLoading = false;
  String? _errorMessage;
  Future<List<Reserva>>? _pendingLoad;
  bool _hasLoaded = false;
  String? get errorMessage => _errorMessage;
  bool get hasLoaded => _hasLoaded;

  ReservaService(this._apiService) {
    _apiService.offline?.addListener(_syncChanged);
  }
  int _revision = -1;
  void _syncChanged() {
    final sync = _apiService.offline!;
    if (_revision == sync.revision) return;
    _revision = sync.revision;
    if (_hasLoaded && !sync.syncing) loadReservations();
  }

  @override
  void dispose() {
    _apiService.offline?.removeListener(_syncChanged);
    super.dispose();
  }

  List<Reserva> get reservations => _reservations;
  bool get isLoading => _isLoading;

  Future<List<Reserva>> loadReservations() {
    return _pendingLoad ??= _loadReservations().whenComplete(
      () => _pendingLoad = null,
    );
  }

  Future<List<Reserva>> _loadReservations() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.get('/reservations');
      _reservations =
          (data as List<dynamic>?)
              ?.map((item) => Reserva.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
      _hasLoaded = true;
      return _reservations;
    } catch (e) {
      debugPrint('Error loading reservations: $e');
      _errorMessage = e.toString();
      return _reservations;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Reserva> createReservation({
    required String branchId,
    required List<Map<String, dynamic>> items,
    String? customerNotes,
    String? couponCode,
    Map<String, dynamic>? delivery,
    String paymentMethod = 'EFECTIVO',
    String? idempotencyKey,
  }) async {
    if ((_apiService.offline?.offline ?? false) &&
        (delivery != null ||
            paymentMethod == 'PAYPAL' ||
            (couponCode?.isNotEmpty ?? false))) {
      throw ApiException(
        delivery != null
            ? 'Delivery necesita Internet para confirmar la ruta y el pago.'
            : 'PayPal y la validación de cupones necesitan Internet.',
        statusCode: 422,
      );
    }
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        ...?delivery,
        'branch_id': branchId,
        'payment_method': paymentMethod,
        'request_id': ?idempotencyKey,
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
        'items': items,
        if (customerNotes != null && customerNotes.trim().isNotEmpty)
          'customer_notes': customerNotes.trim(),
      };

      final data =
          delivery != null ||
              paymentMethod == 'PAYPAL' ||
              (paymentMethod == 'WALLET' &&
                  _apiService.offline?.owner == null) ||
              (couponCode != null && couponCode.isNotEmpty)
          ? await _apiService.postOnline('/reservations', body: body)
          : await _apiService.post('/reservations', body: body);
      final newRes = Reserva.fromJson(data);
      _reservations.insert(0, newRes);
      return newRes;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createPayPalReservationOrder({
    required String branchId,
    required List<Map<String, dynamic>> items,
    String? customerNotes,
    String? couponCode,
    Map<String, dynamic>? delivery,
  }) async {
    if (_apiService.offline?.offline ?? false) {
      throw ApiException(
        'PayPal necesita Internet. Elige pago presencial o wallet.',
        statusCode: 0,
      );
    }
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        ...?delivery,
        'branch_id': branchId,
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
        'items': items,
        if (customerNotes != null && customerNotes.trim().isNotEmpty)
          'customer_notes': customerNotes.trim(),
      };

      final reservation = await _apiService.postOnline(
        '/reservations',
        body: {...body, 'payment_method': 'PAYPAL'},
      );
      if ((reservation['id'] as String).startsWith('local:')) {
        return {'pending_sync': true, 'reservation': reservation};
      }
      return await _apiService.post(
        '/reservations/${reservation['id']}/paypal-order',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Reserva> capturePayPalReservationOrder(String orderId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.post(
        '/reservations/paypal-capture',
        body: {'order_id': orderId, 'paypal_order_id': orderId},
      );
      final updated = Reserva.fromJson(data['reservation'] ?? data);
      final idx = _reservations.indexWhere((r) => r.id == updated.id);
      if (idx != -1) {
        _reservations[idx] = updated;
      } else {
        _reservations.insert(0, updated);
      }
      return updated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Reserva> cancelReservation(String id) async {
    try {
      final data = await _apiService.delete('/reservations/$id');
      final updated = Reserva.fromJson(data['reservation'] ?? data);
      final idx = _reservations.indexWhere((r) => r.id == id);
      if (idx != -1) {
        _reservations[idx] = updated;
        notifyListeners();
      }
      return updated;
    } catch (e) {
      debugPrint('Error cancelling reservation: $e');
      rethrow;
    }
  }

  Future<List<SucursalOption>> getActiveBranches() async {
    List<SucursalOption> scoped(List<SucursalOption> rows) =>
        _apiService.activeBranchId == null
        ? rows
        : rows.where((b) => b.id == _apiService.activeBranchId).toList();
    // 1. Intentar directamente desde /branches?is_active=true
    try {
      final data = await _apiService.get('/branches?is_active=true');
      if (data is List) {
        final list = data
            .map((b) => SucursalOption.fromJson(b as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) return scoped(list);
      }
    } catch (e) {
      debugPrint('Error loading active branches from /branches: $e');
    }

    // 2. Fallback a /catalog/filters
    try {
      final data = await _apiService.get('/catalog/filters');
      final branchesJson = data['branches'] as List<dynamic>? ?? [];
      final list = branchesJson
          .map((b) => SucursalOption.fromJson(b as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) return scoped(list);
    } catch (e) {
      debugPrint('Error loading active branches from /catalog/filters: $e');
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getVariantAvailability(
    String variantId,
  ) async {
    try {
      final data = await _apiService.get(
        '/stocks/variant/$variantId/availability',
      );
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading variant availability: $e');
      return [];
    }
  }
}
