import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:mobile/modelos/usuario.dart';
import 'package:mobile/pantallas/perfil/wallet_screen.dart';
import 'package:mobile/pantallas/reportes/reportes_screen.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';
import 'package:mobile/servicios/autenticacion_service.dart';

class _Storage extends AlmacenamientoService {
  @override
  Future<bool> hasToken() async => false;
  @override
  Future<String?> getAccessToken() async => 'test';
}

class _Auth extends AutenticacionService {
  _Auth(super.api, super.storage, {this.role = 'ADMIN', this.platform = true});
  final String role;
  final bool platform;
  @override
  Usuario get currentUser => Usuario.fromJson({
    'id': 'admin',
    'role': role,
    'branch_id': 'branch',
    'is_saas_admin': platform,
    'email': 'admin@gmail.com',
    'full_name': 'Felipe',
    'created_at': '2026-11-08T12:00:00Z',
    'updated_at': '2026-11-08T12:00:00Z',
  });
}

http.Response jsonResponse(dynamic body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'wallet displays only confirmed balance and verifies a pending topup',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var credited = false;
      final api = ApiService(
        _Storage(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            expect(r.url.path, endsWith('/wallet/topups/topup/capture'));
            credited = true;
          }
          return jsonResponse({
            'balance': credited ? 100 : 0,
            'entries': credited
                ? [
                    {
                      'id': 'e',
                      'amount': 100,
                      'description': 'Recarga confirmada',
                      'created_at': '2026-11-08',
                    },
                  ]
                : [],
            'pending': credited
                ? []
                : [
                    {
                      'id': 'topup',
                      'amount': 100,
                      'order_id': 'order',
                      'approval_url': null,
                    },
                  ],
          });
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(
        Provider.value(
          value: api,
          child: const MaterialApp(home: WalletScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('USD 0.00'), findsOneWidget);
      expect(find.text('USD 10'), findsOneWidget);
      expect(find.text('USD 50'), findsOneWidget);
      expect(find.text('USD 100'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Ya pagué · Verificar recarga'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ya pagué · Verificar recarga'));
      await tester.pumpAndSettle();
      expect(credited, isTrue);
      await tester.drag(find.byType(ListView), const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(find.text('USD 100.00'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'mobile reports request global results only for platform account and mail the logged-in user',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_tts'),
            (call) async => 1,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null),
      );
      Map<String, dynamic>? request;
      final storage = _Storage();
      final api = ApiService(
        storage,
        client: MockClient((r) async {
          if (r.method == 'GET') return jsonResponse([]);
          request = jsonDecode(r.body);
          return jsonResponse({
            'report_id': 'one',
            'title': 'Ventas por empresa',
            'narration': 'MODAT vendió 120 dólares.',
            'email_status': 'SENT',
            'email_message': 'PDF enviado a admin@gmail.com',
            'summary': {'leader_USD': 'MODAT', 'total_USD': 120},
            'columns': ['company', 'amount'],
            'rows': [
              {'company': 'MODAT', 'amount': 120},
            ],
          });
        }),
      );
      final auth = _Auth(api, storage);
      addTearDown(auth.dispose);
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider.value(value: api),
            ChangeNotifierProvider<AutenticacionService>.value(value: auth),
          ],
          child: const MaterialApp(home: ReportesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar reporte'));
      await tester.pumpAndSettle();
      expect(request?['all_companies'], isTrue);
      expect(request?['email_self'], isTrue);
      expect(request?.containsKey('email_to'), isFalse);
      await tester.scrollUntilVisible(
        find.text('PDF enviado a admin@gmail.com'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Exportar CSV'), findsOneWidget);
      expect(find.text('Leer reporte'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  test('report CSV escapes formulas and the cached user retains platform privileges', () {
    final csv = reportCsv({
      'columns': ['company'],
      'rows': [
        {'company': '=HYPERLINK("bad")'},
      ],
    });
    expect(csv, contains("'=HYPERLINK"));
    final user = Usuario.fromJson({
      'id': 'a',
      'role': 'ADMIN',
      'branch_id': 'branch',
      'is_saas_admin': true,
      'email': 'a@example.com',
      'full_name': 'A',
      'created_at': '2026-11-08',
      'updated_at': '2026-11-08',
    });
    expect(Usuario.fromJson(user.toJson()).isSaasAdmin, isTrue);
  });
  for (final role in ['CUSTOMER', 'CASHIER']) {
    testWidgets('$role can open and generate a scoped mobile report', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_tts'),
            (call) async => 1,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null),
      );
      final storage = _Storage();
      Map<String, dynamic>? body;
      final api = ApiService(
        storage,
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return jsonResponse(
              request.url.path.endsWith('/branches')
                  ? [
                      {'id': 'branch', 'name': 'Central'},
                    ]
                  : {'ai_reports': true},
            );
          }
          body = jsonDecode(request.body);
          return jsonResponse({
            'title': 'Inventario',
            'summary': {},
            'columns': [],
            'rows': [],
            'email_status': 'SENT',
            'email_message': 'PDF enviado a admin@gmail.com',
          });
        }),
      );
      final auth = _Auth(api, storage, role: role, platform: false);
      addTearDown(auth.dispose);
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider.value(value: api),
            ChangeNotifierProvider<AutenticacionService>.value(value: auth),
          ],
          child: const MaterialApp(home: ReportesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reporte manual'), findsOneWidget);
      expect(find.text('Todas las empresas y sucursales'), findsNothing);
      await tester.tap(find.text('Generar reporte'));
      await tester.pumpAndSettle();
      expect(body?['branch_id'], 'branch');
      expect(body?['all_companies'], isFalse);
      expect(body?['email_self'], isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
