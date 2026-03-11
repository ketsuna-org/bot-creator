import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bot_creator/utils/database.dart';
import 'package:archive/archive_io.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth show AuthClient;
import 'dart:io' as manager;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import 'package:google_sign_in/google_sign_in.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const List<String> _mobileDriveScopes = <String>[DriveApi.driveAppdataScope];
const List<String> _desktopDriveScopes = <String>[DriveApi.driveAppdataScope];
const String _backupRootFolderName = 'backups_v2';
const String _backupMetaFileName = '__meta__.json';
const String _snapshotArchiveFileName = 'apps_snapshot.zip';
const String _desktopClientId = String.fromEnvironment(
  'GOOGLE_DESKTOP_CLIENT_ID',
  defaultValue:
      '777382167262-tf9rvusrqqd2fnsal8s7bfe80ur21n11.apps.googleusercontent.com',
);
const String _desktopClientSecret = String.fromEnvironment(
  'GOOGLE_DESKTOP_CLIENT_SECRET',
  defaultValue: "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",
);
const String _iosClientId = String.fromEnvironment(
  'GOOGLE_IOS_CLIENT_ID',
  defaultValue:
      '777382167262-2clnpnd4ijkjp71gvmpp5u0rik446kn8.apps.googleusercontent.com',
);

const String _androidServerClientIdFallback =
    '777382167262-on5tpqhctm19sa84jfke5igbn0m9q5uc.apps.googleusercontent.com';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

bool _googleSignInInitialized = false;

/// Cached OAuth tokens for browser-based desktop flow.
_BrowserOAuthTokens? _desktopTokens;

/// Cached Drive API instance for mobile to prevent redundant auth pop-ups.
DriveApi? _mobileDriveApiCache;

/// In-flight mobile Drive API initialization to coalesce concurrent requests.
Future<DriveApi>? _mobileDriveApiInFlight;

// ---------------------------------------------------------------------------
// Platform helpers
// ---------------------------------------------------------------------------

bool get _isDesktopPlatform {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows => true,
    TargetPlatform.linux => true,
    TargetPlatform.macOS => true,
    _ => false,
  };
}

bool get _isMobilePlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

bool get _isWindowsDesktop {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows;
}

// ---------------------------------------------------------------------------
// Mobile (Android + iOS): native GoogleSignIn
// ---------------------------------------------------------------------------

Future<GoogleSignIn> _getInitializedGoogleSignIn() async {
  final signIn = GoogleSignIn.instance;
  if (!_googleSignInInitialized) {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    // iOS needs an explicit clientId; Android uses google-services.json.
    String? clientId;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      clientId = _iosClientId.isEmpty ? null : _iosClientId;
    }

    // Android Credential Manager requires serverClientId = Web client ID.
    // On iOS it is optional but harmless.
    final String? serverClientId =
        isAndroid ? _androidServerClientIdFallback : null;

    if (isAndroid && serverClientId == null) {
      throw Exception(
        'GOOGLE_SERVER_CLIENT_ID is required on Android. '
        'Use your Web OAuth client ID (apps.googleusercontent.com) via '
        '--dart-define=GOOGLE_SERVER_CLIENT_ID=... ',
      );
    }

    debugPrint(
      '[GoogleSignIn] initialize  clientId=$clientId  '
      'serverClientId=$serverClientId',
    );

    await signIn.initialize(clientId: clientId, serverClientId: serverClientId);
    _googleSignInInitialized = true;
  }
  return signIn;
}

