import 'dart:async';

import 'package:cardia_kexa/main.dart';
import 'package:cbl/cbl.dart';

class AppManager {
  static final AppManager _instance = AppManager._internal();
  factory AppManager() => _instance;
  Collection? _colApps;
  Collection? _colCommands;
  Collection? _colLogs;
  AppManager._internal() {
    _init();
  }

  Future<void> _init() async {
    _colApps = await database.createCollection("apps");
    _colCommands = await database.createCollection("commands");
    _colLogs = await database.createCollection("logs");
  }

  Future<Collection> getColApps() async {
    _colApps ??= await database.createCollection("apps");
    return _colApps!;
  }

  Future<Collection> getColCommands() async {
    _colCommands ??= await database.createCollection("commands");
    return _colCommands!;
  }

  Future<Collection> getColLogs() async {
    _colLogs ??= await database.createCollection("logs");
    return _colLogs!;
  }

  Future<void> addLog(String log, String appId) async {
    final col = await getColLogs();
    final doc = MutableDocument({
      "log": log,
      "appId": appId,
      "createdAt": DateTime.now().toIso8601String(),
    });
    await col.saveDocument(doc);
    // retrieve newly created document by id
    await col.setDocumentExpiration(
      doc.id,
      DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  Future<void> removeLog(String id) async {
    final col = await getColLogs();
    final doc = await col.document(id);
    if (doc == null) {
      throw Exception("Document not found");
    }
    await col.deleteDocument(doc);
  }

  Future<List<Map<String, Object?>>> getLogs(String id) async {
    final col = await getColLogs();
    final query = const QueryBuilder()
        .select(
          SelectResult.property("log"),
          SelectResult.property("createdAt"),
        )
        .from(DataSource.collection(col))
        .where(Expression.property("appId").equalTo(Expression.string(id)));
    final snapshot = await query.execute();
    final results =
        await snapshot.asStream().map((event) {
          return {
            "log": event.string("log"),
            "createdAt": event.string("createdAt"),
          };
        }).toList();
    return results;
  }

  Future<void> clearLogs(String id) async {
    final col = await getColLogs();
    final query = const QueryBuilder()
        .select(SelectResult.property("id"))
        .from(DataSource.collection(col))
        .where(Expression.property("appId").equalTo(Expression.string(id)));
    final snapshot = await query.execute();
    final results =
        await snapshot.asStream().map((event) {
          return event.string("id");
        }).toList();
    for (var id in results) {
      final doc = await col.document(id.toString());
      if (doc != null) {
        await col.deleteDocument(doc);
      }
    }
  }

  Stream<List<Map<String, Object?>>> getLogsStream(String id) {
    late StreamController<List<Map<String, Object?>>> ctlr;
    StreamSubscription<CollectionChange>? triggerSubscription;

    Future<void> sendUpdate() async {
      var logs = await getLogs(id);
      if (!ctlr.isClosed) {
        ctlr.add(logs);
      }
    }

    ctlr = StreamController<List<Map<String, Object?>>>(
      onListen: () {
        sendUpdate();

        /// Listen for trigger
        final stream = _colLogs?.changes();
        triggerSubscription = stream?.listen((event) async {
          if (event.collection.name == "logs") {
            sendUpdate();
          }
        });
      },
      onCancel: () {
        triggerSubscription?.cancel();
      },
    );
    return ctlr.stream;
  }

  Future<void> addCommand(String id, Map<String, dynamic> data) async {
    final col = await getColCommands();
    final doc = MutableDocument.withId(id, {
      "id": id,
      "data": data,
      "createdAt": DateTime.now().toIso8601String(),
    });
    await col.saveDocument(doc);
  }

  Future<void> removeCommand(String id) async {
    final col = await getColCommands();
    final doc = await col.document(id);
    if (doc == null) {
      throw Exception("Document not found");
    }
    await col.deleteDocument(doc);
  }

  Future<void> updateCommand(String id, Map<String, dynamic> data) async {
    final col = await getColCommands();
    final doc = await col.document(id);
    if (doc == null) {
      throw Exception("Document not found");
    }
    MutableDocument mutableDoc = doc.toMutable();
    mutableDoc.setString(id, key: "id");
    mutableDoc.setValue(data, key: "data");
    await col.saveDocument(mutableDoc);
  }

  Future<Document?> getCommand(String id) async {
    final col = await getColCommands();
    final doc = await col.document(id);
    return doc;
  }

  Future<void> addApp(String id, String name, String token) async {
    final col = await getColApps();
    final doc = MutableDocument.withId(id, {
      "name": name,
      "id": id,
      "token": token,
      "createdAt": DateTime.now().toIso8601String(),
    });
    await col.saveDocument(doc);
  }

  Future<void> removeApp(String id) async {
    final col = await getColApps();
    final doc = await col.document(id);
    if (doc == null) {
      throw Exception("Document not found");
    }
    await col.deleteDocument(doc);
  }

  Future<void> updateApp(String id, String name, String token) async {
    final col = await getColApps();
    final doc = await col.document(id);
    if (doc == null) {
      throw Exception("Document not found");
    }
    MutableDocument mutableDoc = doc.toMutable();
    mutableDoc.setString(name, key: "name");
    mutableDoc.setString(id, key: "id");
    mutableDoc.setString(token, key: "token");
    await col.saveDocument(mutableDoc);
  }

  Future<Document?> getApp(String id) async {
    final col = await getColApps();
    final doc = await col.document(id);
    return doc;
  }

  Future<List<Map<String, Object?>>> getApps() async {
    final col = await getColApps();
    final query = const QueryBuilder()
        .select(SelectResult.property("id"), SelectResult.property("name"))
        .from(DataSource.collection(col));
    final snapshot = await query.execute();
    final results =
        await snapshot.asStream().map((event) {
          return {"id": event.string("id"), "name": event.string("name")};
        }).toList();
    return results;
  }

  Stream<List<Map<String, Object?>>> getAppsStream() {
    late StreamController<List<Map<String, Object?>>> ctlr;
    StreamSubscription? triggerSubscription;

    Future<void> sendUpdate() async {
      var apps = await getApps();
      if (!ctlr.isClosed) {
        ctlr.add(apps);
      }
    }

    ctlr = StreamController<List<Map<String, Object?>>>(
      onListen: () {
        sendUpdate();

        /// Listen for trigger
        triggerSubscription = _colApps?.changes().listen((event) async {
          if (event.collection.name == "apps") {
            sendUpdate();
          }
        });
      },
      onCancel: () {
        triggerSubscription?.cancel();
      },
    );
    return ctlr.stream;
  }

  // Add your properties and methods here
}
