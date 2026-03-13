import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:crypto/crypto.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;
import 'package:http/http.dart' as http;

const String _backupRootFolderName = 'backups_v2';
const String _backupMetaFileName = '__meta__.json';
const String _snapshotArchiveFileName = 'apps_snapshot.zip';
const String _defaultDesktopClientId =
    '777382167262-tf9rvusrqqd2fnsal8s7bfe80ur21n11.apps.googleusercontent.com';
const String _defaultDesktopClientSecret =
    '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';
const List<String> _driveScopes = <String>[gdrive.DriveApi.driveAppdataScope];

Future<BotConfig> loadConfigFromGoogleDrive({
  required String botId,
  String? snapshotId,
  String? clientId,
  String? clientSecret,
  bool openBrowser = true,
  Duration callbackTimeout = const Duration(minutes: 5),
  void Function(String message)? onInfo,
}) async {
  final resolvedClientId = (clientId ?? '').trim();
  final resolvedClientSecret = (clientSecret ?? '').trim();
  final oauthClientId =
      resolvedClientId.isEmpty ? _defaultDesktopClientId : resolvedClientId;
  final oauthClientSecret =
      resolvedClientSecret.isEmpty
          ? _defaultDesktopClientSecret
          : resolvedClientSecret;

  final tokenStore = _TokenStore();
  final oauth = _GoogleDriveOAuth(
    clientId: oauthClientId,
    clientSecret: oauthClientSecret,
    tokenStore: tokenStore,
    callbackTimeout: callbackTimeout,
    openBrowser: openBrowser,
  );

  final token = await oauth.getValidToken(onInfo: onInfo);
  final authClient = _AccessTokenClient(token.accessToken);
  final drive = gdrive.DriveApi(authClient);
  try {
    return await _loadConfigFromDriveData(
      drive,
      botId: botId,
      snapshotId: snapshotId,
      onInfo: onInfo,
    );
  } finally {
    authClient.close();
  }
}

Future<BotConfig> _loadConfigFromDriveData(
  gdrive.DriveApi drive, {
  required String botId,
  String? snapshotId,
  void Function(String message)? onInfo,
}) async {
  final root = await _findNamedChild(
    drive,
    parentId: '',
    name: _backupRootFolderName,
    folderOnly: true,
  );
  if (root?.id == null) {
    throw Exception(
      'Google Drive backups folder not found: $_backupRootFolderName',
    );
  }

  final selectedSnapshot = await _selectSnapshotFolder(
    drive,
    backupsRootId: root!.id!,
    botId: botId,
    explicitSnapshotId: snapshotId,
  );
  if (selectedSnapshot == null || selectedSnapshot.id == null) {
    if (snapshotId != null && snapshotId.trim().isNotEmpty) {
      throw Exception('Snapshot not found: $snapshotId');
    }
    throw Exception('No backup snapshots found in $_backupRootFolderName.');
  }

  onInfo?.call('Using snapshot: ${selectedSnapshot.name}');

  final archiveFile = await _findNamedChild(
    drive,
    parentId: selectedSnapshot.id!,
    name: _snapshotArchiveFileName,
  );
  if (archiveFile?.id == null) {
    throw Exception(
      'Snapshot "${selectedSnapshot.name}" does not contain $_snapshotArchiveFileName',
    );
  }

  final archiveBytes = await _downloadFileBytes(drive, archiveFile!.id!);
  return _buildBotConfigFromSnapshotZip(archiveBytes, botId: botId);
}

BotConfig _buildBotConfigFromSnapshotZip(
  List<int> zipBytes, {
  required String botId,
}) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  ArchiveFile? appFile;
  final commandFiles = <ArchiveFile>[];

  for (final entry in archive) {
    if (!entry.isFile) {
      continue;
    }
    final name = _normalizeZipEntryPath(entry.name);
    if (name == '$botId.json') {
      appFile = entry;
      continue;
    }
    if (name.startsWith('$botId/') && name.endsWith('.json')) {
      commandFiles.add(entry);
    }
  }

  if (appFile == null) {
    throw Exception('No app file "$botId.json" found in snapshot archive.');
  }

  final appJson = _decodeArchiveJson(appFile);
  final commands = <Map<String, dynamic>>[];
  for (final file in commandFiles) {
    final json = _decodeArchiveJson(file);
    final id = (json['id'] ?? '').toString().trim();
    final name = (json['name'] ?? '').toString().trim();
    if (id.isEmpty || name.isEmpty) {
      continue;
    }
    final normalized = Map<String, dynamic>.from(json);
    normalized['id'] = id;
    normalized['name'] = name;
    normalized['data'] = Map<String, dynamic>.from(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    commands.add(normalized);
  }

  final config = BotConfig(
    token: (appJson['token'] ?? '').toString(),
    intents: _toBoolMap(appJson['intents']),
    globalVariables: _toStringMap(appJson['globalVariables']),
    workflows: _toMapList(appJson['workflows']),
    commands: commands,
  );
  config.validate();
  return config;
}

