import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, authenticating }

class AuthService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  User? _currentUser;
  AuthStatus _status = AuthStatus.uninitialized;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get errorMessage => _errorMessage;

  AuthService(this._apiService, this._storageService) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final hasToken = await _storageService.hasToken();
      if (!hasToken) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final data = await _apiService.get('/users/me');
      _currentUser = User.fromJson(data);
      _status = AuthStatus.authenticated;
    } catch (_) {
      try {
        await _storageService.clearTokens();
      } catch (_) {}
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

      _status = AuthStatus.authenticated;
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

  Future<bool> updateProfile({String? fullName, String? email}) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName;
      if (email != null) body['email'] = email;

      final response = await _apiService.put('/users/me', body: body);
      _currentUser = User.fromJson(response);
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
      await _apiService.post('/auth/logout');
    } catch (_) {}

    await _storageService.clearTokens();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
