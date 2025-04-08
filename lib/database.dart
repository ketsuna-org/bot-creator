import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseProvider {
  static final DatabaseProvider _instance = DatabaseProvider._internal();
  factory DatabaseProvider() => _instance;

  Database? _database;
  final Completer<void> _databaseCompleter = Completer<void>();
  final StreamController<String> _triggerController =
      StreamController<String>.broadcast();

  DatabaseProvider._internal() {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = "$databasePath/cardia_kexa.db";

    try {
      await Directory(databasePath).create(recursive: true);

      _database = await openDatabase(
        path,
        version: 1,
        onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
        onOpen: // This is only called for Debugging purposes
            (db) async => {
              // let's remove everything first
              db.execute('DELETE FROM apps'),
              db.execute('DELETE FROM components'),
              // we need to remove the tables too
              db.execute('DROP TABLE IF EXISTS apps'),
              db.execute('DROP TABLE IF EXISTS components'),

              // and recreate them
              await _onCreate(db, 1),
            },
      );

      _databaseCompleter.complete();
    } catch (e) {
      _databaseCompleter.completeError(e);
      print("Erreur d'initialisation de la base de données : $e");
    }
  }

  Future<Database> get database async {
    if (!_databaseCompleter.isCompleted) {
      await _databaseCompleter.future;
    }
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.execute(
        'CREATE TABLE apps ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'token TEXT NOT NULL,'
        'name TEXT NOT NULL'
        ')',
      );

      await db.execute(
        'CREATE TABLE components ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'name TEXT NOT NULL,'
        'content TEXT NOT NULL,'
        'app_id INTEGER NOT NULL,'
        'execute_after INTEGER DEFAULT NULL,'
        'FOREIGN KEY (app_id) REFERENCES apps (id) ON DELETE CASCADE'
        ')',
      );
    } catch (e) {
      print("Erreur lors de la création des tables : $e");
    }
  }

  Future<int> addApp(String name, String token) async {
    if (name.isEmpty || token.isEmpty) {
      throw ArgumentError(
        'Nom et token requis pour l\'ajout d\'une application',
      );
    }
    final db = await database;
    try {
      final int id = await db.insert('apps', {
        'name': name,
        'token': token,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      triggerUpdate("addApp");
      return id;
    } catch (e) {
      print("Erreur d'ajout d'une application : $e");
      rethrow;
    }
  }

  Future<void> deleteApp(int id) async {
    final db = await database;

    try {
      await db.delete('apps', where: 'id = ?', whereArgs: [id]);
      triggerUpdate("deleteApp");
    } catch (e) {
      print("Erreur de suppression d'une application : $e");
      rethrow;
    }
  }

  Future<void> updateApp(int id, {String name = "", String token = ""}) async {
    final db = await database;
    try {
      if (name.isEmpty && token.isEmpty) {
        throw ArgumentError(
          'Nom ou token requis pour la mise à jour d\'une application',
        );
      }

      await db.update(
        'apps',
        {'token': token, 'name': name},
        where: 'id = ?',
        whereArgs: [id],
      );
      triggerUpdate("updateApp");
    } catch (e) {
      print("Erreur de mise à jour d'une application : $e");
      rethrow;
    }
  }

  Future<DbApp> getApp(int id) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> results = await db.query(
        'apps',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (results.isNotEmpty) {
        return DbApp.fromJson(results.first);
      } else {
        throw Exception('Aucune application trouvée avec cet ID : $id');
      }
    } catch (e) {
      throw Exception(
        'Erreur de récupération de l\'application avec ID $id : $e',
      );
    }
  }

  Future<List<DbApp>> getApps() async {
    final db = await database;
    try {
      return await db.query('apps').then((List<Map<String, dynamic>> results) {
        return results.map((json) => DbApp.fromJson(json)).toList();
      });
    } catch (e) {
      print("Erreur de récupération des applications : $e");
      rethrow;
    }
  }

  Stream<List<DbApp>> getAppsStream() {
    late StreamController<List<DbApp>> ctlr;
    StreamSubscription? triggerSubscription;

    Future<void> sendUpdate() async {
      var apps = await getApps();
      if (!ctlr.isClosed) {
        ctlr.add(apps);
      }
    }

    ctlr = StreamController<List<DbApp>>(
      onListen: () {
        sendUpdate();

        /// Listen for trigger
        triggerSubscription = _triggerController.stream.listen((_) {
          sendUpdate();
        });
      },
      onCancel: () {
        triggerSubscription?.cancel();
      },
    );
    return ctlr.stream;
  }

  void triggerUpdate(String event) {
    if (!_triggerController.isClosed) {
      _triggerController.sink.add(event);
    }
  }

  Future<void> close() async {
    await _triggerController.close();
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
  }
}

@immutable
class DbApp {
  final int id;
  final String token;
  final String name;

  const DbApp({required this.id, required this.name, this.token = ""});

  factory DbApp.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null || json['name'] == null || json['token'] == null) {
      throw FormatException('JSON invalide pour DbApp');
    }
    return DbApp(
      id: json['id'] as int,
      token: json['token'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'token': token, 'name': name};
}