Future<GoogleSignInAccount> _getMobileSignedInAccount({
  bool interactive = true,
}) async {
  final signIn = await _getInitializedGoogleSignIn();

  // 1. Try silent / lightweight sign-in first.
  GoogleSignInAccount? account;
  try {
    final lightweight = signIn.attemptLightweightAuthentication();
    if (lightweight != null) {
      account = await lightweight;
    }
  } catch (e) {
    debugPrint('[GoogleSignIn] silent auth failed: $e');
  }

  // 2. If no account yet and interaction is allowed, authenticate once.
  if (account == null && interactive) {
    try {
      account = await signIn.authenticate(scopeHint: _mobileDriveScopes);
    } catch (e) {
      throw Exception('Authentication cancelled or failed: $e');
    }
  }

  if (account == null) {
    throw Exception('No Google account is signed in.');
  }
  return account;
}

Future<DriveApi> _getMobileDriveApi({bool interactive = true}) async {
  if (_mobileDriveApiCache != null) {
    return _mobileDriveApiCache!;
  }

  final inFlight = _mobileDriveApiInFlight;
  if (inFlight != null) {
    return inFlight;
  }

  final future = () async {
    final account = await _getMobileSignedInAccount(interactive: interactive);
    final authz =
        await account.authorizationClient.authorizationForScopes(
          _mobileDriveScopes,
        ) ??
        await account.authorizationClient.authorizeScopes(_mobileDriveScopes);
    final auth.AuthClient client = authz.authClient(scopes: _mobileDriveScopes);
    _mobileDriveApiCache = DriveApi(client);
    return _mobileDriveApiCache!;
  }();

  _mobileDriveApiInFlight = future;
  try {
    return await future;
  } finally {
    if (identical(_mobileDriveApiInFlight, future)) {
      _mobileDriveApiInFlight = null;
    }
  }
}

// ---------------------------------------------------------------------------
// Desktop: browser OAuth
// ---------------------------------------------------------------------------

Future<void> _authenticateDesktopIfNeeded() async {
  _desktopTokens ??= await _loadDesktopTokens();
  final current = _desktopTokens;
  final now = DateTime.now();

  if (current != null &&
      current.expiry.isAfter(now.add(const Duration(minutes: 1)))) {
    return;
  }

  if (_desktopClientId.isEmpty || _desktopClientSecret.isEmpty) {
    throw Exception(
      'Desktop OAuth requires client_id + client_secret. '
      'Pass --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... '
      '--dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...',
    );
  }

  if (current?.refreshToken case final refreshToken?) {
    try {
      _desktopTokens = await _refreshBrowserToken(
        refreshToken,
        clientId: _desktopClientId,
      );
      await _saveDesktopTokens(_desktopTokens!);
      return;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final isInvalidGrant =
          msg.contains('invalid_grant') ||
          msg.contains('expired') ||
          msg.contains('revoked');
      if (!isInvalidGrant) {
        rethrow;
      }

      // Refresh token expiré/révoqué: on nettoie le cache puis on relance
      // une authentification navigateur complète.
      await _clearDesktopTokens();
      _desktopTokens = null;
    }
  }

  _desktopTokens = await _runBrowserOAuthFlow(clientId: _desktopClientId);
  await _saveDesktopTokens(_desktopTokens!);
}

// ---------------------------------------------------------------------------
// Public entry points
// ---------------------------------------------------------------------------

/// Returns a signed-in account. Available on Android and iOS.
/// On desktop, use [getDriveApi] directly.
Future<GoogleSignInAccount> getSignedInAccount({
  bool interactive = true,
}) async {
  if (_isMobilePlatform) {
    return _getMobileSignedInAccount(interactive: interactive);
  }
  throw Exception(
    'getSignedInAccount() is only available on mobile. '
    'Use getDriveApi() on desktop platforms.',
  );
}

/// Clears OAuth session and cached clients to force a clean reconnect.
Future<void> disconnectDriveAccount() async {
  _mobileDriveApiCache = null;
  _mobileDriveApiInFlight = null;
  _desktopTokens = null;
  await _clearDesktopTokens();

  if (_isMobilePlatform) {
    final signIn = await _getInitializedGoogleSignIn();
    try {
      await signIn.signOut();
    } catch (_) {}
    try {
      await signIn.disconnect();
    } catch (_) {}
  }
}

