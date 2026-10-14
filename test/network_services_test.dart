import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/cart_service.dart';
import 'package:mobile/services/notification_service.dart';
import 'package:mobile/services/reservation_service.dart';
import 'package:mobile/services/storage_service.dart';

class _Storage extends StorageService {
  @override
  Future<String?> getAccessToken() async => 'test-token';
}

class _ControlledApi extends ApiService {
  _ControlledApi() : super(_Storage());
  int calls = 0;
  final response = Completer<dynamic>();
  @override
  Future<dynamic> get(String endpoint, {bool includeAuth = true}) {
    calls++;
    return response.future;
  }
}

void main() {
  test(
    'uses one client for JSON and multipart with correct auth headers',
    () async {
      final methods = <String>[];
      final client = MockClient((request) async {
        methods.add(request.method);
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response('{}', 200);
      });
      final api = ApiService(_Storage(), client: client);
      addTearDown(api.dispose);
      await api.get('/products');
      await api.post('/cart', body: {'quantity': 1});
      await api.put('/users/me', body: {});
      await api.patch('/notifications/read-all');
      await api.delete('/cart');
      await api.postMultipart(
        '/virtual-fitting/idm-tryon',
        fileFields: {
          'person_image': {
            'bytes': [1, 2],
            'filename': 'person.jpg',
            'contentType': 'image/jpeg',
          },
        },
      );
      expect(methods, ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'POST']);
    },
  );

  test(
    'timeouts become a recoverable API error without retrying writes',
    () async {
      var calls = 0;
      final api = ApiService(
        _Storage(),
        requestTimeout: const Duration(milliseconds: 1),
        client: MockClient((request) {
          calls++;
          return Completer<http.Response>().future;
        }),
      );
      addTearDown(api.dispose);
      await expectLater(
        api.post('/cart'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 408)),
      );
      expect(calls, 1);
    },
  );

  test('keeps validation details and supports empty 204 responses', () async {
    final api = ApiService(
      _Storage(),
      client: MockClient(
        (request) async => request.method == 'DELETE'
            ? http.Response('', 204)
            : http.Response('{"detail":"Sin stock"}', 409),
      ),
    );
    addTearDown(api.dispose);
    expect(await api.delete('/cart'), isNull);
    await expectLater(
      api.post('/cart'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Sin stock')
            .having((e) => e.statusCode, 'status', 409),
      ),
    );
  });

  test('cart shares concurrent loads and exposes connection errors', () async {
    final api = _ControlledApi();
    addTearDown(api.dispose);
    final cart = CartService(api);
    addTearDown(cart.dispose);
    final first = cart.loadCart();
    final second = cart.loadCart();
    expect(identical(first, second), isTrue);
    expect(api.calls, 1);
    api.response.completeError(ApiException('Sin conexión'));
    await Future.wait([first, second]);
    expect(cart.errorMessage, 'Sin conexión');
    expect(cart.isLoading, isFalse);
    expect(cart.hasLoaded, isFalse);
  });

  test(
    'reservations share loads and safely finish after session disposal',
    () async {
      final api = _ControlledApi();
      addTearDown(api.dispose);
      final reservations = ReservationService(api);
      final first = reservations.loadReservations();
      final second = reservations.loadReservations();
      expect(api.calls, 1);
      reservations.dispose();
      api.response.complete([]);
      await Future.wait([first, second]);
    },
  );

  testWidgets(
    'notifications do not poll before an authenticated home starts them',
    (tester) async {
      final api = _ControlledApi();
      final notifications = NotificationService(api);
      await tester.pump(const Duration(seconds: 30));
      expect(api.calls, 0);
      notifications.dispose();
      api.dispose();
    },
  );

  test(
    'notification polling shares requests and discards results after logout',
    () async {
      final api = _ControlledApi();
      addTearDown(api.dispose);
      final notifications = NotificationService(api);
      addTearDown(notifications.dispose);
      final first = notifications.loadNotifications(silent: true);
      final second = notifications.loadNotifications(silent: true);
      expect(api.calls, 1);
      notifications.clearSession();
      api.response.complete([
        {'id': 'old-user', 'is_read': false},
      ]);
      await Future.wait([first, second]);
      expect(notifications.notifications, isEmpty);
    },
  );

  test('unchanged background notifications do not rebuild listeners', () async {
    final api = ApiService(
      _Storage(),
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(api.dispose);
    final notifications = NotificationService(api);
    addTearDown(notifications.dispose);
    var rebuilds = 0;
    notifications.addListener(() => rebuilds++);
    await notifications.loadNotifications(silent: true);
    await notifications.loadNotifications(silent: true);
    expect(rebuilds, 1);
  });
}
