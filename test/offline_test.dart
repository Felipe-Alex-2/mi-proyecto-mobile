import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/widgets/offline_status.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile/services/offline_store.dart';
import 'package:mobile/services/offline_service.dart';
import 'package:mobile/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late OfflineStore store;
  late OfflineService offline;
  final sent = <Map<String, dynamic>>[];
  setUp(() async {
    sent.clear();
    store = await OfflineStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    offline = OfflineService(store, (method, path, body) async {
      if (method == 'GET') return {'id': 'u1'};
      sent.add(body);
      if (body['path'] == '/reservations') {
        return {
          'id': 'server-${body['operation_id']}',
          'status': 'PENDING',
          'payment_status': 'PENDING',
          'items': [],
        };
      }
      return {'id': 'u1', 'full_name': body['body']['full_name'], 'items': []};
    });
    await offline.activate('api|u1');
    offline.offline = true;
    await store.write('api|u1', '/users/me', {
      'id': 'u1',
      'full_name': 'Original',
    });
  });
  tearDown(() async {
    offline.dispose();
    await store.db.close();
  });

  testWidgets(
    'offline banner opens pending queue above the navigator on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => offline.mutate('PUT', '/users/me', {'full_name': 'Pendiente'}),
      );
      final navigation = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: offline,
          child: MaterialApp(
            navigatorKey: navigation,
            builder: (context, child) =>
                OfflineStatus(navigatorKey: navigation, child: child!),
            home: const Scaffold(body: Text('VESTA')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Modo offline'), findsOneWidget);
      await tester.tap(find.textContaining('Modo offline'));
      await tester.pumpAndSettle();
      expect(find.text('Cambios guardados en el dispositivo'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('offline reads cache and never invokes network', () async {
    await store.write('api|u1', '/products', [
      {'id': 'p1', 'name': 'Camisa'},
    ]);
    final result = await offline.read(
      '/products',
      () async => throw StateError('Network called'),
    );
    expect(result[0]['name'], 'Camisa');
    expect((await offline.read('/products/p1', () async => null))['id'], 'p1');
  });
  test('profile pending projection is durable and account isolated', () async {
    await offline.mutate('PUT', '/users/me', {'full_name': 'Editado offline'});
    expect(offline.pendingCount, 1);
    final result = await offline.read('/users/me', () async => null);
    expect(result['full_name'], 'Editado offline');
    await offline.activate('api|u2');
    expect(offline.pendingCount, 0);
    expect(await store.read('api|u2', '/users/me'), isNull);
    await offline.activate('api|u1');
    expect(offline.pendingCount, 1);
  });
  test('FIFO drains once without concurrent sends or duplicates', () async {
    await offline.mutate('PUT', '/users/me', {'full_name': 'Primero'});
    await offline.mutate('PUT', '/users/me', {'full_name': 'Segundo'});
    offline.offline = false;
    await Future.wait([offline.sync(), offline.sync(), offline.sync()]);
    expect(sent.map((r) => r['body']['full_name']).toList(), [
      'Primero',
      'Segundo',
    ]);
    expect(offline.pendingCount, 0);
    expect((await store.read('api|u1', '/users/me'))['full_name'], 'Segundo');
  });
  test(
    'stock conflict blocks FIFO and is visible, never silently dropped',
    () async {
      offline.dispose();
      offline = OfflineService(
        store,
        (_, _, _) async => throw ApiException('Sin stock', statusCode: 409),
      );
      await offline.activate('api|u1');
      offline.offline = true;
      await offline.mutate('POST', '/reservations', {
        'branch_id': 'b1',
        'items': [
          {'variant_id': 'v1', 'quantity': 1},
        ],
      });
      await offline.mutate('PUT', '/users/me', {'full_name': 'Segundo'});
      offline.offline = false;
      await offline.sync();
      expect(offline.operations.first['state'], 'blocked');
      expect(offline.operations.last['state'], 'pending');
      final reservations = await offline.read('/reservations', () async => []);
      expect(reservations[0]['status'], 'SYNC_FAILED');
      await offline.discardFrom(offline.operations.first['seq'] as int);
      expect(offline.pendingCount, 0);
    },
  );
  test('timeout preserves operation UUID for safe replay', () async {
    String? first;
    var attempt = 0;
    offline.dispose();
    offline = OfflineService(store, (_, _, body) async {
      if (attempt++ == 0) {
        first = body['operation_id'];
        throw ApiException('timeout', statusCode: 408);
      }
      expect(body['operation_id'], first);
      return {'id': 'u1', 'full_name': 'Cambio'};
    });
    await offline.activate('api|u1');
    await offline.mutate('PUT', '/users/me', {'full_name': 'Cambio'});
    expect(offline.pendingCount, 1);
    offline.offline = false;
    await offline.sync();
    expect(offline.pendingCount, 0);
  });
  test('expired session retains outbox and asks to login', () async {
    offline.dispose();
    offline = OfflineService(
      store,
      (_, _, _) async => throw ApiException('expired', statusCode: 401),
    );
    await offline.activate('api|u1');
    await offline.mutate('PUT', '/users/me', {'full_name': 'Cambio'});
    expect(offline.needsLogin, isTrue);
    expect(offline.pendingCount, 1);
  });
  test('cart can add, edit and remove a local item before syncing', () async {
    await store.write('api|u1', '/products', [
      {
        'id': 'p1',
        'name': 'Camisa',
        'price': 10,
        'variants': [
          {'id': 'v1'},
        ],
      },
    ]);
    final added = await offline.mutate('POST', '/cart/items', {
      'variant_id': 'v1',
      'quantity': 1,
    });
    final id = added['items'][0]['id'];
    final edited = await offline.mutate('PUT', '/cart/items/$id', {
      'quantity': 2,
    });
    expect(edited['total_amount'], 20);
    expect(edited['total_items'], 2);
    final removed = await offline.mutate('DELETE', '/cart/items/$id', {});
    expect(removed['items'], isEmpty);
    expect(offline.pendingCount, 3);
  });

  test(
    'new measurements and read notifications remain available offline',
    () async {
      final result = await offline.mutate('POST', '/virtual-fitting/profile', {
        'gender': 'HOMBRE',
        'height_cm': 180,
        'weight_kg': 75,
        'chest_cm': 95,
        'waist_cm': 80,
        'hip_cm': 95,
      });
      expect(result['height_cm'], 180);
      final loaded = await offline.read(
        '/virtual-fitting/profile',
        () async => throw StateError('network'),
      );
      expect(loaded['height_cm'], 180);
      await store.write('api|u1', '/notifications', [
        {'id': 'n1', 'is_read': false},
      ]);
      await offline.mutate('PATCH', '/notifications/n1/read', {});
      expect((await offline.cached('/notifications'))[0]['is_read'], isTrue);
    },
  );
  test('offline PayPal is pending and cannot be marked paid', () async {
    final result = await offline.mutate('POST', '/reservations', {
      'branch_id': 'b1',
      'payment_method': 'PAYPAL',
      'items': [
        {'variant_id': 'v1', 'quantity': 1},
      ],
    });
    expect(result['status'], 'SYNC_PENDING');
    expect(result['payment_status'], 'PENDING');
    expect(sent, isEmpty);
  });
  test('dependent cancellation resolves local reservation ID', () async {
    final result = await offline.mutate('POST', '/reservations', {
      'branch_id': 'b1',
      'items': [
        {'variant_id': 'v1', 'quantity': 1},
      ],
    });
    await offline.mutate('DELETE', '/reservations/${result['id']}', {});
    offline.offline = false;
    await offline.sync();
    expect(sent.length, 2);
    expect(sent.last['path'], startsWith('/reservations/server-'));
  });
  test('queue survives closing and reopening SQLite', () async {
    final folder = await Directory.systemTemp.createTemp('vesta-offline-test-');
    final path = '${folder.path}/test.db';
    final durable = await OfflineStore.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    await durable.db.insert('outbox', {
      'owner': 'api|u1',
      'id': 'test-uuid',
      'method': 'PUT',
      'path': '/users/me',
      'body': '{}',
      'created_at': '2026-10-19',
    });
    await durable.db.close();
    final reopened = await OfflineStore.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    expect((await reopened.queue('api|u1')).single['id'], 'test-uuid');
    await reopened.db.close();
    if (folder.absolute.path.startsWith(Directory.systemTemp.absolute.path)) {
      await folder.delete(recursive: true);
    }
  });

  test(
    'approved payment capture stays pending offline and uses the same queue',
    () async {
      await store.write('api|u1', '/reservations', [
        {
          'id': 'r1',
          'paypal_order_id': 'order1',
          'status': 'PENDING',
          'payment_status': 'PENDING',
        },
      ]);
      final result = await offline.mutate(
        'POST',
        '/reservations/paypal-capture',
        {'paypal_order_id': 'order1'},
      );
      expect(result['reservation']['payment_status'], 'SYNC_PENDING');
      expect(offline.pendingCount, 1);
      expect(sent, isEmpty);
      expect(
        (await offline.cached('/reservations'))[0]['payment_status'],
        'SYNC_PENDING',
      );
    },
  );
}