Future<manager.File> _getDesktopTokenCacheFile() async {
  final supportDir = await getApplicationSupportDirectory();
  final authDir = manager.Directory(path.join(supportDir.path, 'auth'));
  if (!await authDir.exists()) {
    await authDir.create(recursive: true);
  }
  return manager.File(
    path.join(authDir.path, 'google_drive_desktop_tokens.json'),
  );
}

Future<_BrowserOAuthTokens?> _loadDesktopTokens() async {
  try {
    final file = await _getDesktopTokenCacheFile();
    if (!await file.exists()) {
      return null;
    }
    final raw = await file.readAsString();
    if (raw.isEmpty) {
      return null;
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final accessToken = (json['access_token'] as String?) ?? '';
    if (accessToken.isEmpty) {
      return null;
    }
    final expiryRaw = json['expiry'] as String?;
    final expiry = expiryRaw != null ? DateTime.tryParse(expiryRaw) : null;
    return _BrowserOAuthTokens(
      accessToken: accessToken,
      refreshToken: json['refresh_token'] as String?,
      expiry: expiry ?? DateTime.now(),
    );
  } catch (_) {
    return null;
  }
}

Future<void> _saveDesktopTokens(_BrowserOAuthTokens tokens) async {
  final file = await _getDesktopTokenCacheFile();
  final content = jsonEncode({
    'access_token': tokens.accessToken,
    'refresh_token': tokens.refreshToken,
    'expiry': tokens.expiry.toIso8601String(),
  });
  await file.writeAsString(content, flush: true);
}

Future<void> _clearDesktopTokens() async {
  try {
    final file = await _getDesktopTokenCacheFile();
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}

/// Returns an authenticated [DriveApi] for the current platform.
///
/// - **Android / iOS**: uses native GoogleSignIn (Credential Manager on
///   Android 14+, legacy on older versions).
/// - **Desktop**: opens the system browser for Google OAuth (PKCE).
Future<DriveApi> getDriveApi({bool interactive = true}) async {
  // Desktop (Windows / Linux / macOS)
  if (_isDesktopPlatform) {
    await _authenticateDesktopIfNeeded();
    return DriveApi(_AccessTokenClient(_desktopTokens!.accessToken));
  }

  // Mobile (Android + iOS) — native GoogleSignIn
  if (_isMobilePlatform) {
    return _getMobileDriveApi(interactive: interactive);
  }

  throw Exception('Google Drive sync is not supported on this platform.');
}

// ---------------------------------------------------------------------------
// Shared browser OAuth helpers (Desktop only)
// ---------------------------------------------------------------------------

Future<_BrowserOAuthTokens> _refreshBrowserToken(
  String refreshToken, {
  required String clientId,
}) async {
  final response = await http.post(
    Uri.parse('https://oauth2.googleapis.com/token'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'client_id': clientId,
      'client_secret': _desktopClientSecret,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    },
  );

  if (response.statusCode != 200) {
    throw Exception('Token refresh failed: ${response.body}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return _BrowserOAuthTokens(
    accessToken: json['access_token'] as String,
    refreshToken: (json['refresh_token'] as String?) ?? refreshToken,
    expiry: DateTime.now().add(
      Duration(seconds: (json['expires_in'] as int?) ?? 3600),
    ),
  );
}

Future<_BrowserOAuthTokens> _runBrowserOAuthFlow({
  required String clientId,
  List<String> scopes = _desktopDriveScopes,
}) async {
  final verifier = _generatePkceVerifier(96);
  final challenge = _base64UrlNoPadding(
    sha256.convert(utf8.encode(verifier)).bytes,
  );

  final server = await manager.HttpServer.bind(
    manager.InternetAddress.loopbackIPv4,
    0,
  );
  final redirectUri = 'http://localhost:${server.port}/oauth2redirect';
  final state = _generatePkceVerifier(24);

  final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': 'code',
    'scope': scopes.join(' '),
    'access_type': 'offline',
    'prompt': 'consent',
    'state': state,
    'code_challenge': challenge,
    'code_challenge_method': 'S256',
  });

  final launched = await launchUrl(
    authUri,
    mode: LaunchMode.externalApplication,
  );
  if (!launched) {
    await server.close(force: true);
    throw Exception('Could not open browser for Google OAuth.');
  }

  manager.HttpRequest callback;
  try {
    callback = await server.first.timeout(const Duration(minutes: 5));
  } on TimeoutException {
    await server.close(force: true);
    throw Exception('Google OAuth timeout. Please retry.');
  }

  final query = callback.uri.queryParameters;
  final returnedState = query['state'];
  final code = query['code'];
  final error = query['error'];

  callback.response.headers.contentType = manager.ContentType.html;

  if (error != null) {
    callback.response.write(
      '<html><body>Google OAuth error: $error. You can close this tab.</body></html>',
    );
    await callback.response.close();
    await server.close(force: true);
    throw Exception('Google OAuth failed: $error');
  }

  if (returnedState != state || code == null || code.isEmpty) {
    callback.response.write(
      '<html><body>Invalid OAuth callback. You can close this tab.</body></html>',
    );
    await callback.response.close();
    await server.close(force: true);
    throw Exception('Invalid OAuth callback from browser.');
  }

  callback.response.write(
    '<html><body>Google Drive connected! You can close this tab.</body></html>',
  );
  await callback.response.close();
  await server.close(force: true);

  final tokenResponse = await http.post(
    Uri.parse('https://oauth2.googleapis.com/token'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'client_id': clientId,
      'client_secret': _desktopClientSecret,
      'code': code,
      'code_verifier': verifier,
      'grant_type': 'authorization_code',
      'redirect_uri': redirectUri,
    },
  );

  if (tokenResponse.statusCode != 200) {
    throw Exception('Token exchange failed: ${tokenResponse.body}');
  }

  final tokenJson = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
  final accessToken = tokenJson['access_token'] as String?;
  if (accessToken == null || accessToken.isEmpty) {
    throw Exception('Google OAuth did not return an access token.');
  }

  return _BrowserOAuthTokens(
    accessToken: accessToken,
    refreshToken: tokenJson['refresh_token'] as String?,
    expiry: DateTime.now().add(
      Duration(seconds: (tokenJson['expires_in'] as int?) ?? 3600),
    ),
  );
}

// ---------------------------------------------------------------------------
// Crypto / PKCE helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Drive file helpers
// ---------------------------------------------------------------------------

Future<File> createFolder(
  DriveApi drive, {
  required String name,
  String parentId = '',
}) {
  final parents = parentId.isEmpty ? ['appDataFolder'] : [parentId];
  final meta =
      File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = parents;
  return drive.files.create(meta);
}

Future<File> uploadFile(
  DriveApi drive, {
  required String filePath,
  required String fileName,
  String mimeType = 'application/json',
  String parentId = '',
}) async {
  final local = manager.File(filePath);
  if (!await local.exists()) throw Exception('File does not exist');
  final bytes = await local.readAsBytes();
  final size = bytes.length;
  final parents = parentId.isEmpty ? ['appDataFolder'] : [parentId];
  final meta =
      File()
        ..name = fileName
        ..mimeType = mimeType
        ..parents = parents;
  return drive.files.create(
    meta,
    uploadMedia: Media(Stream<List<int>>.value(bytes), size),
  );
}

Future<void> _deleteFileWithRetry(manager.File file) async {
  const maxAttempts = 6;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      if (await file.exists()) {
        await file.delete();
      }
      return;
    } on manager.FileSystemException {
      if (!_isWindowsDesktop || attempt == maxAttempts) {
        rethrow;
      }
      await Future.delayed(Duration(milliseconds: 120 * attempt));
    }
  }
}

