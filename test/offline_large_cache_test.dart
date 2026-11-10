import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile/servicios/almacen_sin_conexion.dart';
import 'package:mobile/servicios/sin_conexion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AlmacenSinConexion store;
  late Directory directory;
  const owner = 'api|company|branch|user';
  late String location;
  final photo = 'data:image/jpeg;base64,${'A' * (3 * 1024 * 1024)}';
  final products = [
    {
      'id': 'p1',
      'name': 'Pantalón azul 👖',
      'price': 15,
      'image_url': photo,
      'variants': [
        {'id': 'v1', 'color': 'Azul', 'size': 'M', 'total_stock': 5},
      ],
    },
  ];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vesta_large_cache_');
    location = '${directory.path}/offline.db';
    store = await AlmacenSinConexion.open(
      factory: databaseFactoryFfi,
      path: location,
    );
  });
  tearDown(() async {
    await store.db.close();
    await directory.delete(recursive: true);
  });

  test(
    'large Unicode catalog uses bounded SQLite rows and remains isolated',
    () async {
      final value = [
        ...products,
        {'name': 'áéíóú 👖' * 100000},
      ];
      await store.write(owner, '/products', value);
      expect(await store.read(owner, '/products'), value);
      expect(await store.read('api|other|branch|user', '/products'), isNull);
      final max = await store.db.rawQuery(
        'SELECT max(length(data)) AS size FROM cache_parts',
      );
      expect(
        max.single['size'],
        lessThanOrEqualTo(AlmacenSinConexion.chunkBytes),
      );
      await store.write(owner, '/products', []);
      expect(await store.read(owner, '/products'), isEmpty);
      expect(await store.db.query('cache_parts'), isEmpty);
    },
  );

  test(
    'upgrade reads a legacy oversized catalog and preserves pending operations',
    () async {
      await store.db.insert('cache', {
        'owner': owner,
        'path': '/products',
        'data': jsonEncode(products),
        'updated_at': '2026-11-09',
      });
      await store.db.insert('outbox', {
        'owner': owner,
        'id': 'pending-before-upgrade',
        'method': 'POST',
        'path': '/cart/items',
        'body': '{"variant_id":"v1","quantity":1}',
        'preview': jsonEncode({'image': photo}),
        'created_at': '2026-11-09',
      });
      await store.db.execute('DROP TABLE cache_parts');
      await store.db.setVersion(1);
      await store.db.close();
      store = await AlmacenSinConexion.open(
        factory: databaseFactoryFfi,
        path: location,
      );
      expect(await store.db.getVersion(), 2);
      expect(await store.read(owner, '/products'), products);
      final pending = await store.queue(owner);
      expect(pending.single['id'], 'pending-before-upgrade');
      expect(jsonDecode(pending.single['preview'] as String)['image'], photo);
    },
  );

  test(
    'large catalog to cart to wallet persists then synchronizes exactly once',
    () async {
      await store.write(owner, '/products', products);
      await store.write(owner, '/cart', {'items': [], 'total_amount': 0});
      await store.write(owner, '/wallet', {'balance': 100, 'currency': 'USD'});
      final sent = <String>[];
      SinConexionService create() =>
          SinConexionService(store, (_, path, body) async {
            if (path == '/users/me') return {'id': 'user'};
            sent.add(body['operation_id'] as String);
            if (body['path'] == '/cart/items') {
              return {
                'items': [
                  {
                    'id': 'remote-item',
                    'variant_id': 'v1',
                    'quantity': 1,
                    'price': 15,
                  },
                ],
                'total_amount': 15,
                'total_items': 1,
              };
            }
            return {
              'id': 'paid-reservation',
              'status': 'CONFIRMED',
              'payment_status': 'PAID',
              'payment_method': 'WALLET',
              'total_amount': 15,
              'wallet_balance': 85,
              'items': [],
            };
          });
      var offline = create();
      await offline.activate(owner);
      offline.offline = true;
      await offline.mutate('POST', '/cart/items', {
        'variant_id': 'v1',
        'quantity': 1,
      });
      expect(
        (await offline.cached('/cart'))['items'].single['product_name'],
        'Pantalón azul 👖',
      );
      final pending = await offline.mutate('POST', '/reservations', {
        'branch_id': 'branch',
        'payment_method': 'WALLET',
        'request_id': '565f4d13-be22-4898-bb19-0a6fe5947bcb',
        'items': [
          {'variant_id': 'v1', 'quantity': 1},
        ],
      });
      expect(pending['payment_status'], 'SYNC_PENDING');
      expect((await offline.cached('/wallet'))['balance'], 85);
      expect(sent, isEmpty);
      offline.dispose();
      await store.db.close();
      store = await AlmacenSinConexion.open(
        factory: databaseFactoryFfi,
        path: location,
      );
      offline = create();
      addTearDown(offline.dispose);
      await offline.activate(owner);
      offline.offline = true;
      expect(offline.pendingCount, 2);
      expect((await offline.cached('/wallet'))['balance'], 85);
      offline.offline = false;
      await offline.sync();
      await offline.sync();
      expect(offline.pendingCount, 0);
      expect(sent.length, 2);
      expect(sent.toSet().length, 2);
      expect((await offline.cached('/wallet'))['balance'], 85);
    },
  );
}
