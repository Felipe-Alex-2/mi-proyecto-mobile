import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Account and API environment are part of every key. Tokens never enter SQLite.
class AlmacenSinConexion {
  final Database db;
  AlmacenSinConexion(this.db);

  static Future<AlmacenSinConexion> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final driver = factory ?? databaseFactory;
    final location =
        path ?? p.join(await driver.getDatabasesPath(), 'vesta_offline.db');
    final db = await driver.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onConfigure: (db) async {
          await db.rawQuery('PRAGMA busy_timeout = 5000');
          await db.rawQuery('PRAGMA journal_mode = WAL');
        },
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE cache (owner TEXT NOT NULL, path TEXT NOT NULL, data TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(owner,path))',
          );
          await db.execute(
            'CREATE TABLE outbox (seq INTEGER PRIMARY KEY AUTOINCREMENT, owner TEXT NOT NULL, id TEXT NOT NULL UNIQUE, method TEXT NOT NULL, path TEXT NOT NULL, body TEXT NOT NULL, preview TEXT, state TEXT NOT NULL DEFAULT \'pending\', error TEXT, created_at TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE INDEX outbox_owner_seq ON outbox(owner,seq)',
          );
          await db.execute(
            'CREATE TABLE id_map (owner TEXT NOT NULL, local_id TEXT NOT NULL, remote_id TEXT NOT NULL, PRIMARY KEY(owner,local_id))',
          );
        },
      ),
    );
    return AlmacenSinConexion(db);
  }

  Future<dynamic> read(String owner, String path) async {
    final rows = await db.query(
      'cache',
      where: 'owner=? AND path=?',
      whereArgs: [owner, path],
    );
    return rows.isEmpty ? null : jsonDecode(rows.first['data'] as String);
  }

  Future<void> write(
    String owner,
    String path,
    dynamic data, {
    DatabaseExecutor? tx,
  }) async {
    await (tx ?? db).insert('cache', {
      'owner': owner,
      'path': path,
      'data': jsonEncode(data),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> queue(String owner) => db.query(
    'outbox',
    where: 'owner=?',
    whereArgs: [owner],
    orderBy: 'seq ASC',
  );

  Future<String> resolve(String owner, String id) async {
    final rows = await db.query(
      'id_map',
      where: 'owner=? AND local_id=?',
      whereArgs: [owner, id],
    );
    return rows.isEmpty ? id : rows.first['remote_id'] as String;
  }
}
