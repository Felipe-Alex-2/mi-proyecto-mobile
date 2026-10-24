import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/configuracion/tema.dart';
import 'package:mobile/pantallas/inicio/widgets/notificaciones_modal.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/notificacion_service.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';

class _NotificationsApi extends ApiService {
  final patched = <String>[];
  _NotificationsApi() : super(AlmacenamientoService());

  @override
  Future<dynamic> get(String endpoint, {bool includeAuth = true}) async => [
    {
      'id': 'unread',
      'title': 'Nueva notificación',
      'message': 'Tu perfil fue actualizado',
      'is_read': false,
      'created_at': '2026-10-19T12:00:00Z',
    },
    {
      'id': 'read',
      'title': 'Notificación anterior',
      'message': 'Bienvenido a VESTA',
      'is_read': true,
      'created_at': '2026-10-18T12:00:00Z',
    },
  ];

  @override
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    patched.add(endpoint);
    return {};
  }
}

void main() {
  late _NotificationsApi api;
  late NotificacionService service;

  setUp(() async {
    api = _NotificationsApi();
    service = NotificacionService(api);
    await service.loadNotifications();
  });

  tearDown(() {
    service.dispose();
    api.dispose();
  });

  Future<void> open(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => NotificacionesModal.show(context, service),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('filters update immediately after reading a notification', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Nueva notificación'), findsOneWidget);
    expect(find.text('Notificación anterior'), findsOneWidget);
    await tester.tap(find.text('No leídas (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Notificación anterior'), findsNothing);
    await tester.tap(find.text('Nueva notificación'));
    await tester.pumpAndSettle();
    expect(api.patched, ['/notifications/unread/read']);
    expect(find.text('Nueva notificación'), findsNothing);
    expect(find.textContaining('Estás al día'), findsOneWidget);
    await tester.tap(find.text('Leídas (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva notificación'), findsOneWidget);
    expect(find.text('Notificación anterior'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mark all read preserves the selected filter with enlarged text',
    (tester) async {
      await open(tester, textScale: 1.4);
      await tester.tap(find.text('No leídas (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar leídas'));
      await tester.pumpAndSettle();
      expect(api.patched, ['/notifications/read-all']);
      expect(find.text('No leídas (0)'), findsOneWidget);
      expect(find.textContaining('Estás al día'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