Map<String, dynamic> _decodeArchiveJson(ArchiveFile file) {
  final content = file.content as List<int>;
  final raw = utf8.decode(content);
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw FormatException(
      'Expected object JSON in archive entry: ${file.name}',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

Map<String, bool> _toBoolMap(dynamic raw) {
  if (raw is! Map) {
    return const {};
  }
  return raw.map((key, value) => MapEntry(key.toString(), value == true));
}

Map<String, String> _toStringMap(dynamic raw) {
  if (raw is! Map) {
    return const {};
  }
  return raw.map(
    (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
  );
}

List<Map<String, dynamic>> _toMapList(dynamic raw) {
  if (raw is! List) {
    return const [];
  }
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Future<gdrive.File?> _selectSnapshotFolder(
  gdrive.DriveApi drive, {
  required String backupsRootId,
  required String botId,
  String? explicitSnapshotId,
}) async {
  if (explicitSnapshotId != null && explicitSnapshotId.trim().isNotEmpty) {
    return _findNamedChild(
      drive,
      parentId: backupsRootId,
      name: explicitSnapshotId.trim(),
      folderOnly: true,
    );
  }

  final folders = await _listChildren(drive, parentId: backupsRootId);
  final snapshots =
      folders
          .where((f) => f.mimeType == 'application/vnd.google-apps.folder')
          .where((f) => f.id != null && f.name != null)
          .toList();
  if (snapshots.isEmpty) {
    return null;
  }

  final candidates = <_SnapshotCandidate>[];
  for (final folder in snapshots) {
    final metaFile = await _findNamedChild(
      drive,
      parentId: folder.id!,
      name: _backupMetaFileName,
    );
    var includesBot = false;
    DateTime? createdAt = folder.createdTime?.toUtc();
    if (metaFile?.id != null) {
      final meta = await _readJsonFile(drive, fileId: metaFile!.id!);
      if (meta != null) {
        final apps = (meta['apps'] as List?)?.whereType<Map>() ?? const <Map>[];
        includesBot = apps.any(
          (app) => (app['id'] ?? '').toString().trim() == botId,
        );
        final createdRaw = (meta['createdAt'] ?? '').toString().trim();
        final parsed = DateTime.tryParse(createdRaw);
        if (parsed != null) {
          createdAt = parsed.toUtc();
        }
      }
    }

    candidates.add(
      _SnapshotCandidate(
        folder: folder,
        createdAt:
            createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        includesBot: includesBot,
      ),
    );
  }

  candidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  for (final candidate in candidates) {
    if (candidate.includesBot) {
      return candidate.folder;
    }
  }
  return candidates.first.folder;
}

Future<List<int>> _downloadFileBytes(
  gdrive.DriveApi drive,
  String fileId,
) async {
  final response = await drive.files.get(
    fileId,
    downloadOptions: gdrive.DownloadOptions.fullMedia,
  );
  if (response is! gdrive.Media) {
    throw Exception('Failed to download file from Google Drive.');
  }
  final chunks = await response.stream.toList();
  return chunks.expand((chunk) => chunk).toList(growable: false);
}

Future<List<gdrive.File>> _listChildren(
  gdrive.DriveApi drive, {
  required String parentId,
}) async {
  final q = "trashed=false and '$parentId' in parents";
  final result = await drive.files.list(
    q: q,
    spaces: 'appDataFolder',
    $fields:
        'files(id, name, parents, mimeType, createdTime, modifiedTime, size)',
  );
  return result.files ?? const <gdrive.File>[];
}

Future<gdrive.File?> _findNamedChild(
  gdrive.DriveApi drive, {
  required String parentId,
  required String name,
  bool folderOnly = false,
}) async {
  final escapedName = name.replaceAll("'", r"\'");
  final parentClause =
      parentId.isEmpty
          ? "'appDataFolder' in parents"
          : "'$parentId' in parents";
  final mimeClause =
      folderOnly ? " and mimeType='application/vnd.google-apps.folder'" : '';
  final query =
      "trashed=false and $parentClause and name='$escapedName'$mimeClause";
  final result = await drive.files.list(
    q: query,
    spaces: 'appDataFolder',
    pageSize: 1,
    $fields:
        'files(id, name, parents, mimeType, createdTime, modifiedTime, size)',
  );
  final files = result.files ?? const <gdrive.File>[];
  if (files.isEmpty) {
    return null;
  }
  return files.first;
}

Future<Map<String, dynamic>?> _readJsonFile(
  gdrive.DriveApi drive, {
  required String fileId,
}) async {
  final response = await drive.files.get(
    fileId,
    downloadOptions: gdrive.DownloadOptions.fullMedia,
  );
  if (response is! gdrive.Media) {
    return null;
  }
  final chunks = await response.stream.toList();
  final bytes = chunks.expand((chunk) => chunk).toList(growable: false);
  final raw = utf8.decode(bytes);
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    return null;
  }
  return Map<String, dynamic>.from(
    decoded.map((key, value) => MapEntry(key.toString(), value)),
  );
}

String _normalizeZipEntryPath(String input) {
  var value = input.replaceAll('\\', '/').trim();
  if (value.startsWith('./')) {
    value = value.substring(2);
  }
  while (value.startsWith('/')) {
    value = value.substring(1);
  }
  return value;
}

class _SnapshotCandidate {
  const _SnapshotCandidate({
    required this.folder,
    required this.createdAt,
    required this.includesBot,
  });

  final gdrive.File folder;
  final DateTime createdAt;
  final bool includesBot;
}

class _OAuthToken {
  const _OAuthToken({
    required this.accessToken,
    required this.expiry,
    required this.refreshToken,
  });

  final String accessToken;
  final DateTime expiry;
  final String? refreshToken;

  bool get isValid =>
      accessToken.isNotEmpty &&
      expiry.isAfter(DateTime.now().add(const Duration(minutes: 1)));
}

class _TokenStore {
  Future<File> _file() async {
    final envPath = Platform.environment['BOT_CREATOR_RUNNER_TOKEN_CACHE'];
    if (envPath != null && envPath.trim().isNotEmpty) {
      final custom = File(envPath.trim());
      custom.parent.createSync(recursive: true);
      return custom;
    }

    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    String basePath;
    if (xdg != null && xdg.trim().isNotEmpty) {
      basePath = xdg.trim();
    } else if (Platform.environment['HOME'] case final home?
        when home.trim().isNotEmpty) {
      basePath = _join(home.trim(), '.config');
    } else if (Platform.environment['USERPROFILE'] case final profile?
        when profile.trim().isNotEmpty) {
      basePath = _join(profile.trim(), '.config');
    } else {
      basePath = Directory.systemTemp.path;
    }

    final dir = Directory(_join(basePath, 'bot_creator_runner'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File(_join(dir.path, 'google_drive_tokens.json'));
  }

  Future<_OAuthToken?> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) {
        return null;
      }
      final raw = file.readAsStringSync();
      if (raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final json = Map<String, dynamic>.from(decoded);
      final accessToken = (json['access_token'] ?? '').toString();
      final refreshTokenRaw = (json['refresh_token'] ?? '').toString().trim();
      final refreshToken = refreshTokenRaw.isEmpty ? null : refreshTokenRaw;
      final expiryRaw = (json['expiry'] ?? '').toString();
      final parsedExpiry = DateTime.tryParse(expiryRaw)?.toUtc();
      final expiry =
          parsedExpiry ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      if (accessToken.isEmpty) {
        return null;
      }
      return _OAuthToken(
        accessToken: accessToken,
        expiry: expiry,
        refreshToken: refreshToken,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(_OAuthToken token) async {
    final file = await _file();
    file.writeAsStringSync(
      jsonEncode({
        'access_token': token.accessToken,
        'refresh_token': token.refreshToken,
        'expiry': token.expiry.toUtc().toIso8601String(),
      }),
      flush: true,
    );
  }
}

class _GoogleDriveOAuth {
  _GoogleDriveOAuth({
    required this.clientId,
    required this.clientSecret,
    required this.tokenStore,
    required this.callbackTimeout,
    required this.openBrowser,
  });

  final String clientId;
  final String clientSecret;
  final _TokenStore tokenStore;
  final Duration callbackTimeout;
  final bool openBrowser;

  Future<_OAuthToken> getValidToken({
    void Function(String message)? onInfo,
  }) async {
    final cached = await tokenStore.load();
    if (cached != null && cached.isValid) {
      return cached;
    }

    if (cached?.refreshToken case final refreshToken?) {
      try {
        final refreshed = await _refreshToken(refreshToken);
        await tokenStore.save(refreshed);
        return refreshed;
      } catch (_) {
        // Continue with full OAuth flow below.
      }
    }

    final fresh = await _runOAuthAuthorizationCodeFlow(onInfo: onInfo);
    await tokenStore.save(fresh);
    return fresh;
  }

  Future<_OAuthToken> _refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Token refresh failed: ${response.body}');
    }
    final json = jsonDecode(response.body);
    if (json is! Map) {
      throw Exception('Token refresh failed: unexpected response format.');
    }
    final payload = Map<String, dynamic>.from(json);
    final accessToken = (payload['access_token'] ?? '').toString();
    if (accessToken.isEmpty) {
      throw Exception('Token refresh failed: missing access token.');
    }
    final refresh =
        (payload['refresh_token'] ?? '').toString().trim().isEmpty
            ? refreshToken
            : (payload['refresh_token'] ?? '').toString().trim();
    final expiresIn = (payload['expires_in'] as num?)?.toInt() ?? 3600;
    return _OAuthToken(
      accessToken: accessToken,
      refreshToken: refresh,
      expiry: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  Future<_OAuthToken> _runOAuthAuthorizationCodeFlow({
    void Function(String message)? onInfo,
  }) async {
    final verifier = _generatePkceVerifier(96);
    final challenge = _base64UrlNoPadding(
      sha256.convert(utf8.encode(verifier)).bytes,
    );
    final state = _generatePkceVerifier(24);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://localhost:${server.port}/oauth2redirect';
    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _driveScopes.join(' '),
      'access_type': 'offline',
      'prompt': 'consent',
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });

    onInfo?.call('Authorize access in browser:');
    onInfo?.call(authUri.toString());

    if (openBrowser) {
      await _tryOpenUrl(authUri);
    }

    late final HttpRequest callback;
    try {
      callback = await server.first.timeout(callbackTimeout);
    } on TimeoutException {
      await server.close(force: true);
      throw Exception('OAuth timed out. Re-run and complete browser login.');
    }

    final query = callback.uri.queryParameters;
    final returnedState = query['state'] ?? '';
    final code = query['code'] ?? '';
    final error = query['error'] ?? '';

    callback.response.headers.contentType = ContentType.html;
    if (error.isNotEmpty) {
      callback.response.write(
        '<html><body>Google OAuth error: $error. You can close this tab.</body></html>',
      );
      await callback.response.close();
      await server.close(force: true);
      throw Exception('Google OAuth failed: $error');
    }

    if (returnedState != state || code.isEmpty) {
      callback.response.write(
        '<html><body>Invalid OAuth callback. You can close this tab.</body></html>',
      );
      await callback.response.close();
      await server.close(force: true);
      throw Exception('Invalid OAuth callback from Google.');
    }

    callback.response.write(
      '<html><body>Google Drive connected. You can close this tab.</body></html>',
    );
    await callback.response.close();
    await server.close(force: true);

    final tokenResponse = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    );
    if (tokenResponse.statusCode != 200) {
      throw Exception('Token exchange failed: ${tokenResponse.body}');
    }

    final payloadDecoded = jsonDecode(tokenResponse.body);
    if (payloadDecoded is! Map) {
      throw Exception('Token exchange failed: unexpected response format.');
    }
    final payload = Map<String, dynamic>.from(payloadDecoded);
    final accessToken = (payload['access_token'] ?? '').toString();
    if (accessToken.isEmpty) {
      throw Exception('Token exchange failed: missing access token.');
    }
    final refreshTokenRaw = (payload['refresh_token'] ?? '').toString().trim();
    final refreshToken = refreshTokenRaw.isEmpty ? null : refreshTokenRaw;
    final expiresIn = (payload['expires_in'] as num?)?.toInt() ?? 3600;
    return _OAuthToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiry: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  Future<void> _tryOpenUrl(Uri uri) async {
    final url = uri.toString();
    try {
      if (Platform.isMacOS) {
        await Process.run('open', <String>[url]);
        return;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', <String>[url]);
        return;
      }
      if (Platform.isWindows) {
        await Process.run('cmd', <String>['/c', 'start', '', url]);
        return;
      }
    } catch (_) {}
  }
}

class _AccessTokenClient extends http.BaseClient {
  _AccessTokenClient(this._accessToken);

  final String _accessToken;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

String _generatePkceVerifier(int length) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

String _base64UrlNoPadding(List<int> value) =>
    base64UrlEncode(value).replaceAll('=', '');

String _join(String left, String right) {
  if (left.endsWith(Platform.pathSeparator)) {
    return '$left$right';
  }
  return '$left${Platform.pathSeparator}$right';
}
