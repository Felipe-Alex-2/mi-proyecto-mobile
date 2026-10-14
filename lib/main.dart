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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  final apiService = ApiService(storageService);
  final authService = AuthService(apiService, storageService);
  final catalogService = CatalogService(apiService);

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return MaterialApp(
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
          child: child!,
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    switch (authService.status) {
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