Future<void> _recreateDirectoryWithRetry(manager.Directory directory) async {
  const maxAttempts = 6;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await directory.create(recursive: true);
      return;
    } on manager.FileSystemException {
      if (!_isWindowsDesktop || attempt == maxAttempts) {
        rethrow;
      }
      await Future.delayed(Duration(milliseconds: 150 * attempt));
    }
  }
}

Future<void> downloadFile(DriveApi drive, {fileId = '', filePath = ''}) async {
  final file = manager.File(filePath);
  if (!await file.exists()) {
    await file.create(recursive: true);
  }
  final media = await drive.files.get(
    fileId,
    downloadOptions: DownloadOptions.fullMedia,
  );
  if (media is Media) {
    final fileStream = media.stream;
    final fileBytes = await fileStream.toList();
    final fileData = fileBytes.expand((x) => x).toList();
    await file.writeAsBytes(fileData);
  } else {
    throw Exception('Failed to download file');
  }
}

Future<void> deleteFile(DriveApi drive, {fileId = ''}) async {
  await drive.files.delete(fileId);
}

Future<List<File>> listFiles(DriveApi drive) async {
  final fileList = await drive.files.list(
    q: 'trashed=false',
    spaces: 'appDataFolder',
    $fields:
        'files(id, name, parents, mimeType, createdTime, modifiedTime, size)',
  );

  return fileList.files ?? [];
}

