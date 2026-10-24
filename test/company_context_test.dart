import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile/servicios/almacen_sin_conexion.dart';
import 'package:mobile/servicios/sin_conexion_service.dart';
import 'package:mobile/servicios/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('company caches stay separate and all queued operations retain their original destination', () async {
    final store = await AlmacenSinConexion.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final sent = <Map<String, dynamic>>[];
    final offline = SinConexionService(store, (method, path, body) async {
      if (method == 'GET') return {'id': 'customer'};
      sent.add(body);
      return {'items': [], 'total_items': 0, 'total_amount': 0};
    });
    addTearDown(() async {
      offline.dispose();
      await store.db.close();
    });
    const a = 'api|company-a|branch-a|customer',
        b = 'api|company-b|branch-b|customer';
    await offline.activate(a);
    offline.offline = true;
    await store.write(a, '/products', [
      {'id': 'a-product'},
    ]);
    await offline.mutate('POST', '/cart/items', {
      'variant_id': 'a-variant',
      'quantity': 1,
    });
    await offline.activate(b);
    await store.write(b, '/products', [
      {'id': 'b-product'},
    ]);
    await offline.mutate('POST', '/cart/items', {
      'variant_id': 'b-variant',
      'quantity': 1,
    });
    expect((await offline.cached('/products'))[0]['id'], 'b-product');
    expect(offline.pendingCount, 2);
    await offline.sync();
    expect(sent.length, 2);
    final fromA = sent.singleWhere(
      (c) => c['body']['variant_id'] == 'a-variant',
    );
    expect(fromA['tenant_id'], 'company-a');
    expect(fromA['branch_id'], 'branch-a');
    expect(fromA['account_id'], 'customer');
    final fromB = sent.singleWhere(
      (c) => c['body']['variant_id'] == 'b-variant',
    );
    expect(fromB['tenant_id'], 'company-b');
    expect(fromB['branch_id'], 'branch-b');
    expect(offline.owner, b);
    expect(offline.pendingCount, 0);
    expect((await store.read(a, '/products'))[0]['id'], 'a-product');
  });
  test('a conflict from a different company remains visible after switching stores', () async {
    final store = await AlmacenSinConexion.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final offline = SinConexionService(store, (method, path, body) async {
      if (method == 'GET') return {'id': 'customer'};
      throw ApiException('Stock insuficiente', statusCode: 409);
    });
    addTearDown(() async {
      offline.dispose();
      await store.db.close();
    });
    await offline.activate('api|company-a|branch-a|customer');
    offline.offline = true;
    await offline.mutate('POST', '/cart/items', {
      'variant_id': 'a-variant',
      'quantity': 1,
    });
    await offline.activate('api|company-b|branch-b|customer');
    await offline.sync();
    expect(offline.pendingCount, 1);
    expect(offline.hasFailures, true);
    expect(
      offline.operations.single['owner'],
      'api|company-a|branch-a|customer',
    );
  });
}
