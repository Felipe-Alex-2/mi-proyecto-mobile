import 'dart:convert';

import '../configuracion/configuracion_api.dart';
import 'sin_conexion_service.dart';
import 'biometria_service.dart';
import 'sincronizacion_segundo_plano.dart';

import 'package:flutter/foundation.dart';

import '../modelos/usuario.dart';
import 'api_service.dart';
import 'almacenamiento_service.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  unauthenticated,
  authenticating,
  locked,
}

class AutenticacionService extends ChangeNotifier {
  final ApiService _apiService;
  final AlmacenamientoService _storageService;
  final SinConexionService? offline;
  final BiometriaService? biometrics;
  bool biometricEnabled = false;
  bool _unlocking = false;
  bool _disposed = false;
  bool profileSavePending = false;
  bool get unlocking => _unlocking;
  Future<void> _activate(Usuario user) async {
    _apiService.activeTenantId = user.role == 'CUSTOMER'
        ? user.selectedTenantId
        : null;
    _apiService.activeBranchId = user.role == 'CUSTOMER' ? user.branchId : null;
    final tenant =
        user.selectedTenantId ??
        user.tenantId ??
        '00000000-0000-0000-0000-000000000001';
    final owner =
        '${ConfiguracionApi.baseUrl}|$tenant|${user.branchId ?? ""}|${user.id}';
    await _storageService.saveSyncOwner(owner);
    await offline?.activate(owner);
    await _storageService.saveLocalUser(jsonEncode(user.toJson()));
    if (offline?.owner != null &&
        await offline!.store.read(offline!.owner!, '/users/me') == null) {
      await offline!.store.write(offline!.owner!, '/users/me', user.toJson());
    }
    biometricEnabled = await biometrics?.enabledFor(user.id) ?? false;
  }

  Future<void> _warmCache() async {
    final scope = _currentUser?.scopeKey;
    for (final path in [
      '/users/me',
      '/products',
      '/cart',
      if (_currentUser?.role == 'CUSTOMER') '/wallet',
      '/reservations',
      '/branches?is_active=true',
      '/catalog/filters',
      '/virtual-fitting/profile',
      '/virtual-fitting/sessions',
      '/notifications',
    ]) {
      if (_disposed || !isAuthenticated || _currentUser?.scopeKey != scope) {
        return;
      }
      try {
        await _apiService.get(path);
      } catch (_) {}
    }
    if (_disposed || !isAuthenticated || _currentUser?.scopeKey != scope) {
      return;
    }
    await offline?.sync();
    if (_disposed || !isAuthenticated || _currentUser?.scopeKey != scope) {
      return;
    }
    await SincronizacionSegundoPlano.schedule();
  }

  Future<bool> setBiometric(bool value) async {
    if (_currentUser == null || biometrics == null) return false;
    if (value) {
      if (!await biometrics!.enable(_currentUser!.id)) return false;
    } else {
      await biometrics!.disable();
    }
    biometricEnabled = value;
    notifyListeners();
    return true;
  }

  void lock() {
    if (biometricEnabled && isAuthenticated) {
      offline?.deactivate();
      _status = AuthStatus.locked;
      notifyListeners();
    }
  }

  Future<bool> unlock() async {
    if (_unlocking || _currentUser == null || biometrics == null) return false;
    _unlocking = true;
    notifyListeners();
    try {
      if (!await biometrics!.verify()) return false;
      await _activate(_currentUser!);
      _status = AuthStatus.authenticated;
      _warmCache();
      return true;
    } finally {
      _unlocking = false;
      notifyListeners();
    }
  }

  Usuario? _currentUser;
  AuthStatus _status = AuthStatus.uninitialized;
  String? _errorMessage;

  Usuario? get currentUser => _currentUser;
  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get errorMessage => _errorMessage;

  AutenticacionService(
    this._apiService,
    this._storageService, {
    this.offline,
    this.biometrics,
  }) {
    offline?.addListener(_syncChanged);
    _initialize();
  }

