import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/modelos/usuario.dart';
import 'package:mobile/servicios/sin_conexion_service.dart';
import 'package:mobile/servicios/almacen_sin_conexion.dart';
import 'package:path/path.dart' as path;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'profile drafts survive native SQLite reopen and sync on resume',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Prueba offline de perfil')),
        ),
      );
      final directory = await Directory.systemTemp.createTemp(
        'vesta-profile-test-',
      );
      final databasePath = path.join(directory.path, 'profile.db');
      var serverUser = <String, dynamic>{
        'id': 'native-user',
        'full_name': 'Cliente',
        'email': 'cliente@example.com',
        'created_at': '2026-10-19T12:00:00Z',
        'updated_at': '2026-10-19T12:00:00Z',
      };
      var sends = 0;
      Future<dynamic> send(
        String method,
        String route,
        Map<String, dynamic> body,
      ) async {
        if (route == '/sync/operations') {
          serverUser = {
            ...serverUser,
            ...Map<String, dynamic>.from(body['body']),
          };
          sends++;
        }
        return serverUser;
      }

      var store = await AlmacenSinConexion.open(path: databasePath);
      var queue = SinConexionService(store, send)..offline = true;
      await queue.activate('test-api|native-user');
      await store.write(queue.owner!, '/users/me', serverUser);
      final saved = await queue.mutate('PUT', '/users/me', {
        'full_name': 'Cliente Offline',
        'avatar_id': 'sage',
        'profile_photo': null,
      });
      expect(Usuario.fromJson(saved).avatarId, 'sage');
      expect(queue.pendingCount, 1);
      queue.dispose();
      await store.db.close();

      store = await AlmacenSinConexion.open(path: databasePath);
      queue = SinConexionService(store, send)..offline = true;
      try {
        await queue.activate('test-api|native-user');
        final restored = Usuario.fromJson(await queue.cached('/users/me'));
        expect(restored.fullName, 'Cliente Offline');
        expect(restored.avatarId, 'sage');
        expect(queue.pendingCount, 1);
        final synced = Completer<void>();
        queue.addListener(() {
          if (!queue.syncing &&
              queue.pendingCount == 0 &&
              !synced.isCompleted) {
            synced.complete();
          }
        });
        queue.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await synced.future.timeout(const Duration(seconds: 10));
        expect(sends, 1);
        expect(Usuario.fromJson(await queue.cached('/users/me')).avatarId, 'sage');
        expect(serverUser['full_name'], 'Cliente Offline');
      } finally {
        queue.dispose();
        await store.db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
