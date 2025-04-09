import 'dart:async';

import 'package:cardia_kexa/main.dart';
import 'package:cbl/cbl.dart';

class AppManager {
  static final AppManager _instance = AppManager._internal();
  factory AppManager() => _instance;
  Collection? _col;
  final StreamController<String> controller =
      StreamController<String>.broadcast();

  AppManager._internal() {
    _init();
  }

  Future<void> _init() async {
    _col = await database.createCollection("apps");
  }

  Future<Collection> getCol() async {
    _col ??= await database.createCollection("apps");
    return _col!;
  }

  Future<void> addApp(String id, String name, String token) async {
    final col = await getCol();
    final doc = MutableDocument.withId(id, {
      "name": name,
      "id": id,
      "token": token,
      "createdAt": DateTime.now().toIso8601String(),
    });
    await col.saveDocument(doc);
    controller.sink.add("add");
  }

  Future<void> removeApp(String id) async {
    final col = await getCol();
    final doc = await col.document(id);
    if (doc == null) {
      throw Exception("Document not found");
    }
    await col.deleteDocument(doc);
    controller.sink.add("remove");
  }

  Future<void> updateApp(String id, String name, String token) async {
    final col = await getCol();
    final doc = await col.document(id);
    if (doc == null) {
      throw Exception("Document not found");
    }
    MutableDocument mutableDoc = doc.toMutable();
    mutableDoc.setString(name, key: "name");
    mutableDoc.setString(id, key: "id");
    mutableDoc.setString(token, key: "token");
    await col.saveDocument(mutableDoc);
    controller.sink.add("update");
  }

  Future<Document?> getApp(String id) async {
    final col = await getCol();
    final doc = await col.document(id);
    return doc;
  }

  Future<List<Map<String, Object?>>> getApps() async {
    final col = await getCol();
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
        triggerSubscription = controller.stream.listen((_) {
          sendUpdate();
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
