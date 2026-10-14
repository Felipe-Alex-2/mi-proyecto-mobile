import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/main.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/screens/home/home_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/cart_service.dart';
import 'package:mobile/services/catalog_service.dart';
import 'package:mobile/services/notification_service.dart';
import 'package:mobile/services/storage_service.dart';

class _Storage extends StorageService {
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

class _Auth extends AuthService {
  _Auth(super.api, super.storage);
  String userId = 'first';
  @override
  AuthStatus get status => AuthStatus.authenticated;
  @override
  User get currentUser => User.fromJson({
    'id': userId,
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
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider(create: (_) => CatalogService(api)),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      final home = tester.element(find.byType(HomeScreen));
      final oldCart = home.read<CartService>();
      final oldNotifications = home.read<NotificationService>();
      // A pushed route must retain access to the authenticated session scope.
      await tester.tap(find.text('Abrir vestidor'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      auth.changeUser();
      await tester.pumpAndSettle();
      final newHome = tester.element(find.byType(HomeScreen));
      expect(identical(oldCart, newHome.read<CartService>()), isFalse);
      expect(
        identical(oldNotifications, newHome.read<NotificationService>()),
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
