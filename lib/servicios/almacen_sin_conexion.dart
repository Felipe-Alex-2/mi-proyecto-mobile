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

  /// One SELECT gives a consistent snapshot without BEGIN IMMEDIATE. Readers
  /// must not compete for the writer lock held by the background sync isolate.
  Future<dynamic> read(
    String owner,
    String path, {
    DatabaseExecutor? tx,
  }) async {
    final rows = await (tx ?? db).rawQuery(
      '''WITH RECURSIVE slices(start, size) AS (
      SELECT 1, length(CAST(data AS BLOB)) FROM cache
        WHERE owner=? AND path=? AND data<>''
      UNION ALL SELECT start+$chunkBytes,size FROM slices WHERE start+$chunkBytes<=size
    )
    SELECT slices.start AS position, substr(CAST(c.data AS BLOB),slices.start,$chunkBytes) AS bytes
      FROM slices JOIN cache c ON c.owner=? AND c.path=?
    UNION ALL
    SELECT (part*$chunkBytes)+1 AS position, data AS bytes FROM cache_parts
      WHERE owner=? AND path=? AND EXISTS
        (SELECT 1 FROM cache WHERE owner=? AND path=? AND data='')
    ORDER BY position''',
      [owner, path, owner, path, owner, path, owner, path],
    );
    if (rows.isEmpty) return null;
    final bytes = BytesBuilder(copy: false);
    var expected = 1;
    for (final row in rows) {
      if (row['position'] != expected) {
        throw const FormatException(
          'Datos locales incompletos. Actualiza el catálogo con Internet.',
        );
      }
      final part = row['bytes'] as Uint8List;
      bytes.add(part);
      expected += part.length;
    }
    return jsonDecode(utf8.decode(bytes.takeBytes()));
  }

  Future<T> transaction<T>(Future<T> Function(Transaction) action) async {
    // Another Android isolate can briefly own the writer connection. Retry only
    // transactions rolled back by SQLite; never repeat network/payment calls.
    for (var attempt = 0; ; attempt++) {
      try {
        return await db.transaction(action, exclusive: false);
      } on DatabaseException catch (e) {
        final message = e.toString().toLowerCase();
        if (attempt >= 4 ||
            !(message.contains('database is locked') ||
                message.contains('sqlite_busy'))) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 150 * (attempt + 1)));
      }
    }
  }

  Future<void> write(
    String owner,
    String path,
    dynamic data, {
    DatabaseExecutor? tx,
  }) async {
    if (tx == null) {
      await transaction(
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

  Future<List<Map<String, Object?>>> queue([String? owner]) async {
    final filter = owner == null ? '' : 'WHERE owner=?';
    final rows = await db.rawQuery(
      '''WITH RECURSIVE pieces(seq,field,start,size) AS (
      SELECT seq,'body',1,length(CAST(body AS BLOB)) FROM outbox $filter
      UNION ALL SELECT seq,'preview',1,length(CAST(preview AS BLOB)) FROM outbox $filter
      UNION ALL SELECT seq,field,start+$chunkBytes,size FROM pieces WHERE start+$chunkBytes<=size
    )
    SELECT o.seq,o.owner,o.id,o.method,o.path,o.state,o.error,o.created_at,
      pieces.field,pieces.start,
      substr(CAST(CASE pieces.field WHEN 'body' THEN o.body ELSE o.preview END AS BLOB),pieces.start,$chunkBytes) AS bytes
    FROM pieces JOIN outbox o ON o.seq=pieces.seq ORDER BY o.seq,pieces.field,pieces.start''',
      owner == null ? [] : [owner, owner],
    );
    final result = <Map<String, Object?>>[];
    Map<String, Object?>? value;
    BytesBuilder? bytes;
    String? field;
    void finish() {
      if (bytes != null) value![field!] = utf8.decode(bytes.takeBytes());
    }

    for (final row in rows) {
      if (value?['seq'] != row['seq'] || field != row['field']) {
        finish();
        if (value?['seq'] != row['seq']) {
          value = Map<String, Object?>.from(row)
            ..remove('field')
            ..remove('start')
            ..remove('bytes');
          result.add(value);
        }
        field = row['field'] as String;
        bytes = row['bytes'] == null ? null : BytesBuilder(copy: false);
        value![field] = null;
      }
      if (row['bytes'] != null) bytes!.add(row['bytes'] as Uint8List);
    }
    finish();
    return result;
  }

  Future<String> resolve(String owner, String id) async {
    final rows = await db.query(
      'id_map',
      where: 'owner=? AND local_id=?',
      whereArgs: [owner, id],
    );
    return rows.isEmpty ? id : rows.first['remote_id'] as String;
  }
}
