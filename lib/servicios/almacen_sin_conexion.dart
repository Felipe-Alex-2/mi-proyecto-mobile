import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Account and API environment are part of every key. Tokens never enter SQLite.
class AlmacenSinConexion {
  static const chunkBytes = 128 * 1024;
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
        version: 2,
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
          await _createParts(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createParts(db);
        },
      ),
    );
    return AlmacenSinConexion(db);
  }

  static Future<void> _createParts(DatabaseExecutor db) => db.execute(
    'CREATE TABLE IF NOT EXISTS cache_parts (owner TEXT NOT NULL,path TEXT NOT NULL,part INTEGER NOT NULL,data BLOB NOT NULL,PRIMARY KEY(owner,path,part))',
  );

  Future<dynamic> read(String owner, String path, {DatabaseExecutor? tx}) =>
      tx == null
      ? db.transaction((transaction) => read(owner, path, tx: transaction))
      : _read(tx, owner, path);

  Future<dynamic> _read(DatabaseExecutor tx, String owner, String path) async {
    // Never SELECT a complete legacy JSON row: Android CursorWindow cannot fit it.
    final rows = await tx.query(
      'cache',
      columns: ['length(CAST(data AS BLOB)) AS byte_length'],
      where: 'owner=? AND path=?',
      whereArgs: [owner, path],
    );
    if (rows.isEmpty) return null;
    final size = rows.first['byte_length'] as int;
    final bytes = BytesBuilder(copy: false);
    if (size == 0) {
      final parts = await tx.query(
        'cache_parts',
        columns: ['part', 'data'],
        where: 'owner=? AND path=?',
        whereArgs: [owner, path],
        orderBy: 'part ASC',
      );
      for (var i = 0; i < parts.length; i++) {
        if (parts[i]['part'] != i) {
          throw const FormatException(
            'Datos locales incompletos. Actualiza el catálogo con Internet.',
          );
        }
        bytes.add(parts[i]['data'] as Uint8List);
      }
    } else {
      for (var offset = 0; offset < size; offset += chunkBytes) {
        final part = await tx.rawQuery(
          'SELECT substr(CAST(data AS BLOB),?,?) AS part FROM cache WHERE owner=? AND path=?',
          [offset + 1, chunkBytes, owner, path],
        );
        bytes.add(part.single['part'] as Uint8List);
      }
    }
    return jsonDecode(utf8.decode(bytes.takeBytes()));
  }

  Future<void> write(
    String owner,
    String path,
    dynamic data, {
    DatabaseExecutor? tx,
  }) async {
    if (tx == null) {
      await db.transaction(
        (transaction) => write(owner, path, data, tx: transaction),
      );
      return;
    }
    final encoded = jsonEncode(data), bytes = utf8.encode(encoded);
    await tx.delete(
      'cache_parts',
      where: 'owner=? AND path=?',
      whereArgs: [owner, path],
    );
    await tx.insert('cache', {
      'owner': owner,
      'path': path,
      'data': bytes.length > chunkBytes ? '' : encoded,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (bytes.length > chunkBytes) {
      for (
        var offset = 0, part = 0;
        offset < bytes.length;
        offset += chunkBytes, part++
      ) {
        final end = (offset + chunkBytes).clamp(0, bytes.length);
        await tx.insert('cache_parts', {
          'owner': owner,
          'path': path,
          'part': part,
          'data': Uint8List.sublistView(bytes, offset, end),
        });
      }
    }
  }

  Future<List<Map<String, Object?>>> queue([String? owner]) => db.transaction((
    tx,
  ) async {
    // Previews may contain inline product photos too. Read large text by slices,
    // including queues created by older app versions, without losing operations.
    final rows = await tx.query(
      'outbox',
      columns: [
        'seq',
        'owner',
        'id',
        'method',
        'path',
        'state',
        'error',
        'created_at',
        'length(CAST(body AS BLOB)) AS body_length',
        'length(CAST(preview AS BLOB)) AS preview_length',
      ],
      where: owner == null ? null : 'owner=?',
      whereArgs: owner == null ? null : [owner],
      orderBy: 'seq ASC',
    );
    final result = <Map<String, Object?>>[];
    for (final row in rows) {
      final value = Map<String, Object?>.from(row);
      for (final field in ['body', 'preview']) {
        final size = value.remove('${field}_length') as int?;
        if (size == null) {
          value[field] = null;
          continue;
        }
        final bytes = BytesBuilder(copy: false);
        for (var offset = 0; offset < size; offset += chunkBytes) {
          final part = await tx.rawQuery(
            'SELECT substr(CAST($field AS BLOB),?,?) AS part FROM outbox WHERE seq=? AND owner=?',
            [offset + 1, chunkBytes, row['seq'], row['owner']],
          );
          bytes.add(part.single['part'] as Uint8List);
        }
        value[field] = utf8.decode(bytes.takeBytes());
      }
      result.add(value);
    }
    return result;
  });

  Future<String> resolve(String owner, String id) async {
    final rows = await db.query(
      'id_map',
      where: 'owner=? AND local_id=?',
      whereArgs: [owner, id],
    );
    return rows.isEmpty ? id : rows.first['remote_id'] as String;
  }
}
