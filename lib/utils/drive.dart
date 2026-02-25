import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bot_creator/utils/database.dart';
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
      '777382167262-454ckdtstv4jb7m1fue0foqcibvm6f7k.apps.googleusercontent.com',
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
    _desktopTokens = await _refreshBrowserToken(
      refreshToken,
      clientId: _desktopClientId,
    );
    await _saveDesktopTokens(_desktopTokens!);
    return;
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
  final size = (await local.stat()).size;
  final parents = parentId.isEmpty ? ['appDataFolder'] : [parentId];
  final meta =
      File()
        ..name = fileName
        ..mimeType = mimeType
        ..parents = parents;
  return drive.files.create(meta, uploadMedia: Media(local.openRead(), size));
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
    $fields: 'files(id, name, parents, mimeType)',
  );

  return fileList.files ?? [];
}

// ---------------------------------------------------------------------------
// Backup / Restore
// ---------------------------------------------------------------------------

Future<String> uploadAppData(DriveApi drive, AppManager appm) async {
  try {
    const rootParent = '';
    // clean
    final existing = await listFiles(drive);
    existing.sort((a, b) {
      final aFolder = a.mimeType == 'application/vnd.google-apps.folder';
      final bFolder = b.mimeType == 'application/vnd.google-apps.folder';
      if (aFolder == bFolder) return 0;
      return aFolder ? 1 : -1;
    });
    for (var f in existing) {
      await deleteFile(drive, fileId: f.id);
    }

    List<String> filesAlreadyUploaded = [];

    Future<void> push(
      manager.FileSystemEntity entity, {
      String parent = '',
    }) async {
      final stat = await entity.stat();
      final name = path.basename(entity.path);
      if (filesAlreadyUploaded.contains(entity.path)) {
        return;
      } else {
        filesAlreadyUploaded.add(entity.path);
      }
      if (stat.type == manager.FileSystemEntityType.directory) {
        final remoteDir = await createFolder(
          drive,
          name: name,
          parentId: parent,
        );
        for (var e in await manager.Directory(entity.path).list().toList()) {
          await push(e, parent: remoteDir.id!);
        }
      } else if (entity.path.endsWith('.json')) {
        await uploadFile(
          drive,
          filePath: entity.path,
          fileName: name,
          parentId: parent,
        );
      }
    }

    for (var e in await appm.getAllAppDirectory()) {
      await push(e, parent: rootParent);
    }
    return 'Sauvegarde terminee';
  } catch (e) {
    return 'Echec de la sauvegarde : $e';
  }
}

Future<String> downloadAppData(DriveApi drive, AppManager appm) async {
  try {
    final files = await listFiles(drive);
    final path = await appm.path;

    final localAppsDir = manager.Directory('$path/apps');
    if (await localAppsDir.exists()) {
      await localAppsDir.delete(recursive: true);
    }
    await localAppsDir.create(recursive: true);

    Map<String, String> folders = {};
    for (var f in files) {
      if (f.mimeType == 'application/vnd.google-apps.folder') {
        folders[f.id!] = f.name!;
      }
    }
    for (var f in folders.entries) {
      final dir = manager.Directory('$path/apps/${f.value}');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }

    for (var f in files) {
      if (f.mimeType != 'application/vnd.google-apps.folder') {
        final parent = f.parents?.isNotEmpty == true ? f.parents!.first : '';
        final folderName = folders[parent] ?? 'appDataFolder';
        if (folderName == 'appDataFolder') {
          await downloadFile(
            drive,
            fileId: f.id!,
            filePath: '$path/apps/${f.name}',
          );
        } else {
          await downloadFile(
            drive,
            fileId: f.id!,
            filePath: '$path/apps/$folderName/${f.name}',
          );
        }
      }
    }

    return 'Recuperation terminee';
  } catch (e) {
    return 'Echec de la recuperation : $e';
  }
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
