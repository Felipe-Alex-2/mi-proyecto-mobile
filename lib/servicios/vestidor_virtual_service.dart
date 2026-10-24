import 'sesion_notifier.dart';

import 'package:flutter/foundation.dart';

import '../modelos/perfil_biometrico.dart';
import '../modelos/resultado_vestidor_virtual.dart';
import 'api_service.dart';

class VestidorVirtualService extends SesionNotifier {
  final ApiService _apiService;

  PerfilBiometrico? _profile;
  bool _isLoading = false;
  bool _isTryingOn = false;

  VestidorVirtualService(this._apiService);

  PerfilBiometrico? get profile => _profile;
  bool get hasProfile => _profile != null;
  bool get isLoading => _isLoading;
  bool get isTryingOn => _isTryingOn;

  Future<PerfilBiometrico?> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.get('/virtual-fitting/profile');
      if (data != null && data is Map<String, dynamic> && data.isNotEmpty) {
        _profile = PerfilBiometrico.fromJson(data);
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

  Future<PerfilBiometrico> saveProfile(PerfilBiometrico profile) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.post(
        '/virtual-fitting/profile',
        body: profile.toJson(),
      );
      _profile = PerfilBiometrico.fromJson(data);
      return _profile!;
    } catch (e) {
      debugPrint('Error saving biometric profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<RecomendacionTalla> getRecommendation({
    required String productId,
    PerfilBiometrico? customProfile,
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
      return RecomendacionTalla.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching size recommendation: $e');
      rethrow;
    }
  }

  Future<VestidorVirtualResult> tryOnGarment({
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
      return VestidorVirtualResult.fromJson(data);
    } catch (e) {
      debugPrint('Error processing try on: $e');
      rethrow;
    } finally {
      _isTryingOn = false;
      notifyListeners();
    }
  }

  /// Realiza el Virtual Try-On real usando IDM-VTON via Gradio.
  ///
  /// Envía las imágenes como multipart al endpoint /virtual-fitting/idm-tryon
  /// y retorna los bytes de la imagen resultado (PNG/WebP) en base64.
  ///
  /// Lanza [ApiException] con statusCode 503 si el servicio VTON no está activo.
  Future<String> tryOnWithIDMVTON({
    required List<int> personImageBytes,
    required String personFilename,
    required List<int> garmentImageBytes,
    required String garmentFilename,
    String garmentDescription = '',
    bool useAutoMask = true,
    bool useAutoCrop = false,
    int denoiseSteps = 30,
    int seed = 42,
  }) async {
    _isTryingOn = true;
    notifyListeners();

    try {
      final data = await _apiService.postMultipart(
        '/virtual-fitting/idm-tryon',
        fileFields: {
          'person_image': {
            'bytes': personImageBytes,
            'filename': personFilename,
            'contentType': 'image/jpeg',
          },
          'garment_image': {
            'bytes': garmentImageBytes,
            'filename': garmentFilename,
            'contentType': 'image/jpeg',
          },
        },
        formFields: {
          'garment_description': garmentDescription,
          'use_auto_mask': useAutoMask.toString(),
          'use_auto_crop': useAutoCrop.toString(),
          'denoise_steps': denoiseSteps.toString(),
          'seed': seed.toString(),
        },
      );

      // El backend retorna { result_image_b64, mime_type, message }
      final b64 = data['result_image_b64'] as String? ?? '';
      final mimeType = data['mime_type'] as String? ?? 'image/webp';
      return 'data:$mimeType;base64,$b64';
    } catch (e) {
      debugPrint('Error en IDM-VTON try-on: $e');
      rethrow;
    } finally {
      _isTryingOn = false;
      notifyListeners();
    }
  }
}
