import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/configuracion/tema.dart';
import 'package:mobile/pantallas/autenticacion/inicio_sesion_screen.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/autenticacion_service.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';

void main() {
  testWidgets('InicioSesionScreen renders email, password, and login button', (
    WidgetTester tester,
  ) async {
    final storageService = AlmacenamientoService();
    final apiService = ApiService(storageService);
    final authService = AutenticacionService(apiService, storageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlmacenamientoService>.value(value: storageService),
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider<AutenticacionService>.value(value: authService),
        ],
        child: MaterialApp(
          theme: TemaApp.lightTheme,
          home: const InicioSesionScreen(),
        ),
      ),
    );

    // Verify title and input fields
    expect(find.text('Iniciar Sesión'), findsNWidgets(2));
    expect(find.text('Correo Electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Iniciar Sesión'),
      findsOneWidget,
    );
  });
}
