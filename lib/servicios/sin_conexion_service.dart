import '../modelos/venta_mayor.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'api_service.dart';
import 'almacen_sin_conexion.dart';
import 'sincronizacion_segundo_plano.dart';

import 'package:sqflite/sqflite.dart';

typedef OnlineSender = Future<dynamic> Function(
  String method,
  String path,
  Map<String, dynamic> body,
);

class SinConexionService extends ChangeNotifier with WidgetsBindingObserver {
  final AlmacenSinConexion store;
  final OnlineSender send;
  String? owner;
  bool offline = false;
  bool syncing = false;
  bool needsLogin = false;
  int revision = 0;
  List<Map<String, Object?>> operations = [];
  StreamSubscription<List<ConnectivityResult>>? _connection;
  Timer? _timer;
  Future<void>? _syncTask;
  Future<void> _mutationTail = Future.value();
  SinConexionService(this.store, this.send);
  int get pendingCount => operations.length;
  bool get hasFailures => operations.any((r) => r['state'] == 'blocked');

  void start() {
    WidgetsBinding.instance.addObserver(this);
    final connectivity = Connectivity();
    _connection = connectivity.onConnectivityChanged.listen(_connectivity);
    connectivity.checkConnectivity().then(_connectivity).catchError((_) {});
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(sync()),
    );
  }

  void _connectivity(List<ConnectivityResult> results) {
    offline = results.every((r) => r == ConnectivityResult.none);
    notifyListeners();
    if (!offline) unawaited(sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(sync());
  }

  Future<void> activate(String key) async {
    owner = key;
    needsLogin = false;
    await refresh();
  }

  void deactivate() {
    owner = null;
    operations = [];
    notifyListeners();
  }

  Future<void> refresh() async {
    final account = owner;
    final rows = account == null
        ? <Map<String, Object?>>[]
        : (await store.db.query('outbox', orderBy: 'seq ASC'))
              .where((row) => _sameAccount(row['owner'] as String, account))
              .toList();
    if (account != owner) return;
    operations = rows;
    revision++;
    notifyListeners();
  }

  static bool supports(String method, String path) =>
      (method == 'POST' &&
          (path == '/virtual-fitting/profile' ||
              path == '/reservations' ||
              path == '/cart/items' ||
              path == '/reservations/paypal-capture')) ||
      (method == 'PATCH' && path.startsWith('/notifications/')) ||
      (method == 'PUT' &&
          (path == '/users/me' || path.startsWith('/cart/items/'))) ||
      (method == 'DELETE' &&
          (path == '/cart' ||
              path.startsWith('/cart/items/') ||
              path.startsWith('/reservations/')));

  Future<dynamic> read(String path, Future<dynamic> Function() load) async {
    final account = owner;
    if (account == null) return load();
    dynamic base;
    try {
      if (offline) throw ApiException('Sin conexión', statusCode: 0);
      base = await load();
      if (account != owner) {
        throw ApiException('La sesión cambió', statusCode: 401);
      }
      offline = false;
      await store.write(account, path, base);
    } on ApiException catch (e) {
      if (e.statusCode != 0 && e.statusCode != 408 && e.statusCode < 500) {
        rethrow;
      }
      offline = true;
      notifyListeners();
      base = await store.read(account, path);
      if (base == null && path.startsWith('/products/')) {
        final products = await store.read(account, '/products') as List? ?? [];
        for (final p in products) {
          if (p['id'] == path.split('/').last) base = p;
        }
      }
      if (base == null && path == '/cart') {
        base = {'items': [], 'total_items': 0, 'total_amount': 0};
      }
      if (base == null &&
          (path == '/reservations' ||
              path == '/notifications' ||
              path == '/virtual-fitting/sessions')) {
        base = [];
      }
      if (base == null && path == '/virtual-fitting/profile') base = {};
      if (base == null) {
        throw ApiException(
          'Sin conexión. Abre esta sección con internet una vez para guardarla en el dispositivo.',
          statusCode: 0,
        );
      }
    }
    if (account != owner) {
      throw ApiException('La sesión cambió', statusCode: 401);
    }
    return _project(account, path, base);
  }

  Future<dynamic> cached(String path) async {
    final account = owner;
    if (account == null) return null;
    final base = await store.read(account, path);
    return base == null && path != '/virtual-fitting/profile'
        ? null
        : _project(account, path, base);
  }

  Future<dynamic> _project(String account, String path, dynamic base) async {
    dynamic result = jsonDecode(jsonEncode(base));
    var pending = await store.queue(account);
    if (path == '/reservations') {
      final rows = await store.db.query('outbox', orderBy: 'seq ASC');
      pending = rows
          .where((r) => _sameAccount(r['owner'] as String, account))
          .toList();
    }
    for (final row in pending) {
      final target = row['path'] as String;
      final body = jsonDecode(row['body'] as String) as Map<String, dynamic>;
      if (path == '/virtual-fitting/profile' && target == path) {
        result = {
          ...Map<String, dynamic>.from(result as Map? ?? {}),
          ...body,
          '_sync_pending': true,
        };
      }
      if (path == '/notifications' && target.startsWith('/notifications/')) {
        result = (result as List)
            .map(
              (r) =>
                  target.endsWith('/read-all') ||
                      r['id'] == target.split('/')[2]
                  ? {...Map<String, dynamic>.from(r as Map), 'is_read': true}
                  : r,
            )
            .toList();
      }
      if (path == '/users/me' && target == path) {
        result = {
          ...Map<String, dynamic>.from(result as Map),
          ...body,
          '_sync_pending': true,
        };
      }
      if (path == '/cart' && target.startsWith('/cart')) {
        result = await _cartProjection(
          account,
          result,
          row['method'] as String,
          target,
          body,
        );
      }
      if (path == '/reservations' && target == '/reservations') {
        final preview =
            jsonDecode(row['preview'] as String) as Map<String, dynamic>;
        result = [
          {
            ...preview,
            'status': row['state'] == 'blocked'
                ? 'SYNC_FAILED'
                : 'SYNC_PENDING',
            'staff_notes': row['error'],
          },
          ...result as List,
        ];
      }
      if (path == '/reservations' && target == '/reservations/paypal-capture') {
        result = (result as List)
            .map(
              (r) =>
                  r['paypal_order_id'] ==
                      (body['paypal_order_id'] ?? body['order_id'])
                  ? {
                      ...Map<String, dynamic>.from(r as Map),
                      'payment_status': 'SYNC_PENDING',
                    }
                  : r,
            )
            .toList();
      }
      if (path == '/reservations' &&
          target.startsWith('/reservations/') &&
          row['method'] == 'DELETE') {
        result = (result as List)
            .map(
              (r) => r['id'] == target.split('/').last
                  ? {
                      ...Map<String, dynamic>.from(r as Map),
                      'status': 'CANCEL_PENDING',
                    }
                  : r,
            )
            .toList();
      }
    }
    return result;
  }

  Future<dynamic> mutate(
    String method,
    String path,
    Map<String, dynamic> body,
  ) {
    final result = Completer<dynamic>();
    final account = owner;
    _mutationTail = _mutationTail.then((_) async {
      try {
        result.complete(await _enqueue(account, method, path, body));
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }

  Future<dynamic> _enqueue(
    String? account,
    String method,
    String path,
    Map<String, dynamic> input,
  ) async {
    if (account == null || account != owner) {
      throw ApiException('Inicia sesión para guardar cambios', statusCode: 401);
    }
    final body = Map<String, dynamic>.from(input);
    if (path.startsWith('/cart/items/') && method != 'POST') {
      final cart = await _project(
        account,
        '/cart',
        await store.read(account, '/cart') ?? {'items': []},
      );
      final items = cart['items'] as List;
      final matching = items.where((r) => r['id'] == path.split('/').last);
      if (matching.isNotEmpty) {
        body['_variant_id'] = matching.first['variant_id'];
      }
    }
    if (body['quantity'] is num &&
        ((body['quantity'] as num) < 1 || (body['quantity'] as num) > 1000)) {
      throw ApiException(
        'La cantidad debe estar entre 1 y 1000',
        statusCode: 422,
      );
    }
    if (path == '/reservations' &&
        ((body['items'] as List?)?.isEmpty ?? true)) {
      throw ApiException('Selecciona al menos una prenda', statusCode: 422);
    }
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    final now = DateTime.now().toUtc();
    Map<String, dynamic>? preview;
    if (path == '/reservations') {
      final cart = await _project(
        account,
        '/cart',
        await store.read(account, '/cart') ?? {'items': []},
      );
      final cartItems = cart['items'] as List;
      final items = (body['items'] as List).map((item) {
        final found = cartItems.where(
          (v) => v['variant_id'] == item['variant_id'],
        );
        return {
          ...(found.isEmpty
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(found.first)),
          ...Map<String, dynamic>.from(item),
        };
      }).toList();
      preview = {
        'id': 'local:$id',
        'reservation_code': 'Pendiente de envío',
        'tenant_id': account.split('|').length >= 4
            ? account.split('|')[1]
            : null,
        'company_name': (await store.read(
          account,
          '/users/me',
        ))?['company_name'],
        'branch_name': (await store.read(account, '/users/me'))?['branch_name'],
        'customer_id': account.split('|').last,
        ...body,
        'created_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(hours: 48)).toIso8601String(),
        'items': items,
        'total_items': items.fold<int>(0, (n, i) => n + (i['quantity'] as int)),
        ...resumenVentaMayor(
          items.fold<double>(
            0,
            (n, i) => n + (i['price'] as num? ?? 0) * (i['quantity'] as int),
          ),
          items.fold<int>(0, (n, i) => n + (i['quantity'] as int)),
        ),
        'total_estimated_amount': resumenVentaMayor(
          items.fold<double>(
            0,
            (n, i) => n + (i['price'] as num? ?? 0) * (i['quantity'] as int),
          ),
          items.fold<int>(0, (n, i) => n + (i['quantity'] as int)),
        )['total_amount'],
        'payment_status': 'PENDING',
        'status': 'SYNC_PENDING',
      };
    }
    if (path == '/reservations/paypal-capture') {
      final reservations = await cached('/reservations') as List? ?? [];
      final matching = reservations.where(
        (r) =>
            r['paypal_order_id'] ==
            (body['paypal_order_id'] ?? body['order_id']),
      );
      if (matching.isEmpty) {
        throw ApiException(
          'Abre tus reservas con conexión antes de guardar este pago pendiente.',
          statusCode: 422,
        );
      }
      preview = Map<String, dynamic>.from(matching.first);
      preview['payment_status'] = 'SYNC_PENDING';
    }
    await store.db.insert('outbox', {
      'owner': account,
      'id': id,
      'method': method,
      'path': path,
      'body': jsonEncode(body),
      'preview': jsonEncode(preview),
      'created_at': now.toIso8601String(),
    });
    await refresh();
    await SincronizacionSegundoPlano.schedule();
    if (!offline) await sync();
    final receipt = await store.read(account, 'receipt:$id');
    if (receipt != null) return receipt;
    if (path == '/reservations/paypal-capture') {
      return {'reservation': preview, 'status': 'PENDING_SYNC'};
    }
    if (path == '/reservations') {
      return {
        ...preview!,
        'status':
            operations.any((o) => o['id'] == id && o['state'] == 'blocked')
            ? 'SYNC_FAILED'
            : 'SYNC_PENDING',
      };
    }
    if (path == '/virtual-fitting/profile') {
      return _project(account, path, await store.read(account, path));
    }
    if (path.startsWith('/notifications/')) return {'queued': true};
    if (path.startsWith('/reservations/')) {
      final rows = await _project(
        account,
        '/reservations',
        await store.read(account, '/reservations') ?? [],
      );
      return (rows as List).firstWhere((r) => r['id'] == path.split('/').last);
    }
    final key = path.startsWith('/cart') ? '/cart' : '/users/me';
    return _project(
      account,
      key,
      await store.read(account, key) ?? {'items': []},
    );
  }

  Future<Map<String, dynamic>> _cartProjection(
    String account,
    dynamic source,
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final items = List<Map<String, dynamic>>.from(
      (source['items'] as List? ?? []).map((r) => Map<String, dynamic>.from(r)),
    );
    if (path == '/cart' && method == 'DELETE') items.clear();
    if (path == '/cart/items' && method == 'POST') {
      final variant = body['variant_id'];
      final idx = items.indexWhere((r) => r['variant_id'] == variant);
      if (idx >= 0) {
        items[idx]['quantity'] =
            (items[idx]['quantity'] as int) + (body['quantity'] as int? ?? 1);
      } else {
        final products = await store.read(account, '/products') as List? ?? [];
        Map<String, dynamic> meta = {};
        for (final p in products) {
          for (final v in p['variants'] as List? ?? []) {
            if (v['id'] == variant) {
              meta = {
                ...Map<String, dynamic>.from(v),
                'product_id': p['id'],
                'product_name': p['name'],
                'image_url': p['image_url'],
                'price': v['price'] ?? p['price'] ?? 0,
              };
            }
          }
        }
        items.add({
          ...meta,
          'id': 'local:$variant',
          'variant_id': variant,
          'quantity': body['quantity'] ?? 1,
          'available_stock': meta['total_stock'] ?? 0,
        });
      }
    }
    if (path.startsWith('/cart/items/') && method != 'POST') {
      final match = items.indexWhere(
        (r) => body['_variant_id'] != null
            ? r['variant_id'] == body['_variant_id']
            : r['id'] == path.split('/').last,
      );
      if (match >= 0) {
        if (method == 'DELETE') {
          items.removeAt(match);
        } else {
          items[match]['quantity'] = body['quantity'];
        }
      }
    }
    for (final item in items) {
      item['subtotal'] =
          (item['price'] as num? ?? 0) * (item['quantity'] as int);
    }
    return {
      'items': items,
      'total_items': items.fold<int>(0, (n, i) => n + (i['quantity'] as int)),
      ...resumenVentaMayor(
        items.fold<double>(0, (n, i) => n + (i['subtotal'] as num)),
        items.fold<int>(0, (n, i) => n + (i['quantity'] as int)),
      ),
      '_sync_pending': true,
    };
  }

  Future<void> sync() =>
      _syncTask ??= _drain().whenComplete(() => _syncTask = null);
  bool _sameAccount(String a, String b) {
    final aa = a.split('|'), bb = b.split('|');
    return aa.first == bb.first && aa.last == bb.last;
  }

  Future<void> _drain() async {
    final activeOwner = owner;
    if (activeOwner == null) return;
    final rows = await store.db.query(
      'outbox',
      columns: ['owner'],
      distinct: true,
      orderBy: 'seq ASC',
    );
    final owners = <String>{
      activeOwner,
      ...rows
          .map((r) => r['owner'] as String)
          .where((key) => _sameAccount(key, activeOwner)),
    };
    for (final account in owners) {
      if (owner != activeOwner || needsLogin) break;
      await _drainContext(account, activeOwner);
    }
  }

  Future<void> _drainContext(String account, String activeOwner) async {
    if (needsLogin) return;
    if (offline) {
      try {
        await send('GET', '/users/me', {});
        offline = false;
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          needsLogin = true;
          notifyListeners();
        }
        return;
      } catch (_) {
        return;
      }
    }
    syncing = true;
    notifyListeners();
    try {
      for (final row in await store.queue(account)) {
        if (owner != activeOwner || needsLogin) break;
        if (row['state'] == 'blocked') {
          break; // Strict FIFO: dependents never overtake a conflict.
        }
        var path = row['path'] as String;
        if (path.startsWith('/reservations/local:')) {
          final local = path.substring('/reservations/'.length);
          final remote = await store.resolve(account, local);
          if (remote == local) break;
          path = '/reservations/$remote';
        }
        try {
          final result = await send('POST', '/sync/operations', {
            'operation_id': row['id'],
            'account_id': account.split('|').last,
            if (account.split('|').length >= 4)
              'tenant_id': account.split('|')[1],
            if (account.split('|').length >= 4 &&
                account.split('|')[2].isNotEmpty)
              'branch_id': account.split('|')[2],
            if (account.split('|').length == 2)
              'tenant_id': '00000000-0000-0000-0000-000000000001',
            'method': row['method'],
            'path': path,
            'body': jsonDecode(row['body'] as String),
          });
          await store.db.transaction((tx) async {
            await store.write(account, 'receipt:${row['id']}', result, tx: tx);
            if (path.startsWith('/cart')) {
              await store.write(account, '/cart', result, tx: tx);
            }
            if (path == '/virtual-fitting/profile') {
              await store.write(account, path, result, tx: tx);
            }
            if (path.startsWith('/notifications/')) {
              final rows = await tx.query(
                'cache',
                where: 'owner=? AND path=?',
                whereArgs: [account, '/notifications'],
              );
              if (rows.isNotEmpty) {
                final notifications =
                    jsonDecode(rows.first['data'] as String) as List;
                await store.write(
                  account,
                  '/notifications',
                  notifications
                      .map(
                        (r) =>
                            path.endsWith('/read-all') ||
                                r['id'] == path.split('/')[2]
                            ? {
                                ...Map<String, dynamic>.from(r as Map),
                                'is_read': true,
                              }
                            : r,
                      )
                      .toList(),
                  tx: tx,
                );
              }
            }
            if (path == '/users/me') {
              await store.write(account, path, result, tx: tx);
            }
            if (path.startsWith('/reservations')) {
              final reservation = result['reservation'] ?? result;
              final rows = await tx.query(
                'cache',
                where: 'owner=? AND path=?',
                whereArgs: [account, '/reservations'],
              );
              final list = rows.isEmpty
                  ? <dynamic>[]
                  : jsonDecode(rows.first['data'] as String) as List;
              list.removeWhere((r) => r['id'] == reservation['id']);
              list.insert(0, reservation);
              await store.write(account, '/reservations', list, tx: tx);
              if (path == '/reservations') {
                await tx.insert('id_map', {
                  'owner': account,
                  'local_id': 'local:${row['id']}',
                  'remote_id': result['id'],
                }, conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
            await tx.delete(
              'outbox',
              where: 'id=? AND owner=?',
              whereArgs: [row['id'], account],
            );
          });
          offline = false;
        } on ApiException catch (e) {
          if (e.statusCode == 401) {
            needsLogin = true;
            break;
          }
          if (e.statusCode == 0 || e.statusCode == 408) {
            offline = true;
            break;
          }
          if (e.statusCode >= 500 || e.statusCode == 429) break;
          await store.db.update(
            'outbox',
            {'state': 'blocked', 'error': e.message},
            where: 'id=? AND owner=?',
            whereArgs: [row['id'], account],
          );
          break;
        } catch (_) {
          break;
        }
      }
    } finally {
      syncing = false;
      await refresh();
    }
  }

  Future<void> retry() async {
    if (owner == null) return;
    for (final row in operations) {
      await store.db.update(
        'outbox',
        {'state': 'pending', 'error': null},
        where: 'id=? AND owner=?',
        whereArgs: [row['id'], row['owner']],
      );
    }
    offline = false;
    await sync();
  }

  Future<void> discardFrom(int seq) async {
    if (owner == null || syncing) return;
    final target = operations.where((r) => r['seq'] == seq).firstOrNull;
    if (target == null) return;
    // Discard dependents only in the original company/branch context.
    await store.db.delete(
      'outbox',
      where: 'owner=? AND seq>=?',
      whereArgs: [target['owner'], seq],
    );
    await refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _connection?.cancel();
    super.dispose();
  }
}
