import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile/servicios/almacen_sin_conexion.dart';
import 'package:mobile/servicios/sin_conexion_service.dart';
import 'package:mobile/servicios/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AlmacenSinConexion store;
  late SinConexionService service;
  const owner = 'api|company|branch|user';
  Map<String, dynamic> purchase(String request, {int quantity = 1}) => {
    'branch_id': 'branch',
    'payment_method': 'WALLET',
    'request_id': request,
    'items': [
      {'variant_id': 'v1', 'quantity': quantity},
    ],
  };
  Future<void> cart(String key) => store.write(key, '/cart', {
    'items': [
      {
        'id': 'i',
        'variant_id': 'v1',
        'quantity': 1,
        'price': 50,
        'subtotal': 50,
      },
    ],
    'total_items': 1,
    'total_amount': 50,
  });
  setUp(() async {
    store = await AlmacenSinConexion.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    service = SinConexionService(
      store,
      (method, path, body) async => {
        'id': 'server-reservation',
        'reservation_code': 'RSV-CONFIRMED',
        'status': 'CONFIRMED',
        'payment_status': 'PAID',
        'payment_method': 'WALLET',
        'wallet_balance': 50,
        'total_amount': 50,
        'items': [],
      },
      internetCheck: () async => true,
    );
    await service.activate(owner);
    service.offline = true;
    await store.write(owner, '/wallet', {'balance': 100, 'currency': 'USD'});
    await cart(owner);
  });
  tearDown(() async {
    service.dispose();
    await store.db.close();
  });
  test('offline wallet holds funds, clears cart, survives service restart and syncs once', () async {
    final data = purchase('b3dcc5f4-72e0-424f-84ec-3406089724a1');
    final result = await service.mutate('POST', '/reservations', data);
    expect(result['payment_status'], 'SYNC_PENDING');
    expect((await service.cached('/wallet'))['balance'], 50);
    expect((await service.cached('/cart'))['items'], isEmpty);
    expect(
      (await service.mutate('POST', '/reservations', data))['id'],
      result['id'],
    );
    expect(service.pendingCount, 1);
    service.dispose();
    service = SinConexionService(
      store,
      (_, _, _) async => {
        'id': 'remote',
        'status': 'CONFIRMED',
        'payment_status': 'PAID',
        'payment_method': 'WALLET',
        'wallet_balance': 50,
        'total_amount': 50,
        'items': [],
      },
    );
    await service.activate(owner);
    service.offline = true;
    expect((await service.cached('/wallet'))['balance'], 50);
    service.offline = false;
    await service.sync();
    await service.sync();
    expect(service.pendingCount, 0);
    expect((await service.cached('/wallet'))['balance'], 50);
    expect((await service.cached('/wallet'))['pending_debits'], 0);
  });
  test('holds span branches but not companies or users and prevent local overspending', () async {
    await service.mutate(
      'POST',
      '/reservations',
      purchase('a39fcbd1-d178-4bb5-9cbc-b120b8ae73c9'),
    );
    const branch2 = 'api|company|branch2|user';
    await store.write(branch2, '/wallet', {'balance': 100, 'currency': 'USD'});
    await cart(branch2);
    await service.activate(branch2);
    expect((await service.cached('/wallet'))['balance'], 50);
    await expectLater(
      service.mutate(
        'POST',
        '/reservations',
        purchase('7e8d60bc-d07e-49b7-a9c3-60fca8e558e4', quantity: 2),
      ),
      throwsA(isA<ApiException>()),
    );
    const another = 'api|other-company|branch|user';
    await store.write(another, '/wallet', {'balance': 100, 'currency': 'USD'});
    await service.activate(another);
    expect((await service.cached('/wallet'))['balance'], 100);
  });
  test(
    'confirmed server conflict releases local hold and preserves failed intent',
    () async {
      await service.mutate(
        'POST',
        '/reservations',
        purchase('a39fcbd1-d178-4bb5-9cbc-b120b8ae73c9'),
      );
      service.dispose();
      service = SinConexionService(
        store,
        (_, _, _) async =>
            throw ApiException('Saldo insuficiente', statusCode: 409),
      );
      await service.activate(owner);
      service.offline = false;
      await service.sync();
      expect(service.operations.single['state'], 'blocked');
      expect((await service.cached('/wallet'))['balance'], 100);
      expect((await service.cached('/reservations')) as dynamic, isNull);
    },
  );
}
