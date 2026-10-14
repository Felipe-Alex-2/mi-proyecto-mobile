import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/config/theme.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/screens/profile/profile_screen.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/utils/validators.dart';

class _Storage extends StorageService {
  @override
  Future<bool> hasToken() async => false;
}

class _Auth extends AuthService {
  _Auth(super.api, super.storage);
  int saves = 0;
  String? savedAvatar;
  bool? clearedPhoto;
  @override
  User get currentUser => User.fromJson({
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
      AppValidators.validateEmail('cliente+vesta@example.technology'),
      isNull,
    );
    expect(AppValidators.validateEmail('  '), isNotNull);
    expect(AppValidators.validateEmail('cliente@'), isNotNull);
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
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfileScreen(),
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
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    expect(auth.saves, 0);
    await tester.enterText(find.byType(TextFormField).first, 'Cliente VESTA');
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(auth.saves, 1);
    expect(auth.savedAvatar, 'sage');
    expect(auth.clearedPhoto, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    api.dispose();
  });
}