// ---------------------------------------------------------------------------
// Backup / Restore
// ---------------------------------------------------------------------------

Future<String> uploadAppData(DriveApi drive, AppManager appm) async {
  try {
    final snapshot = await createBackupSnapshot(
      drive,
      appm,
      label: 'Manual backup',
    );
    await _pruneSnapshots(drive, keepLatest: 20);
    return 'Sauvegarde terminee (${snapshot.snapshotId})';
  } catch (e) {
    return 'Echec de la sauvegarde : $e';
  }
}

Future<String> downloadAppData(DriveApi drive, AppManager appm) async {
  try {
    final latest = await getLatestBackupSnapshot(drive);
    if (latest != null) {
      await restoreBackupSnapshot(drive, appm, snapshotId: latest.snapshotId);
      return 'Recuperation terminee (${latest.snapshotId})';
    }

    // Legacy fallback for old flat backups stored at appDataFolder root.
    return await _downloadLegacyFlatBackup(drive, appm);
  } catch (e) {
    return 'Echec de la recuperation : $e';
  }
}

Future<BackupSnapshotSummary> createBackupSnapshot(
  DriveApi drive,
  AppManager appm, {
  String label = 'Manual backup',
}) async {
  final backupsRoot = await _ensureBackupsRootFolder(drive);
  final now = DateTime.now().toUtc();
  final snapshotId = now
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
  final snapshotFolder = await createFolder(
    drive,
    name: snapshotId,
    parentId: backupsRoot.id!,
  );

  final localRootPath = await appm.path;
  final localAppsDir = manager.Directory('$localRootPath/apps');
  if (!await localAppsDir.exists()) {
    await localAppsDir.create(recursive: true);
  }

  var fileCount = 0;
  var totalBytes = 0;
  final tempDir = await getTemporaryDirectory();
  final tempArchive = manager.File(
    path.join(
      tempDir.path,
      'bot_creator_snapshot_${DateTime.now().microsecondsSinceEpoch}.zip',
    ),
  );

  final zipEncoder = ZipFileEncoder();
  zipEncoder.create(tempArchive.path);
  try {
    await for (final entity in localAppsDir.list(recursive: true)) {
      if (entity is! manager.File || !entity.path.endsWith('.json')) {
        continue;
      }

      final relativePath = path.relative(entity.path, from: localAppsDir.path);
      final archivePath = _normalizeZipEntryPath(relativePath);
      zipEncoder.addFile(entity, archivePath);

      final size = await entity.length();
      fileCount += 1;
      totalBytes += size;
    }
  } finally {
    zipEncoder.close();
  }

  try {
    await uploadFile(
      drive,
      filePath: tempArchive.path,
      fileName: _snapshotArchiveFileName,
      mimeType: 'application/zip',
      parentId: snapshotFolder.id!,
    );
  } finally {
    await _deleteFileWithRetry(tempArchive);
  }

  final apps = await appm.getAllApps();
  final appsPreview = apps
      .whereType<Map>()
      .map((raw) => Map<String, dynamic>.from(raw))
      .map(
        (app) => <String, String>{
          'id': (app['id'] ?? '').toString(),
          'name': (app['name'] ?? '').toString(),
        },
      )
      .where((app) => app['id']!.isNotEmpty)
      .toList(growable: false);

  final metadata = <String, dynamic>{
    'version': 2,
    'snapshotId': snapshotId,
    'label': label,
    'createdAt': now.toIso8601String(),
    'fileCount': fileCount,
    'totalBytes': totalBytes,
    'appCount': appsPreview.length,
    'apps': appsPreview,
    'format': 'zip-v1',
    'archiveFile': _snapshotArchiveFileName,
  };
  await _uploadJsonToParent(
    drive,
    parentId: snapshotFolder.id!,
    fileName: _backupMetaFileName,
    content: metadata,
  );

  return BackupSnapshotSummary.fromJson(metadata);
}

