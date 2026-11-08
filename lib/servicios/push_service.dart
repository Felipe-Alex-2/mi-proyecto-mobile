import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../modelos/usuario.dart';
import '../utilidades/request_id.dart';
import 'api_service.dart';
import 'almacenamiento_service.dart';
import 'autenticacion_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Android displays the generic notification payload. Do not show it twice.
}

bool pushBelongsTo(Map<String, dynamic> data, Usuario? user) =>
    user != null &&
    data['user_id'] == user.id &&
    data['tenant_id'] ==
        (user.role == 'CUSTOMER' ? user.selectedTenantId : user.tenantId);

class PushService extends ChangeNotifier with WidgetsBindingObserver {
  final ApiService api;
  final AutenticacionService auth;
  final AlmacenamientoService storage;
  final _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _foreground, _opened;
  bool _ready = false,
      _disposed = false,
      _enabled = false,
      _registered = false,
      _serverConfigured = false;
  bool _busy = false;
  String? _scope, _token, _installation, _error;
  int _generation = 0, _revision = 0;
  Map<String, dynamic>? _pendingOpen;
  final Set<String> _received = {};
  Timer? _retry;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get enabled => _enabled;
  bool get busy => _busy;
  bool get serverConfigured => _serverConfigured;
  int get revision => _revision;
  String get status => !supported
      ? 'Push disponible en Android'
      : _error ??
            (!_ready
                ? 'Preparando notificaciones…'
                : !_enabled
                ? 'Notificaciones desactivadas'
                : !_registered
                ? 'Pendiente de registrar este dispositivo'
                : !_serverConfigured
                ? 'Dispositivo registrado. Falta activar Firebase en el backend.'
                : 'Notificaciones push activadas');

