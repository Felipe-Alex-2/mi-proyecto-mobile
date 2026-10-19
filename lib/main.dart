import 'package:flutter/foundation.dart';

import 'services/offline_store.dart';
import 'services/background_sync.dart';
import 'services/offline_service.dart';
import 'services/biometric_service.dart';
import 'widgets/offline_status.dart';
import 'widgets/session_lock.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/catalog_service.dart';
import 'services/cart_service.dart';
import 'services/reservation_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/virtual_fitting_service.dart';
import 'services/recommendation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await BackgroundSync.initialize();
  final storageService = StorageService();
  final apiService = ApiService(storageService);
  OfflineService? offline;
  if (!kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform)) {
    offline = OfflineService(
      await OfflineStore.open(),
      (method, path, body) => apiService.sendOnline(method, path, body),
    );
    apiService.offline = offline;
    offline.start();
  }
  final authService = AuthService(
    apiService,
    storageService,
    offline: offline,
    biometrics: BiometricService(),
  );
  final catalogService = CatalogService(apiService);

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        if (offline != null)
          ChangeNotifierProvider<OfflineService>.value(value: offline),
        Provider<ApiService>(
          create: (_) => apiService,
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<CatalogService>.value(value: catalogService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _navigationOwner;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final owner = auth.status == AuthStatus.authenticated
        ? auth.currentUser!.id
        : 'guest';
    if (_navigationOwner != owner) {
      _navigationOwner = owner;
      _navigatorKey = GlobalKey<NavigatorState>();
    }
    return SessionLock(
      auth: auth,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        key: ValueKey(
          auth.status == AuthStatus.authenticated
              ? auth.currentUser!.id
              : 'guest',
        ),
        title: 'FashionStore VESTA',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          if (auth.status != AuthStatus.authenticated) return child!;
          final api = context.read<ApiService>();
          // Personal data belongs to one authenticated session. Wrap the
          // Navigator so pushed routes share this scope as well as the home page.
          return MultiProvider(
            key: ValueKey(auth.currentUser!.id),
            providers: [
              ChangeNotifierProvider(create: (_) => CartService(api)),
              ChangeNotifierProvider(create: (_) => ReservationService(api)),
              ChangeNotifierProvider(create: (_) => NotificationService(api)),
              ChangeNotifierProvider(create: (_) => VirtualFittingService(api)),
              ChangeNotifierProvider(create: (_) => RecommendationService(api)),
            ],
            child: context.read<ApiService>().offline == null
                ? child!
                : OfflineStatus(navigatorKey: _navigatorKey, child: child!),
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

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
        return const HomeScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.authenticating:
        return const LoginScreen();
    }
  }
}
