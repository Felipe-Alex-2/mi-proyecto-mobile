import 'widgets/selector_tienda.dart';

import 'package:flutter/foundation.dart';

import 'servicios/almacen_sin_conexion.dart';
import 'servicios/sincronizacion_segundo_plano.dart';
import 'servicios/sin_conexion_service.dart';
import 'servicios/biometria_service.dart';
import 'widgets/estado_sin_conexion.dart';
import 'widgets/bloqueo_sesion.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'configuracion/tema.dart';
import 'pantallas/autenticacion/inicio_sesion_screen.dart';
import 'pantallas/inicio/inicio_screen.dart';
import 'servicios/api_service.dart';
import 'servicios/autenticacion_service.dart';
import 'servicios/catalogo_service.dart';
import 'servicios/carrito_service.dart';
import 'servicios/reserva_service.dart';
import 'servicios/notificacion_service.dart';
import 'servicios/almacenamiento_service.dart';
import 'servicios/vestidor_virtual_service.dart';
import 'servicios/recomendacion_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SincronizacionSegundoPlano.initialize();
  final storageService = AlmacenamientoService();
  final apiService = ApiService(storageService);
  SinConexionService? offline;
  if (!kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform)) {
    offline = SinConexionService(
      await AlmacenSinConexion.open(),
      (method, path, body) => apiService.sendOnline(method, path, body),
    );
    apiService.offline = offline;
    offline.start();
  }
  final authService = AutenticacionService(
    apiService,
    storageService,
    offline: offline,
    biometrics: BiometriaService(),
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<AlmacenamientoService>.value(value: storageService),
        if (offline != null)
          ChangeNotifierProvider<SinConexionService>.value(value: offline),
        Provider<ApiService>(
          create: (_) => apiService,
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider<AutenticacionService>.value(value: authService),
      ],
      child: const VestaApp(),
    ),
  );
}

class VestaApp extends StatefulWidget {
  const VestaApp({super.key});
  @override
  State<VestaApp> createState() => _VestaAppState();
}

class _VestaAppState extends State<VestaApp> {
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _navigationOwner;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AutenticacionService>();
    final owner = auth.status == AuthStatus.authenticated
        ? auth.currentUser!.scopeKey
        : 'guest';
    if (_navigationOwner != owner) {
      _navigationOwner = owner;
      _navigatorKey = GlobalKey<NavigatorState>();
    }
    return BloqueoSesion(
      auth: auth,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        key: ValueKey(owner),
        title: 'FashionStore VESTA',
        theme: TemaApp.lightTheme,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          if (auth.status != AuthStatus.authenticated) return child!;
          final api = context.read<ApiService>();
          // Personal data belongs to one authenticated session. Wrap the
          // Navigator so pushed routes share this scope as well as the home page.
          return MultiProvider(
            key: ValueKey(auth.currentUser!.scopeKey),
            providers: [
              ChangeNotifierProvider(create: (_) => CatalogoService(api)),
              ChangeNotifierProvider(create: (_) => CarritoService(api)),
              ChangeNotifierProvider(create: (_) => ReservaService(api)),
              ChangeNotifierProvider(create: (_) => NotificacionService(api)),
              ChangeNotifierProvider(create: (_) => VestidorVirtualService(api)),
              ChangeNotifierProvider(create: (_) => RecomendacionService(api)),
            ],
            child: context.read<ApiService>().offline == null
                ? child!
                : EstadoSinConexion(navigatorKey: _navigatorKey, child: child!),
          );
        },
        home: const AccesoAutenticacion(),
      ),
    );
  }
}

class AccesoAutenticacion extends StatelessWidget {
  const AccesoAutenticacion({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AutenticacionService>();

    switch (authService.status) {
      case AuthStatus.locked:
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fingerprint, size: 72),
                    const SizedBox(height: 20),
                    const Text('Desbloquear VESTA'),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: authService.unlocking
                          ? null
                          : authService.unlock,
                      child: const Text('Usar huella / biometría'),
                    ),
                    TextButton(
                      onPressed: authService.logout,
                      child: const Text('Entrar con contraseña'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case AuthStatus.uninitialized:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        final user = authService.currentUser!;
        if (user.role == 'CUSTOMER' && user.branchId == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Elige tu tienda')),
            body: SingleChildScrollView(
              child: SelectorTienda(
                tenantId: user.selectedTenantId,
                onSelected: (tenant, branch) =>
                    authService.selectStore(tenant, branch),
              ),
            ),
          );
        }
        return const InicioScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.authenticating:
        return const InicioSesionScreen();
    }
  }
}
