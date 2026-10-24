import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/autenticacion_service.dart';
import 'package:mobile/servicios/biometria_service.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';

class Device extends BiometriaService {
  bool accepted = false;
  bool enabled = true;
  @override
  Future<bool> enabledFor(String id) async => enabled;
  @override
  Future<bool> verify() async => accepted;
  @override
  Future<bool> enable(String id) async {
    if (!accepted) return false;
    enabled = true;
    return true;
  }

  @override
  Future<void> disable() async {
    enabled = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final user = {
    'id': 'user1',
    'email': 'cliente@example.com',
    'full_name': 'Cliente VESTA',
    'created_at': '2026-10-19T12:00:00Z',
    'updated_at': '2026-10-19T12:00:00Z',
  };
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'access_token': 'stored-token',
      'refresh_token': 'refresh',
      'local_user': jsonEncode(user),
    }),
  );
  test('startup with biometric preference stays locked until successful verification', () async {
    var requests = 0;
    final storage = AlmacenamientoService();
    final api = ApiService(
      storage,
      client: MockClient((_) async {
        requests++;
        return http.Response(jsonEncode(user), 200);
      }),
    );
    final device = Device();
    final auth = AutenticacionService(api, storage, biometrics: device);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(auth.status, AuthStatus.locked);
    expect(requests, 0);
    expect(await auth.unlock(), isFalse);
    expect(auth.status, AuthStatus.locked);
    device.accepted = true;
    expect(await auth.unlock(), isTrue);
    expect(auth.status, AuthStatus.authenticated);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    auth.lock();
    expect(auth.status, AuthStatus.locked);
    auth.dispose();
    api.dispose();
  });
  test(
    'disable removes biometric preference and logout removes credentials',
    () async {
      final storage = AlmacenamientoService();
      final api = ApiService(
        storage,
        client: MockClient((_) async => http.Response(jsonEncode(user), 200)),
      );
      final device = Device()..accepted = true;
      final auth = AutenticacionService(api, storage, biometrics: device);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await auth.unlock();
      expect(await auth.setBiometric(false), isTrue);
      auth.lock();
      expect(auth.status, AuthStatus.authenticated);
      await auth.logout();
      expect(await storage.hasToken(), isFalse);
      expect(await storage.getSyncOwner(), isNull);
      expect(auth.status, AuthStatus.unauthenticated);
      auth.dispose();
      api.dispose();
    },
  );
}
