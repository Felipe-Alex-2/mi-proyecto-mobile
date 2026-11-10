import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mobile/servicios/almacen_sin_conexion.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/autenticacion_service.dart';
import 'package:mobile/servicios/carrito_service.dart';
import 'package:mobile/servicios/recomendacion_service.dart';
import 'package:mobile/servicios/sin_conexion_service.dart';

class ScenarioStorage extends AlmacenamientoService {
  bool signedIn = false;
  String? local;
  @override
  Future<bool> hasToken() async => signedIn;
  @override
  Future<String?> getAccessToken() async => signedIn ? 'test-token' : null;
  @override
  Future<String?> getRefreshToken() async => 'test-refresh';
  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    signedIn = true;
  }

  @override
  Future<String?> getLocalUser() async => local;
  @override
  Future<void> saveLocalUser(String json) async {
    local = json;
  }

  @override
  Future<void> saveSyncOwner(String owner) async {}
}

Future<void> until(bool Function() condition) async {
  final limit = DateTime.now().add(const Duration(seconds: 20));
  while (!condition()) {
    if (DateTime.now().isAfter(limit)) {
      throw TimeoutException('No terminó el flujo offline');
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
}

Future<void> purchaseScenario(
  String payment, {
  DatabaseFactory? factory,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'vesta-purchase-test-',
  );
  final store = await AlmacenSinConexion.open(
    factory: factory,
    path: '${directory.path}/scenario.db',
  );
  var connected = true;
  var balance = 100.0;
  final commands = <String>{};
  var syncRequests = 0;
  final user = {
    'id': 'client',
    'role': 'CUSTOMER',
    'tenant_id': 'company',
    'selected_tenant_id': 'company',
    'branch_id': 'branch',
    'email': 'test@example.com',
    'full_name': 'Cliente Offline',
    'created_at': '2026-11-09T00:00:00Z',
    'updated_at': '2026-11-09T00:00:00Z',
  };
  final products = [
    {
      'id': 'p1',
      'name': 'Pantalón Azul',
      'category': 'Pantalones',
      'price': 15,
      'image_url': 'data:image/jpeg;base64,${'A' * (3 * 1024 * 1024)}',
      'variants': [
        {
          'id': 'v1',
          'size': 'M',
          'color': 'Azul',
          'price': 15,
          'stocks': [
            {'branch_id': 'branch', 'quantity': 100},
          ],
        },
      ],
    },
  ];
  final reservations = <Map<String, dynamic>>[
    {'id': 'old', 'status': 'CONFIRMED', 'items': []},
  ];
  final storage = ScenarioStorage();
  final api = ApiService(
    storage,
    client: MockClient((request) async {
      if (!connected) throw http.ClientException('Sin conexión');
      final path = request.url.path;
      dynamic result = {};
      if (path.endsWith('/auth/login')) {
        result = {
          'user': user,
          'access_token': 'test-token',
          'refresh_token': 'test-refresh',
        };
      } else if (path.endsWith('/users/me')) {
        result = user;
      } else if (path.endsWith('/products')) {
        result = products;
      } else if (path.endsWith('/cart')) {
        result = {'items': [], 'total_items': 0, 'total_amount': 0};
      } else if (path.endsWith('/wallet')) {
        result = {'balance': balance, 'currency': 'USD'};
      } else if (path.endsWith('/reservations')) {
        result = reservations;
      } else if (path.endsWith('/branches')) {
        result = [
          {'id': 'branch', 'name': 'Sucursal'},
        ];
      } else if (path.endsWith('/notifications') ||
          path.endsWith('/sessions')) {
        result = [];
      } else if (path.endsWith('/sync/operations')) {
        final command = jsonDecode(request.body) as Map;
        syncRequests++;
        expect(
          commands.add(command['operation_id'] as String),
          isTrue,
          reason: 'Cada operación se procesa una vez',
        );
        if (command['path'] == '/cart/items') {
          result = {
            'items': [
              {
                'id': 'server-item',
                'variant_id': 'v1',
                'quantity': 1,
                'price': 15,
              },
            ],
            'total_items': 1,
            'total_amount': 15,
          };
        } else {
          if (payment == 'WALLET') balance -= 15;
          result = {
            'id': 'new-reservation',
            'status': payment == 'WALLET' ? 'CONFIRMED' : 'PENDING',
            'payment_method': payment,
            'payment_status': payment == 'WALLET' ? 'PAID' : 'PENDING',
            'wallet_balance': balance,
            'total_amount': 15,
            'items': [],
          };
          reservations.add(Map<String, dynamic>.from(result));
        }
      }
      return http.Response(
        jsonEncode(result),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  final offline = SinConexionService(
    store,
    (method, path, body) => api.sendOnline(method, path, body),
    internetCheck: () async => connected,
  );
  api.offline = offline;
  final auth = AutenticacionService(api, storage, offline: offline);
  final cart = CarritoService(api);
  final assistant = RecomendacionService(api);
  try {
    await until(() => auth.status != AuthStatus.uninitialized);
    expect(await auth.login('test@example.com', 'test'), isTrue);
    await until(() => offline.offlineReady && !offline.downloadingData);
    await offline.sync();
    expect(
      (await store.read(offline.owner!, '/offline/manifest'))['ready'],
      true,
    );
    connected = false;
    await offline.refreshConnection();
    expect((await api.get('/reservations') as List).single['id'], 'old');
    expect(
      (await assistant.getRecommendations('Me gusta el azul'))!
          .recommendations
          .single
          .id,
      'p1',
    );
    expect(
      (await assistant.getRecommendations('¿Cómo pago sin Internet?'))!.message,
      contains('pendiente'),
    );
    await cart.addToCart('v1');
    expect(cart.cart!.totalAmount, 15);
    final result = await api.post(
      '/reservations',
      body: {
        'branch_id': 'branch',
        'payment_method': payment,
        'request_id': '7c42e835-a6d8-4987-96aa-833305070b62',
        'items': [
          {'variant_id': 'v1', 'quantity': 1},
        ],
      },
    );
    expect(result['status'], 'SYNC_PENDING');
    expect(offline.pendingCount, 2);
    expect(syncRequests, 0);
    expect(
      (await offline.cached('/wallet'))['balance'],
      payment == 'WALLET' ? 85 : 100,
    );
    expect((await offline.cached('/reservations') as List).length, 2);
    // Reconnect uses the same lifecycle hook registered in the actual app.
    connected = true;
    offline.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await until(() => offline.pendingCount == 0 && !offline.syncing);
    expect(syncRequests, 2);
    expect(reservations.length, 2);
    expect(balance, payment == 'WALLET' ? 85 : 100);
    expect(
      (await offline.cached('/reservations') as List).any(
        (r) => r['id'] == 'new-reservation',
      ),
      true,
    );
    await offline.sync();
    expect(syncRequests, 2);
  } finally {
    auth.dispose();
    cart.dispose();
    assistant.dispose();
    offline.dispose();
    api.dispose();
    await store.db.close();
    await directory.delete(recursive: true);
  }
}

Future<void> concurrentReadScenario({DatabaseFactory? factory}) async {
  final directory = await Directory.systemTemp.createTemp('vesta-wal-test-');
  final path = '${directory.path}/locks.db';
  final reader = await AlmacenSinConexion.open(factory: factory, path: path);
  final writer = await AlmacenSinConexion.open(factory: factory, path: path);
  final locked = Completer<void>(), release = Completer<void>();
  final data = [
    {'name': 'Azul', 'image': 'A' * (3 * 1024 * 1024)},
  ];
  await reader.write('owner', '/products', data);
  await reader.db.insert('outbox', {
    'owner': 'owner',
    'id': 'before',
    'method': 'POST',
    'path': '/cart/items',
    'body': '{}',
    'preview': 'null',
    'created_at': 'now',
  });
  final writing = writer.transaction((tx) async {
    await writer.write('owner', '/products', [
      {'name': 'Not yet committed'},
    ], tx: tx);
    locked.complete();
    await release.future;
  });
  try {
    await locked.future;
    expect(
      await reader
          .read('owner', '/products')
          .timeout(const Duration(seconds: 3)),
      data,
    );
    expect(
      (await reader.queue('owner').timeout(const Duration(seconds: 3)))
          .single['id'],
      'before',
    );
  } finally {
    release.complete();
    await writing;
    await reader.db.close();
    await writer.db.close();
    await directory.delete(recursive: true);
  }
}
