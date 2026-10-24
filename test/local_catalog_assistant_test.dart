import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/modelos/producto.dart';
import 'package:mobile/configuracion/tema.dart';
import 'package:mobile/pantallas/asistente/asistente_carlitos_screen.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/asistente_catalogo_local.dart';
import 'package:mobile/servicios/sin_conexion_service.dart';
import 'package:mobile/servicios/almacen_sin_conexion.dart';
import 'package:mobile/servicios/recomendacion_service.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Storage extends AlmacenamientoService {
  @override
  Future<String?> getAccessToken() async => 'token';
  @override
  Future<String?> getRefreshToken() async => null;
}

Map<String, dynamic> garment(
  String id,
  String color, {
  int quantity = 2,
  double price = 150,
  String size = 'M',
  bool active = true,
}) => {
  'id': id,
  'name': 'Camisa $color',
  'category': 'Camisas',
  'price': price,
  'is_active': active,
  'variants': [
    {
      'id': 'v-$id',
      'color': color,
      'size': size,
      'price': price,
      'stocks': [
        {'quantity': quantity},
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final rows = [
    garment('blue', 'Azul'),
    garment('red', 'Roja'),
    garment('expensive', 'Azul', price: 300),
    garment('sold-out', 'Azul', quantity: 0),
    garment('inactive', 'Azul', active: false),
    {
      ...garment('mixed', 'Azul', quantity: 0),
      'variants': [
        (garment('mixed', 'Azul', quantity: 0)['variants'] as List).first,
        (garment('mixed', 'Roja', size: 'L')['variants'] as List).first,
      ],
    },
  ];
  final catalog = rows.map(Producto.fromJson).toList();
  final engine = AsistenteLocalCatalogo();

  test(
    'local constraints use one available variant and never invent products',
    () {
      final response = engine.respond('camisa azul talla M hasta 200', catalog);
      expect(response.recommendations.map((product) => product.id), ['blue']);
      expect(response.matchedFilters['Talla'], 'M');
      expect(response.message, contains('última actualización'));
    },
  );

  test('plural colors and categories are understood', () {
    expect(
      engine
          .respond('CAMISAS ROJAS', catalog)
          .recommendations
          .map((product) => product.id)
          .toSet(),
      {'red', 'mixed'},
    );
  });

  test('greetings, unsupported questions and missing cache have useful bounded answers', () {
    expect(engine.respond('hola', catalog).message, contains('¡Hola!'));
    final unsupported = engine.respond('quién es el presidente', catalog);
    expect(unsupported.recommendations, isEmpty);
    expect(unsupported.message, contains('limitado'));
    expect(engine.respond('camisa', []).message, contains('conexión una vez'));
  });

  late AlmacenSinConexion store;
  late SinConexionService offline;
  late ApiService api;
  late RecomendacionService service;
  var calls = 0;
  var status = 200;
  var failConnection = false;

  setUp(() async {
    calls = 0;
    status = 200;
    failConnection = false;
    store = await AlmacenSinConexion.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    api = ApiService(
      _Storage(),
      client: MockClient((request) async {
        calls++;
        if (failConnection) throw http.ClientException('Sin conexión');
        return http.Response(
          jsonEncode(
            status == 200
                ? {'message': 'Desde la API', 'recommendations': []}
                : {'detail': 'Inicia sesión'},
          ),
          status,
        );
      }),
    );
    offline = SinConexionService(
      store,
      (method, path, body) => api.sendOnline(method, path, body),
    );
    api.offline = offline;
    await offline.activate('api|u1');
    await store.write('api|u1', '/products', rows);
    await store.write('api|u2', '/products', [garment('other-user', 'Azul')]);
    service = RecomendacionService(api);
  });

  tearDown(() async {
    service.dispose();
    offline.dispose();
    api.dispose();
    await store.db.close();
  });

  test('known offline mode does not call HTTP or enqueue chat and uses only this account cache', () async {
    offline.offline = true;
    final result = await service.getRecommendations(
      'camisa azul talla M hasta 200',
    );
    expect(result!.recommendations.single.id, 'blue');
    expect(service.isLocalResponse, isTrue);
    expect(service.errorMessage, isNull);
    expect(calls, 0);
    expect(offline.pendingCount, 0);
  });

  test('connection failure falls back to cached products', () async {
    failConnection = true;
    expect(
      await service.getRecommendations('camisa azul talla M hasta 200'),
      isNotNull,
    );
    expect(service.isLocalResponse, isTrue);
    expect(calls, 1);
  });

  test('online requests continue using the remote assistant', () async {
    expect(
      (await service.getRecommendations('camisa'))!.message,
      'Desde la API',
    );
    expect(service.isLocalResponse, isFalse);
  });

  test('authentication errors are not disguised as offline answers', () async {
    status = 401;
    expect(await service.getRecommendations('camisa'), isNull);
    expect(service.isLocalResponse, isFalse);
    expect(service.errorMessage, isNotNull);
  });

  testWidgets('local answer is labeled and readable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    offline.offline = true;
    await tester.runAsync(
      () => service.getRecommendations('camisa azul talla M hasta 200'),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: api),
          ChangeNotifierProvider.value(value: service),
        ],
        child: MaterialApp(
          theme: TemaApp.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const AsistenteCarlitosScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Carlitos · modo local'), findsOneWidget);
    expect(find.text('Filtros de búsqueda local:'), findsOneWidget);
    expect(find.text('Camisa Azul'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
