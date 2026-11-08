import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:mobile/modelos/usuario.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/autenticacion_service.dart';
import 'package:mobile/servicios/reserva_service.dart';
import 'package:mobile/widgets/opciones_entrega.dart';
import 'package:mobile/configuracion/tema.dart';

class Storage extends AlmacenamientoService {
  @override
  Future<String?> getAccessToken() async => 'test';
}

class Auth extends AutenticacionService {
  Auth(super.api, super.storage);
  @override
  Usuario get currentUser => Usuario.fromJson({
    'id': 'client',
    'full_name': 'Felipe Cliente',
    'email': 'test@example.com',
    'phone': '70001234',
    'created_at': '2026-11-08',
    'updated_at': '2026-11-08',
  });
}

http.Response jsonResult(dynamic value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUpAll(() async {
    for (final (family, asset) in [
      ('VestaBody', 'assets/fonts/Roboto-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  testWidgets(
    'delivery prefills contact, quotes in USD and invalidates an edited destination',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = Storage();
      var calls = 0;
      final api = ApiService(
        storage,
        client: MockClient((r) async {
          calls++;
          expect(r.url.path, endsWith('/own/deliveries/quote'));
          expect(jsonDecode(r.body)['branch_id'], 'branch');
          return jsonResult({
            'id': 'quote',
            'fee_usd': 1.44,
            'fee_bob': 10,
            'bob_per_usd': 6.96,
            'branch_name': 'Central',
            'distance_km': 2.5,
            'estimated_minutes_min': 25,
            'estimated_minutes_max': 35,
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 10))
                .toIso8601String(),
            'directions_url': 'https://www.google.com/maps/dir/?api=1',
          });
        }),
      );
      final auth = Auth(api, storage);
      final key = GlobalKey<OpcionesEntregaState>();
      final screenKey = GlobalKey();
      addTearDown(api.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: api),
            ChangeNotifierProvider<AutenticacionService>.value(value: auth),
          ],
          child: MaterialApp(
            theme: TemaApp.lightTheme,
            home: RepaintBoundary(
              key: screenKey,
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: OpcionesEntrega(
                    key: key,
                    branchId: 'branch',
                    enabled: true,
                    onChanged: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(key.currentState!.validatedPayload(), isNull);
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delivery a mi ubicación').last);
      await tester.pumpAndSettle();
      expect(find.text('Felipe Cliente'), findsOneWidget);
      expect(find.text('70001234'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(2), 'Calle 123 puerta azul');
      await tester.enterText(
        fields.at(3),
        'https://www.google.com/maps?q=-17.8,-63.2',
      );
      final calculate = find.text('Calcular envío y tiempo');
      await tester.ensureVisible(calculate);
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(key.currentState!.fee, 1.44);
      expect(
        key.currentState!.validatedPayload(),
        containsPair('delivery_phone', '70001234'),
      );
      expect(find.textContaining('Envío: USD 1.44'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('Envío: USD 1.44'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render =
            screenKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/design-previews/delivery-checkout.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.enterText(
        fields.at(3),
        'https://www.google.com/maps?q=-17.9,-63.1',
      );
      await tester.pump();
      expect(key.currentState!.fee, 0);
      expect(() => key.currentState!.validatedPayload(), throwsException);
    },
  );

  test(
    'wallet and PayPal send delivery data through online reservation checkout',
    () async {
      final requests = <Map<String, dynamic>>[];
      final api = ApiService(
        Storage(),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/paypal-order')) {
            return jsonResult({
              'order_id': 'order',
              'approval_url':
                  'https://www.sandbox.paypal.com/checkoutnow?token=order',
            });
          }
          final body = Map<String, dynamic>.from(jsonDecode(r.body));
          requests.add(body);
          return jsonResult({
            'id': 'reservation',
            'items': [],
            'status': 'CONFIRMED',
            'total_amount': 51.44,
            'delivery_fee': 1.44,
            'delivery': {'status': 'REQUESTED'},
          });
        }),
      );
      final service = ReservaService(api);
      addTearDown(service.dispose);
      addTearDown(api.dispose);
      final delivery = {
        'fulfillment': 'DELIVERY',
        'delivery_quote_id': 'quote',
        'delivery_recipient': 'Felipe',
        'delivery_phone': '70001234',
        'delivery_address': 'Calle 123',
      };
      final result = await service.createReservation(
        branchId: 'branch',
        items: [
          {'variant_id': 'v', 'quantity': 1},
        ],
        paymentMethod: 'WALLET',
        idempotencyKey: 'request',
        delivery: delivery,
      );
      expect(result.deliveryFee, 1.44);
      expect(result.delivery!['status'], 'REQUESTED');
      await service.createPayPalReservationOrder(
        branchId: 'branch',
        items: [
          {'variant_id': 'v', 'quantity': 1},
        ],
        delivery: delivery,
      );
      expect(requests.map((r) => r['payment_method']), ['WALLET', 'PAYPAL']);
      for (final body in requests) {
        expect(body['delivery_quote_id'], 'quote');
        expect(body['fulfillment'], 'DELIVERY');
      }
    },
  );
}