Future<List<BackupSnapshotSummary>> listBackupSnapshots(DriveApi drive) async {
  final root = await _findBackupsRootFolder(drive);
  if (root == null || root.id == null) {
    return const [];
  }

  final children = await _listChildren(drive, parentId: root.id!);
  final folders = children
      .where((f) => f.mimeType == 'application/vnd.google-apps.folder')
      .toList(growable: false);

  final snapshots = <BackupSnapshotSummary>[];
  for (final folder in folders) {
    if (folder.id == null || folder.name == null) {
      continue;
    }
    final meta = await _readSnapshotMetadata(
      drive,
      parentId: folder.id!,
      fallbackSnapshotId: folder.name!,
    );
    snapshots.add(meta);
  }

  snapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return snapshots;
}

Future<BackupSnapshotSummary?> getLatestBackupSnapshot(DriveApi drive) async {
  final snapshots = await listBackupSnapshots(drive);
  if (snapshots.isEmpty) {
    return null;
  }
  return snapshots.first;
}

Future<String> restoreBackupSnapshot(
  DriveApi drive,
  AppManager appm, {
  required String snapshotId,
}) async {
  final root = await _findBackupsRootFolder(drive);
  if (root == null || root.id == null) {
    throw Exception('No backups folder found.');
  }

  final snapshotFolder = await _findNamedChild(
    drive,
    parentId: root.id!,
    name: snapshotId,
    folderOnly: true,
  );
  if (snapshotFolder?.id == null) {
    throw Exception('Snapshot not found: $snapshotId');
  }
  final snapshotFolderId = snapshotFolder!.id!;

  final archiveFile = await _findNamedChild(
    drive,
    parentId: snapshotFolderId,
    name: _snapshotArchiveFileName,
  );
  if (archiveFile?.id != null) {
    final tempDir = await getTemporaryDirectory();
    final archivePath = path.join(
      tempDir.path,
      'bot_creator_restore_${DateTime.now().microsecondsSinceEpoch}.zip',
    );
    await downloadFile(drive, fileId: archiveFile!.id!, filePath: archivePath);

    final localRootPath = await appm.path;
    final localAppsDir = manager.Directory('$localRootPath/apps');
    await _recreateDirectoryWithRetry(localAppsDir);

    try {
      extractFileToDisk(archivePath, localAppsDir.path);
    } finally {
      final archiveLocal = manager.File(archivePath);
      await _deleteFileWithRetry(archiveLocal);
    }

    await appm.refreshApps();
    return 'Recuperation terminee';
  }

  // Legacy snapshot format fallback: folder tree of files.
  final allFiles = await listFiles(drive);
  final childrenByParent = <String, List<File>>{};
  for (final file in allFiles) {
    final parents = file.parents ?? const <String>[];
    for (final parent in parents) {
      childrenByParent.putIfAbsent(parent, () => <File>[]).add(file);
    }
  }

  final localRootPath = await appm.path;
  final localAppsDir = manager.Directory('$localRootPath/apps');
  await _recreateDirectoryWithRetry(localAppsDir);

  Future<void> restoreFolder(String folderId, String relPath) async {
    final children = childrenByParent[folderId] ?? const <File>[];
    for (final child in children) {
      final childId = child.id;
      final childName = child.name;
      if (childId == null || childName == null) {
        continue;
      }

      final nextRel =
          relPath.isEmpty ? childName : path.join(relPath, childName);
      if (child.mimeType == 'application/vnd.google-apps.folder') {
        await restoreFolder(childId, nextRel);
        continue;
      }

      if (childName == _backupMetaFileName || !childName.endsWith('.json')) {
        continue;
      }

      final targetPath = path.join(localAppsDir.path, nextRel);
      await downloadFile(drive, fileId: childId, filePath: targetPath);
    }
  }

  await restoreFolder(snapshotFolderId, '');
  await appm.refreshApps();
  return 'Recuperation terminee';
}

