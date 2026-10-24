import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/configuracion/tema.dart';
import 'package:mobile/pantallas/inicio/inicio_screen.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/autenticacion_service.dart';
import 'package:mobile/servicios/carrito_service.dart';
import 'package:mobile/servicios/catalogo_service.dart';
import 'package:mobile/servicios/notificacion_service.dart';
import 'package:mobile/servicios/reserva_service.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';
import 'package:mobile/servicios/vestidor_virtual_service.dart';

class _Storage extends AlmacenamientoService {
  @override
  Future<bool> hasToken() async => false;
}

class _Api extends ApiService {
  _Api(super.storage);
  @override
  Future<dynamic> get(String endpoint, {bool includeAuth = true}) async {
    if (endpoint == '/products') {
      return [
        for (final (id, name, gender) in [
          ('1', 'Blusa de lino', 'Mujer'),
          ('2', 'Sobrecamisa de algodón', 'Hombre'),
        ])
          {
            'id': id,
            'name': name,
            'gender': gender,
            'price': 29,
            'category': 'Prendas',
            'is_active': true,
            'variants': [
              {
                'id': 'v$id',
                'color': 'Crema',
                'size': 'M',
                'price': 29,
                'stocks': [
                  {'quantity': 5},
                ],
              },
            ],
          },
      ];
    }
    if (endpoint == '/cart' || endpoint == '/virtual-fitting/profile') {
      return <String, dynamic>{};
    }
    return [];
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    return <String, dynamic>{'recommended_size': 'M', 'confidence_score': 95};
  }
}

void main() {
  final boundary = GlobalKey();
  Future<void> mount(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _Storage();
    final api = _Api(storage);
    final notifications = NotificacionService(api)..stopPolling();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      notifications.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AutenticacionService(api, storage)),
          ChangeNotifierProvider(create: (_) => CatalogoService(api)),
          ChangeNotifierProvider(create: (_) => CarritoService(api)),
          ChangeNotifierProvider(create: (_) => ReservaService(api)),
          ChangeNotifierProvider(create: (_) => VestidorVirtualService(api)),
          ChangeNotifierProvider.value(value: notifications),
        ],
        child: MaterialApp(
          theme: TemaApp.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: RepaintBoundary(key: boundary, child: const InicioScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/virtual-fitting-hero.png'),
        tester.element(find.byType(InicioScreen)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('SAVE_DESIGN_PREVIEWS')) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/design-previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  setUpAll(() async {
    for (final (family, asset) in [
      ('VestaBody', 'assets/fonts/Roboto-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ('VestaEditorial', 'assets/fonts/CormorantGaramond.ttf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });

  testWidgets(
    'Home, catalog filters, and fitting remain usable on a narrow phone',
    (tester) async {
      await mount(tester, const Size(320, 740));
      expect(find.text('Abrir vestidor'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await preview(tester, 'inicio');
      await tester.tap(find.text('Catálogo').last);
      await tester.pumpAndSettle();
      expect(find.text('Blusa de lino'), findsOneWidget);
      await preview(tester, 'catalogo');
      await tester.tap(find.text('Mujer').first);
      await tester.pumpAndSettle();
      expect(find.text('Blusa de lino'), findsOneWidget);
      expect(find.text('Sobrecamisa de algodón'), findsNothing);
      await tester.tap(find.text('Probar en mí').first);
      await tester.pumpAndSettle();
      // Dismiss the existing measurement sheet to inspect the fitting screen.
      final context = tester.element(
        find.text('Calcular Talla y Probar Prendas'),
      );
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(find.text('Vestidor virtual'), findsOneWidget);
      expect(find.text('Añadir al carrito'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Mi foto'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home and catalog accommodate enlarged text', (tester) async {
    await mount(tester, const Size(390, 844), textScale: 1.4);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Catálogo').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
