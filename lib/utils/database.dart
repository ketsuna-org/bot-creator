import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bot_creator/utils/global.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nyxx/nyxx.dart';

class AppManager {
  static final AppManager _instance = AppManager._internal();
  factory AppManager() => _instance;
  final StreamController<List<dynamic>> _appsStreamController =
      StreamController<List<dynamic>>.broadcast();
  List<dynamic> _apps = [];

  AppManager._internal() {
    _init();
  }

  static Future<String> _path() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<String> get path async =>
      (await getApplicationDocumentsDirectory()).path;

  Future<void> _init() async {
    final path = await _path();
    final appsDir = Directory("$path/apps");
    if (!await appsDir.exists()) await appsDir.create(recursive: true);

    await getAllApps();
    _startStreamUpdateLoop();
  }

  void _startStreamUpdateLoop() async {
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      _appsStreamController.add(_apps);
    }
  }

  Future<File> createOrUpdateApp(User user, String token) async {
    final path = await _path();
    final file = File("$path/apps/${user.id}.json");
    final allAppsFile = File("$path/apps/all_apps.json");
    final avatarUri = makeAvatarUrl(
      user.id.toString(),
      avatarId: user.avatarHash,
      discriminator: user.discriminator,
    );
    final data = {
      "name": user.username,
      "id": user.id.toString(),
      "avatar": avatarUri,
      "token": token,
      "createdAt": DateTime.now().toIso8601String(),
    };

    await file.writeAsString(jsonEncode(data));
    if (!await allAppsFile.exists()) await allAppsFile.create(recursive: true);

    final appsList = await getAllApps();
    final index = appsList.indexWhere((a) => a['id'] == user.id.toString());
    if (index >= 0) {
      appsList[index]['name'] = user.username;
      appsList[index]['avatar'] = avatarUri;
    } else {
      appsList.add({
        "name": user.username,
        "avatar": avatarUri,
        "id": user.id.toString(),
      });
    }

    await allAppsFile.writeAsString(jsonEncode(appsList));
    _apps = appsList;
    _appsStreamController.add(appsList);
    return file;
  }

  Future<void> deleteApp(String id) async {
    final path = await _path();
    await File("$path/apps/$id.json").delete();
    await Directory("$path/apps/$id").delete(recursive: true);
    final allAppsFile = File("$path/apps/all_apps.json");
    if (!await allAppsFile.exists()) return;

    final content = await allAppsFile.readAsString();
    final appsList =
        content.isNotEmpty ? jsonDecode(content) as List<dynamic> : [];
    appsList.removeWhere((a) => a['id'] == id);

    await allAppsFile.writeAsString(jsonEncode(appsList));
    _apps = appsList;
    _appsStreamController.add(appsList);
  }

  Future<List<dynamic>> getAllApps() async {
    final path = await _path();
    final file = File("$path/apps/all_apps.json");
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    final appsList = content.isNotEmpty ? jsonDecode(content) : [];
    _apps = appsList;
    return appsList;
  }

  Stream<List<dynamic>> getAppStream() => _appsStreamController.stream;

  Future<void> clearLogs(String id) async {
    final path = await _path();
    await File("$path/apps/$id/logs.json").delete();
  }

  Future<void> deleteAllLogs() async {
    final apps = await getAllApps();
    for (final app in apps) {
      await clearLogs(app["id"]);
    }
  }

  Future<Map<String, dynamic>> getApp(String id) async {
    final path = await _path();
    final file = File("$path/apps/$id.json");
    if (!await file.exists()) return {};

    final data = await file.readAsString();
    return data.isNotEmpty ? jsonDecode(data) : {};
  }

  Future<Map<String, dynamic>> getAppCommand(
    String id,
    String commandId,
  ) async {
    final path = await _path();
    final file = File("$path/apps/$id/$commandId.json");
    if (!await file.exists()) return {};

    final data = await file.readAsString();
    if (data.isEmpty) return {};

    final decoded = Map<String, dynamic>.from(jsonDecode(data));
    final normalized = normalizeCommandData(decoded);
    if (!_deepEquals(decoded, normalized)) {
      await file.writeAsString(jsonEncode(normalized));
    }

    return normalized;
  }

  Future<void> saveAppCommand(
    String id,
    String commandId,
    Map<String, dynamic> data,
  ) async {
    final path = await _path();
    final file = File("$path/apps/$id/$commandId.json");
    if (!await file.exists()) await file.create(recursive: true);
    await file.writeAsString(jsonEncode(normalizeCommandData(data)));
  }

  Map<String, dynamic> normalizeCommandData(Map<String, dynamic> command) {
    final normalized = Map<String, dynamic>.from(command);
    final rawData = Map<String, dynamic>.from(
      (normalized['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    final legacyResponse = rawData['response'];
    final response = Map<String, dynamic>.from(
      (legacyResponse is Map)
          ? legacyResponse.cast<String, dynamic>()
          : {
            'mode': 'text',
            'text': legacyResponse?.toString() ?? '',
            'embed': {'title': '', 'description': '', 'url': ''},
            'embeds': <Map<String, dynamic>>[],
          },
    );

    final legacySingleEmbed = Map<String, dynamic>.from(
      (response['embed'] as Map?)?.cast<String, dynamic>() ??
          {'title': '', 'description': '', 'url': ''},
    );
    final embeds =
        (response['embeds'] is List)
            ? List<Map<String, dynamic>>.from(
              (response['embeds'] as List).whereType<Map>().map(
                (embed) => Map<String, dynamic>.from(embed),
              ),
            )
            : <Map<String, dynamic>>[];

    final hasLegacyEmbed =
        (legacySingleEmbed['title']?.toString().isNotEmpty ?? false) ||
        (legacySingleEmbed['description']?.toString().isNotEmpty ?? false) ||
        (legacySingleEmbed['url']?.toString().isNotEmpty ?? false);
    if (embeds.isEmpty && hasLegacyEmbed) {
      embeds.add(legacySingleEmbed);
    }

    final actions =
        (rawData['actions'] is List)
            ? List<Map<String, dynamic>>.from(
              (rawData['actions'] as List).whereType<Map>().map(
                (action) => Map<String, dynamic>.from(action),
              ),
            )
            : <Map<String, dynamic>>[];

    normalized['data'] = {
      'version': 1,
      'response': {
        'mode':
            (embeds.isNotEmpty ? 'embed' : (response['mode'] ?? 'text'))
                .toString(),
        'text': (response['text'] ?? '').toString(),
        'embed':
            embeds.isNotEmpty
                ? embeds.first
                : {'title': '', 'description': '', 'url': ''},
        'embeds': embeds.take(10).toList(),
      },
      'actions': actions,
    };

    return normalized;
  }

  bool _deepEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    return jsonEncode(a) == jsonEncode(b);
  }

  Future<void> deleteAppCommand(String id, String commandId) async {
    final path = await _path();
    final file = File("$path/apps/$id/$commandId.json");
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAppCommands(String id) async {
    final path = await _path();
    final dir = Directory("$path/apps/$id");
    if (!await dir.exists()) return;

    final files = await dir.list().toList();
    for (final file in files) {
      if (file is File && file.path.endsWith(".json")) {
        await file.delete();
      }
    }
  }

  Future<List<FileSystemEntity>> getAllAppDirectory() async {
    final path = await _path();
    final dir = Directory("$path/apps");
    if (!await dir.exists()) return [];

    final files = await dir.list(recursive: true).toList();
    final allAppsFile = File("$path/apps/all_apps.json");
    if (await allAppsFile.exists()) files.add(allAppsFile);
    return files;
  }

  Future<void> deleteAllApps() async {
    final apps = await getAllApps();
    for (final app in apps) {
      await deleteApp(app['id']);
    }
  }
}
