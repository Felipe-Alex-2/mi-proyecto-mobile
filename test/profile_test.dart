import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/configuracion/tema.dart';
import 'package:mobile/modelos/usuario.dart';
import 'package:mobile/pantallas/perfil/perfil_screen.dart';
import 'package:mobile/servicios/autenticacion_service.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';
import 'package:mobile/utilidades/validadores.dart';

class _Storage extends AlmacenamientoService {
  @override
  Future<bool> hasToken() async => false;
}

class _Auth extends AutenticacionService {
  _Auth(super.api, super.storage);
  int saves = 0;
  String? savedAvatar;
  bool? clearedPhoto;
  @override
  Usuario get currentUser => Usuario.fromJson({
    'id': '1',
    'email': 'cliente@example.com',
    'full_name': 'Cliente VESTA',
    'created_at': '2026-10-13T12:00:00Z',
    'updated_at': '2026-10-13T12:00:00Z',
  });
  @override
  Future<bool> updateProfile({
    String? fullName,
    String? email,
    String? avatarId,
    String? profilePhoto,
    bool updateImage = false,
  }) async {
    saves++;
    savedAvatar = avatarId;
    clearedPhoto = updateImage && profilePhoto == null;
    return true;
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
  test('email validation accepts long domains and tagged addresses', () {
    expect(
      ValidadoresApp.validarCorreo('cliente+vesta@example.technology'),
      isNull,
    );
    expect(ValidadoresApp.validarCorreo('  '), isNotNull);
    expect(ValidadoresApp.validarCorreo('cliente@'), isNotNull);
  });
  testWidgets('profile offers three avatars and rejects blank names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _Storage();
    final api = ApiService(storage);
    final auth = _Auth(api, storage);
    await tester.pumpWidget(
      ChangeNotifierProvider<AutenticacionService>.value(
        value: auth,
        child: MaterialApp(
          theme: TemaApp.lightTheme,
          home: const PerfilScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final avatar in ['Terracota', 'Salvia', 'Arena']) {
      expect(find.text(avatar), findsOneWidget);
    }
    await tester.tap(find.text('Salvia'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.scrollUntilVisible(
      find.text('Guardar cambios'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    expect(auth.saves, 0);
    await tester.enterText(find.byType(TextFormField).first, 'Cliente VESTA');
    await tester.scrollUntilVisible(
      find.text('Guardar cambios'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(auth.saves, 1);
    expect(auth.savedAvatar, 'sage');
    expect(auth.clearedPhoto, isTrue);
    expect(find.text('Cambios guardados.'), findsOneWidget);
    expect(find.textContaining('Pendientes de sincronizar'), findsNothing);
    auth.profileSavePending = true;
    await tester.scrollUntilVisible(
      find.text('Guardar cambios'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Cambios guardados en el dispositivo. Pendientes de sincronizar.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cambios guardados.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    api.dispose();
  });
}
