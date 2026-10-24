import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/servicios/almacen_sin_conexion.dart';
import 'package:path/path.dart' as path;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native SQLite opens and the app reaches the login screen', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('vesta-startup-');
    final databasePath = path.join(directory.path, 'startup.db');
    var store = await AlmacenSinConexion.open(path: databasePath);
    try {
      final timeout = await store.db.rawQuery('PRAGMA busy_timeout');
      expect(timeout.single.values.single, 5000);
      final journal = await store.db.rawQuery('PRAGMA journal_mode');
      expect(journal.single.values.single, 'wal');
      await store.write('test-owner', '/users/me', {'full_name': 'Prueba'});
    } finally {
      await store.db.close();
    }

    store = await AlmacenSinConexion.open(path: databasePath);
    try {
      expect(await store.read('test-owner', '/users/me'), {
        'full_name': 'Prueba',
      });
    } finally {
      await store.db.close();
      await directory.delete(recursive: true);
    }

    await app.main();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
    expect(find.text('Iniciar Sesión'), findsWidgets);
  });
}
