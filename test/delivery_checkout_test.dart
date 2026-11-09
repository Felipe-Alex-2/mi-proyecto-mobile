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
import 'package:mobile/configuracion/tema.dart';
import 'package:mobile/modelos/usuario.dart';
import 'package:mobile/pantallas/carrito/carrito_screen.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/autenticacion_service.dart';
import 'package:mobile/servicios/carrito_service.dart';
import 'package:mobile/servicios/reserva_service.dart';
import 'package:mobile/widgets/opciones_entrega.dart';

class Storage extends AlmacenamientoService {
  @override
  Future<String?> getAccessToken() async => 'test';
}

class Auth extends AutenticacionService {
  Auth(super.api, super.storage);
  @override
  Usuario get currentUser => Usuario.fromJson({
    'id': 'client',
    'role': 'CUSTOMER',
    'branch_id': 'selected',
    'selected_tenant_id': 'company',
    'full_name': 'Felipe Cliente',
    'phone': '70001234',
    'email': 'cliente@example.com',
    'created_at': '2026-11-09',
    'updated_at': '2026-11-09',
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
      ('VestaEditorial', 'assets/fonts/CormorantGaramond.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  testWidgets(
    'Delivery is the fourth option, keeps the selected branch and leaves pickup payments independent',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Map<String, dynamic>>[];
      var quoteCalls = 0;
      final storage = Storage();
      final api =
          ApiService(
              storage,
              client: MockClient((r) async {
                if (r.url.path.endsWith('/cart')) {
                  return jsonResult({
                    'items': [
                      {
                        'id': 'item',
                        'variant_id': 'variant',
                        'product_name': 'Camisa',
                        'quantity': 1,
                        'price': 12,
                        'subtotal': 12,
                        'available_stock': 5,
                      },
                    ],
                    'total_items': 1,
                    'total_amount': 12,
                  });
                }
                if (r.url.path.endsWith('/branches')) {
                  return jsonResult([
                    {
                      'id': 'other',
                      'name': 'Primera de la lista',
                      'city': 'Santa Cruz',
                      'address': 'Otra dirección',
                    },
                    {
                      'id': 'selected',
                      'name': 'Sucursal elegida',
                      'city': 'Santa Cruz',
                      'address': 'Av. Principal',
                    },
                  ]);
                }
                if (r.url.path.endsWith('/wallet')) {
                  return jsonResult({'balance': 100});
                }
                if (r.url.path.endsWith('/deliveries/quote')) {
                  quoteCalls++;
                  final body = jsonDecode(r.body);
                  expect(body['branch_id'], 'selected');
                  expect(r.headers['X-Vesta-Branch'], 'selected');
                  return jsonResult({
                    'id': 'quote',
                    'fee_usd': 1.44,
                    'fee_bob': 10,
                    'bob_per_usd': 6.96,
                    'branch_name': 'Sucursal elegida',
                    'distance_km': 2.5,
                    'estimated_minutes_min': 25,
                    'estimated_minutes_max': 35,
                    'expires_at': DateTime.now()
                        .toUtc()
                        .add(const Duration(minutes: 10))
                        .toIso8601String(),
                    'directions_url': 'https://www.google.com/maps/dir/?api=1',
                  });
                }
                if (r.url.path.endsWith('/reservations') &&
                    r.method == 'POST') {
                  final body = Map<String, dynamic>.from(jsonDecode(r.body));
                  requests.add(body);
                  return jsonResult({
                    'id': 'reservation',
                    'reservation_code': 'RSV-TEST',
                    'items': [],
                    'status': 'CONFIRMED',
                    'payment_status': body['payment_method'] == 'WALLET'
                        ? 'PAID'
                        : 'PENDING',
                    'payment_method': body['payment_method'],
                    'total_amount': body['fulfillment'] == 'DELIVERY'
                        ? 13.44
                        : 12,
                    'delivery': body['fulfillment'] == 'DELIVERY'
                        ? {'status': 'REQUESTED'}
                        : null,
                  });
                }
                if (r.url.path.endsWith('/paypal-order')) {
                  return http.Response(
                    jsonEncode({'detail': 'Sandbox simulado para la prueba'}),
                    503,
                    headers: {'content-type': 'application/json'},
                  );
                }
                throw StateError(
                  'Unexpected request ${r.method} ${r.url.path}',
                );
              }),
            )
            ..activeTenantId = 'company'
            ..activeBranchId = 'selected';
      final auth = Auth(api, storage),
          cart = CarritoService(api),
          reservations = ReservaService(api);
      addTearDown(auth.dispose);
      addTearDown(cart.dispose);
      addTearDown(reservations.dispose);
      addTearDown(api.dispose);
      final screen = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: api),
            ChangeNotifierProvider<AutenticacionService>.value(value: auth),
            ChangeNotifierProvider<CarritoService>.value(value: cart),
            ChangeNotifierProvider<ReservaService>.value(value: reservations),
          ],
          child: RepaintBoundary(
            key: screen,
            child: MaterialApp(
              theme: TemaApp.lightTheme,
              home: const CarritoScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tapText(String text) async {
        final target = find.text(text).last;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Finder button(String text) => find
          .ancestor(
            of: find.text(text).last,
            matching: find.byWidgetPredicate((w) => w is ElevatedButton),
          )
          .first;
      await tapText('Pagar con PayPal (Sandbox)');
      expect(find.byType(OpcionesEntrega), findsNothing);
      expect(find.textContaining('Sucursal elegida'), findsWidgets);
      expect(find.textContaining('Primera de la lista'), findsNothing);
      await tapText('Pagar con PayPal (\$ 12.00)');
      expect(requests.single['branch_id'], 'selected');
      expect(requests.single.containsKey('fulfillment'), isFalse);
      expect(quoteCalls, 0);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tapText('Delivery a domicilio');
      expect(find.byType(OpcionesEntrega), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(button('Calcula el envío para continuar'))
            .onPressed,
        isNull,
      );
      await tapText('Pagar con mi wallet');
      expect(find.byType(OpcionesEntrega), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(button('Pagar con wallet (\$ 12.00)'))
            .onPressed,
        isNotNull,
      );
      await tapText('Delivery a domicilio');
      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.enterText(
        field('Dirección y referencias'),
        'Calle 123, puerta azul',
      );
      await tester.enterText(
        field('Link de Google Maps'),
        'https://maps.app.goo.gl/cXzSxikcRGXvG7cU8',
      );
      await tapText('Calcular envío y tiempo');
      expect(quoteCalls, 1);
      final deliveryMethod = find.byType(DropdownButtonFormField<String>).last;
      await tester.ensureVisible(deliveryMethod);
      await tester.tap(deliveryMethod);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi wallet').last);
      await tester.pumpAndSettle();
      final pay = button('Pagar con wallet (\$ 13.44)');
      expect(tester.widget<ElevatedButton>(pay).onPressed, isNotNull);
      await tester.ensureVisible(pay);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/design-previews/delivery-fourth-option.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(requests.last, containsPair('fulfillment', 'DELIVERY'));
      expect(requests.last['payment_method'], 'WALLET');
      expect(requests.last['delivery_quote_id'], 'quote');
      expect(requests.last['branch_id'], 'selected');
      expect(requests.last['delivery_recipient'], 'Felipe Cliente');
      expect(requests.last['delivery_phone'], '70001234');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
