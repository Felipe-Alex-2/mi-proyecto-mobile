import 'package:flutter/foundation.dart';
import '../models/biometric_profile.dart';
import '../models/virtual_fitting_result.dart';
import 'api_service.dart';

class VirtualFittingService extends ChangeNotifier {
  final ApiService _apiService;

  BiometricProfile? _profile;
  bool _isLoading = false;
  bool _isTryingOn = false;

  VirtualFittingService(this._apiService);

  BiometricProfile? get profile => _profile;
  bool get hasProfile => _profile != null;
  bool get isLoading => _isLoading;
  bool get isTryingOn => _isTryingOn;

  Future<BiometricProfile?> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.get('/virtual-fitting/profile');
      if (data != null && data is Map<String, dynamic> && data.isNotEmpty) {
        _profile = BiometricProfile.fromJson(data);
      } else {
        _profile = null;
      }
      return _profile;
    } catch (e) {
      debugPrint('Error loading biometric profile: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BiometricProfile> saveProfile(BiometricProfile profile) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.post(
        '/virtual-fitting/profile',
        body: profile.toJson(),
      );
      _profile = BiometricProfile.fromJson(data);
      return _profile!;
    } catch (e) {
      debugPrint('Error saving biometric profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SizeRecommendation> getRecommendation({
    required String productId,
    BiometricProfile? customProfile,
  }) async {
    try {
      final Map<String, dynamic> body = {'product_id': productId};

      final p = customProfile ?? _profile;
      if (p != null) {
        body['gender'] = p.gender;
        body['height_cm'] = p.heightCm;
        body['weight_kg'] = p.weightKg;
        body['chest_cm'] = p.chestCm;
        body['waist_cm'] = p.waistCm;
        body['hip_cm'] = p.hipCm;
      }

      final data = await _apiService.post(
        '/virtual-fitting/recommend-size',
        body: body,
      );
      return SizeRecommendation.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching size recommendation: $e');
      rethrow;
    }
  }

  Future<VirtualFittingResult> tryOnGarment({
    required String productId,
    String? variantId,
    String? userImageBase64,
    String? userImageUrl,
  }) async {
    _isTryingOn = true;
    notifyListeners();

    try {
      final Map<String, dynamic> body = {'product_id': productId};
      if (variantId != null) body['variant_id'] = variantId;
      if (userImageBase64 != null) body['user_image_base64'] = userImageBase64;
      if (userImageUrl != null) body['user_image_url'] = userImageUrl;

      final data = await _apiService.post(
        '/virtual-fitting/try-on',
        body: body,
      );
      return VirtualFittingResult.fromJson(data);
    } catch (e) {
      debugPrint('Error processing try on: $e');
      rethrow;
    } finally {
      _isTryingOn = false;
      notifyListeners();
    }
  }
}