Future<void> deleteBackupSnapshot(
  DriveApi drive, {
  required String snapshotId,
}) async {
  final root = await _findBackupsRootFolder(drive);
  if (root == null || root.id == null) {
    return;
  }
  final snapshotFolder = await _findNamedChild(
    drive,
    parentId: root.id!,
    name: snapshotId,
    folderOnly: true,
  );
  if (snapshotFolder?.id == null) {
    return;
  }
  await deleteFile(drive, fileId: snapshotFolder!.id!);
}

Future<void> _pruneSnapshots(DriveApi drive, {int keepLatest = 20}) async {
  final snapshots = await listBackupSnapshots(drive);
  if (snapshots.length <= keepLatest) {
    return;
  }
  for (final snapshot in snapshots.skip(keepLatest)) {
    await deleteBackupSnapshot(drive, snapshotId: snapshot.snapshotId);
  }
}

Future<String> _downloadLegacyFlatBackup(
  DriveApi drive,
  AppManager appm,
) async {
  final files = await listFiles(drive);
  final localRootPath = await appm.path;

  final localAppsDir = manager.Directory('$localRootPath/apps');
  await _recreateDirectoryWithRetry(localAppsDir);

  final folders = <String, String>{};
  for (final file in files) {
    if (file.id != null &&
        file.name != null &&
        file.mimeType == 'application/vnd.google-apps.folder') {
      folders[file.id!] = file.name!;
      final dir = manager.Directory(path.join(localAppsDir.path, file.name!));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
  }

  for (final file in files) {
    if (file.id == null ||
        file.name == null ||
        file.mimeType == 'application/vnd.google-apps.folder') {
      continue;
    }
    final parent = file.parents?.isNotEmpty == true ? file.parents!.first : '';
    final folderName = folders[parent];
    final targetPath =
        folderName == null
            ? path.join(localAppsDir.path, file.name!)
            : path.join(localAppsDir.path, folderName, file.name!);
    await downloadFile(drive, fileId: file.id!, filePath: targetPath);
  }

  await appm.refreshApps();
  return 'Recuperation terminee (legacy backup)';
}

Future<File?> _findBackupsRootFolder(DriveApi drive) {
  return _findNamedChild(
    drive,
    parentId: '',
    name: _backupRootFolderName,
    folderOnly: true,
  );
}

Future<File> _ensureBackupsRootFolder(DriveApi drive) async {
  final existing = await _findBackupsRootFolder(drive);
  if (existing?.id != null) {
    return existing!;
  }
  return createFolder(drive, name: _backupRootFolderName);
}

Future<List<File>> _listChildren(
  DriveApi drive, {
  required String parentId,
}) async {
  final q = "trashed=false and '$parentId' in parents";
  final result = await drive.files.list(
    q: q,
    spaces: 'appDataFolder',
    $fields:
        'files(id, name, parents, mimeType, createdTime, modifiedTime, size)',
  );
  return result.files ?? const <File>[];
}

Future<File?> _findNamedChild(
  DriveApi drive, {
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
  final files = result.files ?? const <File>[];
  if (files.isEmpty) {
    return null;
  }
  return files.first;
}

Future<void> _uploadJsonToParent(
  DriveApi drive, {
  required String parentId,
  required String fileName,
  required Map<String, dynamic> content,
}) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = manager.File(
    path.join(
      tempDir.path,
      'bot_creator_${DateTime.now().microsecondsSinceEpoch}_$fileName',
    ),
  );
  await tempFile.writeAsString(jsonEncode(content), flush: true);
  try {
    await uploadFile(
      drive,
      filePath: tempFile.path,
      fileName: fileName,
      parentId: parentId,
    );
  } finally {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }
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

Future<Map<String, dynamic>?> _readJsonFile(
  DriveApi drive, {
  required String fileId,
}) async {
  final media = await drive.files.get(
    fileId,
    downloadOptions: DownloadOptions.fullMedia,
  );
  if (media is! Media) {
    return null;
  }

  final chunks = await media.stream.toList();
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

Future<BackupSnapshotSummary> _readSnapshotMetadata(
  DriveApi drive, {
  required String parentId,
  required String fallbackSnapshotId,
}) async {
  final metaFile = await _findNamedChild(
    drive,
    parentId: parentId,
    name: _backupMetaFileName,
  );

  if (metaFile?.id != null) {
    final json = await _readJsonFile(drive, fileId: metaFile!.id!);
    if (json != null) {
      return BackupSnapshotSummary.fromJson(json);
    }
  }

  return BackupSnapshotSummary(
    snapshotId: fallbackSnapshotId,
    label: 'Legacy snapshot',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    fileCount: 0,
    totalBytes: 0,
    appCount: 0,
    apps: const [],
  );
}

class BackupSnapshotSummary {
  const BackupSnapshotSummary({
    required this.snapshotId,
    required this.label,
    required this.createdAt,
    required this.fileCount,
    required this.totalBytes,
    required this.appCount,
    required this.apps,
  });

  factory BackupSnapshotSummary.fromJson(Map<String, dynamic> json) {
    final appsRaw = (json['apps'] as List?)?.whereType<Map>() ?? const <Map>[];
    final apps = appsRaw
        .map(
          (entry) => Map<String, String>.from(
            entry.map((key, value) {
              return MapEntry(key.toString(), value?.toString() ?? '');
            }),
          ),
        )
        .toList(growable: false);

    final createdAt =
        DateTime.tryParse((json['createdAt'] ?? '').toString())?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return BackupSnapshotSummary(
      snapshotId: (json['snapshotId'] ?? '').toString(),
      label: (json['label'] ?? 'Backup').toString(),
      createdAt: createdAt,
      fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      appCount: (json['appCount'] as num?)?.toInt() ?? apps.length,
      apps: apps,
    );
  }

  final String snapshotId;
  final String label;
  final DateTime createdAt;
  final int fileCount;
  final int totalBytes;
  final int appCount;
  final List<Map<String, String>> apps;
}

// ---------------------------------------------------------------------------
// Internal types
// ---------------------------------------------------------------------------

class _BrowserOAuthTokens {
  _BrowserOAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiry,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiry;
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
