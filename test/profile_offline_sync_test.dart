import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/servicios/api_service.dart';
import 'package:mobile/servicios/autenticacion_service.dart';
import 'package:mobile/servicios/sin_conexion_service.dart';
import 'package:mobile/servicios/almacen_sin_conexion.dart';
import 'package:mobile/servicios/almacenamiento_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Storage extends AlmacenamientoService {
  String user;
  _Storage(this.user);
  @override
  Future<bool> hasToken() async => true;
  @override
  Future<String?> getAccessToken() async => 'token';
  @override
  Future<String?> getLocalUser() async => user;
  @override
  Future<void> saveLocalUser(String value) async => user = value;
  @override
  Future<void> saveSyncOwner(String owner) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'real profile save stays pending offline and syncs on resume exactly once',
    () async {
      var connected = false;
      var writes = 0;
      var serverUser = <String, dynamic>{
        'id': 'profile-user',
        'full_name': 'Cliente Prueba',
        'email': 'cliente@example.com',
        'avatar_id': 'terracotta',
        'created_at': '2026-10-19T12:00:00Z',
        'updated_at': '2026-10-19T12:00:00Z',
      };
      final storage = _Storage(jsonEncode(serverUser));
      final api = ApiService(
        storage,
        client: MockClient((request) async {
          if (!connected) throw http.ClientException('Sin conexión');
          if (request.url.path.endsWith('/sync/operations')) {
            final command = jsonDecode(request.body) as Map<String, dynamic>;
            expect(command['path'], '/users/me');
            expect(command['account_id'], 'profile-user');
            serverUser = {
              ...serverUser,
              ...Map<String, dynamic>.from(command['body']),
            };
            writes++;
          }
          return http.Response(jsonEncode(serverUser), 200);
        }),
      );
      final store = await AlmacenSinConexion.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final offline = SinConexionService(
        store,
        (method, path, body) => api.sendOnline(method, path, body),
      )..offline = true;
      api.offline = offline;
      final auth = AutenticacionService(api, storage, offline: offline);
      addTearDown(() async {
        auth.dispose();
        offline.dispose();
        api.dispose();
        await store.db.close();
      });
      final ready = Completer<void>();
      void listen() {
        if (auth.status == AuthStatus.authenticated && !ready.isCompleted) {
          ready.complete();
        }
      }

      auth.addListener(listen);
      await ready.future.timeout(const Duration(seconds: 5));
      auth.removeListener(listen);
      await pumpEventQueue();
      expect(
        await auth.updateProfile(
          fullName: 'Cliente Offline',
          avatarId: 'sage',
          updateImage: true,
        ),
        isTrue,
      );
      expect(auth.errorMessage, isNull);
      expect(auth.profileSavePending, isTrue);
      expect(auth.currentUser!.avatarId, 'sage');
      expect(auth.currentUser!.fullName, 'Cliente Offline');
      expect(jsonDecode(storage.user)['avatar_id'], 'sage');
      expect(offline.pendingCount, 1);
      expect(writes, 0);

      final drained = Completer<void>();
      void onSynced() {
        if (!offline.syncing &&
            offline.pendingCount == 0 &&
            !drained.isCompleted) {
          drained.complete();
        }
      }

      offline.addListener(onSynced);
      connected = true;
      offline.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await drained.future.timeout(const Duration(seconds: 5));
      offline.removeListener(onSynced);
      await pumpEventQueue();
      expect(writes, 1);
      expect(serverUser['avatar_id'], 'sage');
      expect(auth.currentUser!.fullName, 'Cliente Offline');
      await offline.sync();
      expect(writes, 1);
      expect(await auth.updateProfile(fullName: 'Cliente Online'), isTrue);
      expect(auth.profileSavePending, isFalse);
      expect(offline.pendingCount, 0);
      expect(writes, 2);
      connected = false;
      offline.offline = false;
      expect(
        await auth.updateProfile(fullName: 'Servidor inaccesible'),
        isTrue,
      );
      expect(auth.profileSavePending, isTrue);
      expect(offline.pendingCount, 1);
    },
  );
}
