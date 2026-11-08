import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';
import 'package:mobile/pantallas/perfil/puntos_screen.dart';

class _Storage extends AlmacenamientoService {
  @override
  Future<String?> getAccessToken() async => 'token';
}

void main() {
  testWidgets(
    'shows affordable rewards and spends 10 points for in-store mystery pickup',
    (tester) async {
      var balance = 10;
      var redeemed = false;
      final api = ApiService(
        _Storage(),
        client: MockClient((request) async {
          if (request.method == 'POST') {
            final body = jsonDecode(request.body);
            expect(body['reward'], 'MYSTERY');
            expect(body['request_id'], matches(RegExp(r'^[a-f0-9-]{36}$')));
            balance = 0;
            redeemed = true;
            return http.Response('{}', 201);
          }
          return http.Response(
            jsonEncode({
              'balance': balance,
              'options': [
                {
                  'id': 'MYSTERY',
                  'name': 'Caja de prenda misteriosa',
                  'points': 10,
                },
                {'id': 'COUPON_7', 'name': 'Cupón 7%', 'points': 5},
              ],
              'rewards': redeemed
                  ? [
                      {
                        'id': 'r',
                        'reward_type': 'MYSTERY',
                        'status': 'AVAILABLE',
                        'code': 'VESTA-PRIVATE',
                        'expires_at': '2099-12-30T12:00:00Z',
                      },
                    ]
                  : [],
              'entries': [],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(
        Provider.value(
          value: api,
          child: const MaterialApp(home: PuntosScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('10 puntos disponibles'), findsOneWidget);
      expect(find.textContaining('USD 10'), findsOneWidget);
      await tester.tap(find.text('Canjear 10 puntos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('exclusivamente en sucursal'), findsOneWidget);
      await tester.tap(find.text('Canjear'));
      await tester.pumpAndSettle();
      expect(redeemed, isTrue);
      expect(find.text('0 puntos disponibles'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Canjear 10 puntos'),
      );
      expect(button.onPressed, isNull);
      await tester.scrollUntilVisible(find.text('VESTA-PRIVATE'), 300);
      expect(find.text('VESTA-PRIVATE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed redemption keeps points and offers an error', (
    tester,
  ) async {
    final api = ApiService(
      _Storage(),
      client: MockClient(
        (request) async => request.method == 'POST'
            ? http.Response(
                jsonEncode({'detail': 'Necesitas 5 puntos disponibles.'}),
                409,
                headers: {'content-type': 'application/json; charset=utf-8'},
              )
            : http.Response(
                jsonEncode({
                  'balance': 5,
                  'options': [
                    {'id': 'COUPON_7', 'name': 'Cupón 7%', 'points': 5},
                  ],
                  'rewards': [],
                  'entries': [],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
      ),
    );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: const MaterialApp(home: PuntosScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canjear 5 puntos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canjear'));
    await tester.pumpAndSettle();
    expect(find.text('5 puntos disponibles'), findsOneWidget);
    expect(find.text('Necesitas 5 puntos disponibles.'), findsOneWidget);
  });
}
