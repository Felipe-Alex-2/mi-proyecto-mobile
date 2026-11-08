import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile/servicios/almacen_sin_conexion.dart';
import 'package:mobile/servicios/sin_conexion_service.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';
import 'package:mobile/servicios/autenticacion_service.dart';
import 'package:mobile/widgets/bloqueo_sesion.dart';

class Storage extends AlmacenamientoService {
  @override
  Future<bool> hasToken() async => false;
}

class Auth extends AutenticacionService {
  Auth(super.api, super.storage);
  int locks = 0;
  @override
  void lock() {
    locks++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('API errors and timeouts do not mean internet disconnection', () async {
    final store = await AlmacenSinConexion.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    var internet = true;
    final service = SinConexionService(
      store,
      (_, _, _) async => {},
      internetCheck: () async => internet,
    );
    await service.activate('api|user');
    await store.write('api|user', '/products', [
      {'id': 'p'},
    ]);
    for (final code in [500, 503, 408, 0]) {
      final cached = await service.read(
        '/products',
        () async => throw ApiException('Unavailable', statusCode: code),
      );
      expect(cached[0]['id'], 'p');
      expect(service.offline, isFalse);
      expect(service.serverUnavailable, isTrue);
    }
    internet = false;
    await service.checkAfterFailure(ApiException('No network', statusCode: 0));
    expect(service.offline, isTrue);
    internet = true;
    await service.refreshConnection();
    expect(service.offline, isFalse);
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    internet = false;
    await service.checkAfterFailure(ApiException('Suspended', statusCode: 0));
    expect(service.offline, isFalse);
    service.dispose();
    await store.db.close();
  });

  test('resume rechecks internet after transient background failure', () async {
    final store = await AlmacenSinConexion.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    var checks = 0;
    final service = SinConexionService(
      store,
      (_, _, _) async => {},
      internetCheck: () async {
        checks++;
        return true;
      },
    );
    service.offline = true;
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect(checks, 1);
    expect(service.offline, isFalse);
    service.dispose();
    await store.db.close();
  });

  testWidgets('session remains unlocked through five minutes in background', (
    tester,
  ) async {
    final storage = Storage();
    final api = ApiService(storage);
    final auth = Auth(api, storage);
    var now = DateTime(2026, 11, 8, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: BloqueoSesion(
          auth: auth,
          now: () => now,
          child: const SizedBox(),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(auth.locks, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 5, seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(auth.locks, 1);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    api.dispose();
  });
}