  int _syncRevision = -1;
  void _syncChanged() {
    final sync = offline!;
    if (_syncRevision == sync.revision || !isAuthenticated || sync.syncing) {
      return;
    }
    _syncRevision = sync.revision;
    _restoreProjectedUser();
  }

  Future<void> _restoreProjectedUser() async {
    if (_disposed) return;
    final account = offline?.owner;
    try {
      final data = await offline?.cached('/users/me');
      if (_disposed ||
          data == null ||
          account != offline?.owner ||
          !isAuthenticated ||
          data['id'] != _currentUser?.id) {
        return;
      }
      _currentUser = Usuario.fromJson(data);
      await _storageService.saveLocalUser(jsonEncode(_currentUser!.toJson()));
      if (!_disposed) notifyListeners();
    } catch (error) {
      if (!_disposed) {
        debugPrint('No se pudo actualizar el perfil guardado: $error');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    offline?.removeListener(_syncChanged);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final hasToken = await _storageService.hasToken();
      if (!hasToken) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final local = await _storageService.getLocalUser();
      if (local != null) {
        _currentUser = Usuario.fromJson(jsonDecode(local));
        biometricEnabled =
            await biometrics?.enabledFor(_currentUser!.id) ?? false;
        if (biometricEnabled) {
          _status = AuthStatus.locked;
          notifyListeners();
          return;
        }
        await _activate(_currentUser!);
      }
      try {
        final data = await _apiService.sendOnline('GET', '/users/me', {});
        _currentUser = Usuario.fromJson(data);
        await _activate(_currentUser!);
      } on ApiException catch (e) {
        if (e.statusCode != 0 && e.statusCode != 408 && e.statusCode < 500) {
          rethrow;
        }
        if (_currentUser == null) rethrow;
        if (offline != null) await offline!.checkAfterFailure(e);
      }
      _status = AuthStatus.authenticated;
      _warmCache();
    } catch (_) {
      offline?.deactivate();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
        includeAuth: false,
      );

      final accessToken = response['access_token'] as String;
      final refreshToken = response['refresh_token'] as String;
      _currentUser = Usuario.fromJson(response['user']);

      await _storageService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      await _activate(_currentUser!);
      _status = AuthStatus.authenticated;
      _warmCache();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String email,
    String password,
    String fullName, {
    String? tenantId,
    String? branchId,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.post(
        '/auth/register',
        body: {
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'tenant_id': ?tenantId,
          'branch_id': ?branchId,
        },
        includeAuth: false,
      );

      // Auto login after registration
      return await login(email, password);
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> selectStore(String tenantId, String branchId) async {
    try {
      await offline?.sync();
      final response = await _apiService.putOnline(
        '/saas/selection',
        body: {'tenant_id': tenantId, 'branch_id': branchId},
      );
      _currentUser = Usuario.fromJson(Map<String, dynamic>.from(response));
      await _activate(_currentUser!);
      notifyListeners();
      _warmCache();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? email,
    String? avatarId,
    String? profilePhoto,
    bool updateImage = false,
  }) async {
    _errorMessage = null;
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName.trim();
      if (email != null) body['email'] = email.trim();
      if (avatarId != null) body['avatar_id'] = avatarId;
      if (updateImage) body['profile_photo'] = profilePhoto;

      final response = await _apiService.put('/users/me', body: body);
      profileSavePending = response['_sync_pending'] == true;
      _currentUser = Usuario.fromJson(response);
      await _storageService.saveLocalUser(jsonEncode(_currentUser!.toJson()));
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> Function()? beforeLogout;

  Future<void> logout() async {
    try {
      await beforeLogout?.call();
    } catch (_) {}
    _apiService.activeTenantId = null;
    _apiService.activeBranchId = null;
    try {
      if (!(offline?.offline ?? false)) {
        await _apiService
            .post('/auth/logout')
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}

    offline?.deactivate();
    await _storageService.clearSyncOwner();
    await biometrics?.disable();
    biometricEnabled = false;
    await _storageService.clearTokens();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
