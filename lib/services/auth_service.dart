import 'dart:convert';

import '../config/api_config.dart';
import 'offline_service.dart';
import 'biometric_service.dart';
import 'background_sync.dart';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  unauthenticated,
  authenticating,
  locked,
}

class AuthService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;
  final OfflineService? offline;
  final BiometricService? biometrics;
  bool biometricEnabled = false;
  bool _unlocking = false;
  bool get unlocking => _unlocking;
  Future<void> _activate(User user) async {
    await _storageService.saveSyncOwner('${ApiConfig.baseUrl}|${user.id}');
    await offline?.activate('${ApiConfig.baseUrl}|${user.id}');
    await _storageService.saveLocalUser(jsonEncode(user.toJson()));
    if (offline?.owner != null &&
        await offline!.store.read(offline!.owner!, '/users/me') == null) {
      await offline!.store.write(offline!.owner!, '/users/me', user.toJson());
    }
    biometricEnabled = await biometrics?.enabledFor(user.id) ?? false;
  }

  Future<void> _warmCache() async {
    for (final path in [
      '/users/me',
      '/products',
      '/cart',
      '/reservations',
      '/branches?is_active=true',
      '/catalog/filters',
      '/virtual-fitting/profile',
      '/virtual-fitting/sessions',
      '/notifications',
    ]) {
      if (!isAuthenticated) return;
      try {
        await _apiService.get(path);
      } catch (_) {}
    }
    await offline?.sync();
    await BackgroundSync.schedule();
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

  User? _currentUser;
  AuthStatus _status = AuthStatus.uninitialized;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get errorMessage => _errorMessage;

  AuthService(
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
    final account = offline?.owner;
    final data = await offline?.cached('/users/me');
    if (data == null ||
        account != offline?.owner ||
        !isAuthenticated ||
        data['id'] != _currentUser?.id) {
      return;
    }
    _currentUser = User.fromJson(data);
    await _storageService.saveLocalUser(jsonEncode(_currentUser!.toJson()));
    notifyListeners();
  }

  @override
  void dispose() {
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
        _currentUser = User.fromJson(jsonDecode(local));
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
        _currentUser = User.fromJson(data);
        await _activate(_currentUser!);
      } on ApiException catch (e) {
        if (e.statusCode != 0 && e.statusCode != 408 && e.statusCode < 500) {
          rethrow;
        }
        if (_currentUser == null) rethrow;
        if (offline != null) offline!.offline = true;
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
      _currentUser = User.fromJson(response['user']);

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

  Future<bool> register(String email, String password, String fullName) async {
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
      _currentUser = User.fromJson(response);
      await _storageService.saveLocalUser(jsonEncode(_currentUser!.toJson()));
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
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
