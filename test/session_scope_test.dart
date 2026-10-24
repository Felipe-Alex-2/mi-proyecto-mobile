import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/main.dart';
import 'package:mobile/modelos/usuario.dart';
import 'package:mobile/pantallas/inicio/inicio_screen.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/autenticacion_service.dart';
import 'package:mobile/servicios/carrito_service.dart';
import 'package:mobile/servicios/catalogo_service.dart';
import 'package:mobile/servicios/notificacion_service.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';

class _Storage extends AlmacenamientoService {
  @override
  Future<bool> hasToken() async => false;
}

class _Api extends ApiService {
  _Api(super.storage);
  @override
  Future<dynamic> get(String endpoint, {bool includeAuth = true}) async =>
      endpoint == '/cart' || endpoint == '/virtual-fitting/profile'
      ? <String, dynamic>{}
      : [];
  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async => <String, dynamic>{};
}

class _Auth extends AutenticacionService {
  _Auth(super.api, super.storage);
  String userId = 'first';
  @override
  AuthStatus get status => AuthStatus.authenticated;
  @override
  Usuario get currentUser => Usuario.fromJson({
    'id': userId,
    'branch_id': 'branch',
    'selected_tenant_id': 'company',
    'email': '$userId@example.com',
    'full_name': 'Cliente',
    'created_at': '2026-10-13T12:00:00Z',
    'updated_at': '2026-10-13T12:00:00Z',
  });
  void changeUser() {
    userId = 'second';
    notifyListeners();
  }
}

void main() {
  setUpAll(() async {
    for (final (family, asset) in [
      ('VestaBody', 'assets/fonts/Roboto-Regular.ttf'),
      ('VestaEditorial', 'assets/fonts/CormorantGaramond.ttf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  testWidgets(
    'personal services and navigation are recreated when the user changes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = _Storage();
      final api = _Api(storage);
      final auth = _Auth(api, storage);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: api),
            ChangeNotifierProvider<AutenticacionService>.value(value: auth),
            ChangeNotifierProvider(create: (_) => CatalogoService(api)),
          ],
          child: const VestaApp(),
        ),
      );
      await tester.pumpAndSettle();
      final home = tester.element(find.byType(InicioScreen));
      final oldCart = home.read<CarritoService>();
      final oldNotifications = home.read<NotificacionService>();
      // A pushed route must retain access to the authenticated session scope.
      await tester.tap(find.text('Abrir vestidor'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      auth.changeUser();
      await tester.pumpAndSettle();
      final newHome = tester.element(find.byType(InicioScreen));
      expect(identical(oldCart, newHome.read<CarritoService>()), isFalse);
      expect(
        identical(oldNotifications, newHome.read<NotificacionService>()),
        isFalse,
      );
      expect(find.text('Vestidor virtual'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
      api.dispose();
    },
  );
}
