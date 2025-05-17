import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;

class AppManager {
  static final AppManager _instance = AppManager._internal();
  factory AppManager() => _instance;
  final StreamController<List<dynamic>> _appsStreamController =
      StreamController<List<dynamic>>.broadcast();
  final Map<String, StreamController<List<Map<String, String>>>>
  _logController = {};
  List<dynamic> _apps = [];

  AppManager._internal() {
    _init();
  }

  static Future<String> _path() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<void> _init() async {
    final path = await _path();
    final apps = Directory("$path/apps");
    if (!await apps.exists()) {
      await apps.create(recursive: true);
    }
    await getAllApps();
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      _appsStreamController.add(_apps);
    }
  }

  Future<File> createOrUpdateApp(String id, String name, String token) async {
    final path = await _path();

    Map<String, String> data = {
      "name": name,
      "id": id,
      "token": token,
      "createdAt": DateTime.now().toIso8601String(),
    };
    developer.log("Creating or updating app: $data");
    final file = File("$path/apps/$id.json");
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(data));

    // We need to have refs to alls App Ids in another file. (only name and id inside is needed)
    final allAppsFile = File("$path/apps/all_apps.json");
    if (!await allAppsFile.exists()) {
      await allAppsFile.create(recursive: true);
    }
    List<dynamic> allAppsList = await getAllApps();
    // check if the app already exists
    bool exists = false;
    for (var app in allAppsList) {
      if (app["id"] == id) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      allAppsList.add({"name": name, "id": id});
    } else {
      // update the app
      for (var app in allAppsList) {
        if (app["id"] == id) {
          app["name"] = name;
          break;
        }
      }
    }
    await allAppsFile.writeAsString(jsonEncode(allAppsList));
    _apps = allAppsList;
    _appsStreamController.add(allAppsList);
    return file;
  }

  Future<void> deleteApp(String id) async {
    final path = await _path();
    final file = File("$path/apps/$id.json");
    if (await file.exists()) {
      await file.delete();
    }
    final currentAppDir = Directory("$path/apps/$id");
    if (await currentAppDir.exists()) {
      await currentAppDir.delete(recursive: true);
    }
    // We need to have refs to alls App Ids in another file. (only name and id inside is needed)
    final allAppsFile = File("$path/apps/all_apps.json");
    if (!await allAppsFile.exists()) {
      await allAppsFile.create(recursive: true);
    }
    final allApps = await allAppsFile.readAsString();
    // let's decode json
    List<dynamic> allAppsList = [];
    if (allApps.isNotEmpty) {
      developer.log("All Apps: $allApps");
      allAppsList = jsonDecode(allApps) as List<dynamic>;
    }
    // check if the app already exists
    for (var app in allAppsList) {
      if (app["id"] == id) {
        allAppsList.remove(app);
        break;
      }
    }
    await allAppsFile.writeAsString(jsonEncode(allAppsList));
    _apps = allAppsList;
    _appsStreamController.add(allAppsList);
  }

  Future<List<dynamic>> getAllApps() async {
    final path = await _path();
    final allAppsFile = File("$path/apps/all_apps.json");
    if (!await allAppsFile.exists()) {
      await allAppsFile.create(recursive: true);
    }
    final allApps = await allAppsFile.readAsString();
    // let's decode json
    List<dynamic> allAppsList = [];
    if (allApps.isNotEmpty) {
      allAppsList = jsonDecode(allApps) as List<dynamic>;
    }
    _apps = allAppsList;
    _appsStreamController.add(allAppsList);
    return allAppsList;
  }

  Stream<List<dynamic>> getAppStream() {
    // add trigger to the stream

    if (_appsStreamController.hasListener) {
      return _appsStreamController.stream;
    } else {
      return _appsStreamController.stream;
    }
  }

  Stream<List<dynamic>> getLogStream(String id) {
    if (_logController.containsKey(id)) {
      return _logController[id]!.stream;
    } else {
      final logStreamController =
          StreamController<List<Map<String, String>>>.broadcast();
      _logController[id] = logStreamController;
      return logStreamController.stream;
    }
  }

  Future<void> deleteAllApps() async {
    final path = await _path();
    final allAppsFile = File("$path/apps/all_apps.json");
    if (await allAppsFile.exists()) {
      // first let's read the file
      final allApps = await allAppsFile.readAsString();
      // let's decode json
      List<dynamic> allAppsList = [];
      if (allApps.isNotEmpty) {
        allAppsList = jsonDecode(allApps) as List<dynamic>;
      }
      // let's recursively delete all apps inside the list
      for (var app in allAppsList) {
        final appId = app["id"];
        await deleteApp(appId!);
      }
      await allAppsFile.delete();
    }
  }

  Future<Map<String, dynamic>> getApp(String id) async {
    final path = await _path();
    final file = File("$path/apps/$id.json");
    if (await file.exists()) {
      final data = await file.readAsString();
      // let's decode json
      var appData = <String, dynamic>{};
      if (data.isNotEmpty) {
        appData = jsonDecode(data) as Map<String, dynamic>;
      }
      return appData;
    }
    return {};
  }

  Future<Map<String, dynamic>> getAppCommand(
    String id,
    String commandId,
  ) async {
    final path = await _path();
    final file = File("$path/apps/$id/$commandId.json");
    if (await file.exists()) {
      final data = await file.readAsString();
      // let's decode json
      Map<String, dynamic> appData = {};
      if (data.isNotEmpty) {
        appData = jsonDecode(data) as Map<String, dynamic>;
      }
      developer.log("Command data: $appData");
      return appData;
    }
    return {};
  }

  Future<void> saveAppCommand(
    String id,
    String commandId,
    Map<String, dynamic> data,
  ) async {
    final path = await _path();
    final file = File("$path/apps/$id/$commandId.json");
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> deleteAppCommand(String id, String commandId) async {
    final path = await _path();
    final file = File("$path/apps/$id/$commandId.json");
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteAppCommands(String id) async {
    final path = await _path();
    final appDir = Directory("$path/apps/$id");
    if (await appDir.exists()) {
      final appFiles = await appDir.list().toList();
      for (var appFile in appFiles) {
        if (appFile.path.endsWith(".json")) {
          final appDataFile = File(appFile.path);
          await appDataFile.delete();
        }
      }
    }
  }

  Future<void> saveLog(String id, String log) async {
    final path = await _path();
    final file = File("$path/apps/$id/logs.json");
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    final data = await file.readAsString();
    List<Map<String, String>> logs = [];
    if (data.isNotEmpty) {
      logs = List<Map<String, String>>.from(jsonDecode(data));
    }
    logs.add({"log": log, "createdAt": DateTime.now().toIso8601String()});
    await file.writeAsString(jsonEncode(logs));
    // let's also add the log to the stream
    if (_logController.containsKey(id)) {
      _logController[id]!.add(logs);
    } else {
      final logStreamController = StreamController<List<Map<String, String>>>();
      _logController[id] = logStreamController;
      logStreamController.add(logs);
    }
  }

  Future<void> clearLogs(String id) async {
    final path = await _path();
    final file = File("$path/apps/$id/logs.json");
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteAllLogs() async {
    final path = await _path();
    final allAppsFile = File("$path/apps/all_apps.json");
    if (await allAppsFile.exists()) {
      // first let's read the file
      final allApps = await allAppsFile.readAsString();
      // let's decode json
      List<Map<String, String>> allAppsList = [];
      if (allApps.isNotEmpty) {
        allAppsList = List<Map<String, String>>.from(jsonDecode(allApps));
      }
      // let's recursively delete all logs inside the list
      for (var app in allAppsList) {
        final appId = app["id"];
        await clearLogs(appId!);
      }
    }
  }
}
