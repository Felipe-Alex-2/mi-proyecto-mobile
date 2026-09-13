import 'package:flutter/foundation.dart';
import '../models/reservation.dart';
import 'api_service.dart';

class ReservationService extends ChangeNotifier {
  final ApiService _apiService;
  List<Reservation> _reservations = [];
  bool _isLoading = false;

  ReservationService(this._apiService);

  List<Reservation> get reservations => _reservations;
  bool get isLoading => _isLoading;

  Future<List<Reservation>> loadReservations() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.get('/reservations');
      _reservations = (data as List<dynamic>?)
              ?.map((item) => Reservation.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
      return _reservations;
    } catch (e) {
      debugPrint('Error loading reservations: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Reservation> createReservation({
    required String branchId,
    required List<Map<String, dynamic>> items,
    String? customerNotes,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        'branch_id': branchId,
        'items': items,
        if (customerNotes != null && customerNotes.trim().isNotEmpty)
          'customer_notes': customerNotes.trim(),
      };

      final data = await _apiService.post('/reservations', body: body);
      final newRes = Reservation.fromJson(data);
      _reservations.insert(0, newRes);
      return newRes;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Reservation> cancelReservation(String id) async {
    try {
      final data = await _apiService.delete('/reservations/$id');
      final updated = Reservation.fromJson(data);
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

  Future<List<BranchOption>> getActiveBranches() async {
    try {
      final data = await _apiService.get('/catalog/filters');
      final branchesJson = data['branches'] as List<dynamic>? ?? [];
      return branchesJson
          .map((b) => BranchOption.fromJson(b as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading active branches: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVariantAvailability(String variantId) async {
    try {
      final data = await _apiService.get('/stocks/variant/$variantId/availability');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading variant availability: $e');
      return [];
    }
  }
}