  PushService(this.api, this.auth, this.storage) {
    auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    auth.beforeLogout = unregister;
  }
  Future<void> initialize() async {
    if (!supported) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          try {
            final data = jsonDecode(response.payload ?? '{}');
            _open(Map<String, dynamic>.from(data));
          } catch (_) {}
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'vesta_notifications',
              'Avisos de VESTA',
              description: 'Pedidos, reservas y wallet',
              importance: Importance.high,
            ),
          );
      _installation = await storage.getPushInstallation();
      if (_installation == null) {
        _installation = requestId();
        await storage.savePushInstallation(_installation!);
      }
      _foreground = FirebaseMessaging.onMessage.listen((message) {
        unawaited(_message(message));
      });
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _open(message.data),
      );
      _refresh = FirebaseMessaging.instance.onRegistered.listen((token) {
        _token = token;
        _registered = false;
        unawaited(sync());
      });
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        try {
          _pendingOpen = Map<String, dynamic>.from(
            jsonDecode(launch!.notificationResponse?.payload ?? '{}'),
          );
        } catch (_) {}
      }
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingOpen = initial.data;
      _ready = true;
      _authChanged();
      _retry = Timer.periodic(const Duration(minutes: 1), (_) {
        if (_enabled && !_registered) unawaited(sync());
      });
    } catch (_) {
      _error = 'No se pudo iniciar Firebase. Revisa la conexión y la configuración de la app.';
    }
    _emit();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _authChanged() {
    if (!_ready || _disposed) return;
    final user = auth.isAuthenticated ? auth.currentUser : null;
    final scope = user?.scopeKey;
    if (scope == _scope) return;
    _scope = scope;
    _generation++;
    _registered = false;
    _received.clear();
    if (user == null) {
      _enabled = false;
      unawaited(_local.cancelAll());
      _emit();
      return;
    }
    // Android retains the OS permission decision; this does not prompt repeatedly.
    unawaited(_autoEnable());
  }

  Future<void> _autoEnable() async {
    final user = auth.currentUser;
    if (user == null) return;
    if (await storage.pushDisabledFor(user.id)) return;
    if (!auth.isAuthenticated || auth.currentUser?.id != user.id) return;
    await enable();
  }

  Future<void> disable() async {
    final user = auth.currentUser;
    if (user != null) await storage.setPushDisabled(user.id, true);
    await unregister();
  }

  Future<void> enable() async {
    if (!_ready || _disposed || !auth.isAuthenticated) return;
    if (_busy) return;
    _busy = true;
    _error = null;
    _emit();
    try {
      await storage.setPushDisabled(auth.currentUser!.id, false);
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _enabled =
          permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional;
      if (!_enabled) {
        _error = 'Permiso de notificaciones denegado. Puedes activarlo en los ajustes de Android.';
        return;
      }
      await FirebaseMessaging.instance.register();
      await sync();
    } catch (_) {
      _error = 'No se pudo registrar el dispositivo. Reintenta con conexión.';
    } finally {
      _busy = false;
      _emit();
    }
  }

  Future<void> sync() async {
    final user = auth.isAuthenticated ? auth.currentUser : null;
    if (!_ready ||
        !_enabled ||
        user == null ||
        _token == null ||
        _installation == null) {
      return;
    }
    final tenant = user.role == 'CUSTOMER'
        ? user.selectedTenantId
        : user.tenantId;
    if (tenant == null || (user.role == 'CUSTOMER' && user.branchId == null)) {
      return;
    }
    final version = _generation;
    try {
      final response = await api.postOnline(
        '/notifications/push/devices',
        body: {
          'installation_id': _installation,
          'token': _token,
          'user_id': user.id,
          'tenant_id': tenant,
          'branch_id': user.branchId,
        },
      );
      if (version != _generation || _disposed) return;
      _registered = response['registered'] == true;
      _serverConfigured = response['server_configured'] == true;
      _error = null;
    } catch (_) {
      if (version == _generation) {
        _registered = false;
        _error = 'Registro push pendiente. Verifica tu conexión y que el backend esté actualizado.';
      }
    }
    _emit();
  }

  Future<void> testNotification() async {
    if (!_registered) {
      await enable();
    }
    try {
      final response = await api.postOnline(
        '/notifications/push/test',
        body: {'request_id': requestId()},
      );
      _error = response['message'] as String?;
    } catch (_) {
      _error = 'No se pudo enviar la prueba. Comprueba Firebase en Railway.';
    }
    _emit();
  }

  Future<void> unregister() async {
    _generation++;
    _enabled = false;
    _registered = false;
    _pendingOpen = null;
    final token = _token;
    if (token != null && _installation != null) {
      try {
        await api
            .postOnline(
              '/notifications/push/unregister',
              body: {'installation_id': _installation, 'token': token},
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    try {
      await FirebaseMessaging.instance.unregister();
    } catch (_) {}
    try {
      await _local.cancelAll();
    } catch (_) {}
    _token = null;
    _emit();
  }

  Future<void> _message(RemoteMessage message) async {
    if (!auth.isAuthenticated ||
        !pushBelongsTo(message.data, auth.currentUser)) {
      return;
    }
    final id = '${message.data['notification_id'] ?? message.messageId}';
    if (!_received.add(id)) return;
    if (_received.length > 200) _received.remove(_received.first);
    _revision++;
    _emit();
    try {
      await _local.show(
        id: id.hashCode & 0x7fffffff,
        title: message.notification?.title ?? 'VESTA',
        body:
            message.notification?.body ??
            'Tienes una nueva notificación. Abre la app para verla.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'vesta_notifications',
            'Avisos de VESTA',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (_) {}
  }

  void _open(Map<String, dynamic> data) {
    _pendingOpen = data;
    _revision++;
    _emit();
  }

  Map<String, dynamic>? takeOpen() {
    if (!auth.isAuthenticated) return null;
    final data = _pendingOpen;
    _pendingOpen = null;
    return data != null && pushBelongsTo(data, auth.currentUser) ? data : null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready && auth.isAuthenticated) {
      unawaited(_autoEnable());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _retry?.cancel();
    auth.removeListener(_authChanged);
    auth.beforeLogout = null;
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    _foreground?.cancel();
    _opened?.cancel();
    super.dispose();
  }
}
