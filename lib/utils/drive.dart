import 'package:bot_creator/utils/database.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth show AuthClient;
import 'dart:io' as manager;

/// Provides the `GoogleSignIn` class
import 'package:google_sign_in/google_sign_in.dart';

const List<String> _driveScopes = <String>[DriveApi.driveAppdataScope];
bool _googleSignInInitialized = false;

Future<GoogleSignIn> _getInitializedGoogleSignIn() async {
  final signIn = GoogleSignIn.instance;
  if (!_googleSignInInitialized) {
    await signIn.initialize();
    _googleSignInInitialized = true;
  }
  return signIn;
}

Future<GoogleSignInAccount> getSignedInAccount({bool interactive = true}) async {
  final signIn = await _getInitializedGoogleSignIn();

  GoogleSignInAccount? account;
  final lightweightAuthFuture = signIn.attemptLightweightAuthentication();
  if (lightweightAuthFuture != null) {
    account = await lightweightAuthFuture;
  }

  if (account == null && interactive) {
    account = await signIn.authenticate(scopeHint: _driveScopes);
  }

  if (account == null) {
    throw Exception('No Google account is signed in.');
  }
  return account;
}

Future<DriveApi> getDriveApi() async {
  final account = await getSignedInAccount();
  final authz =
      await account.authorizationClient.authorizationForScopes(_driveScopes) ??
      await account.authorizationClient.authorizeScopes(_driveScopes);
  final auth.AuthClient client = authz.authClient(scopes: _driveScopes);
  return DriveApi(client);
}

Future<File> createFolder(
  DriveApi drive, {
  required String name,
  String parentId = '',
}) {
  final meta =
      File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = parentId.isEmpty ? ['appDataFolder'] : [parentId];
  return drive.files.create(meta); // pas d’uploadMedia
}

/// 2. fichier = un seul parent
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
  final meta =
      File()
        ..name = fileName
        ..mimeType = mimeType
        ..parents = parentId.isEmpty ? ['appDataFolder'] : [parentId];
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
    q: "trashed=false",
    spaces: "appDataFolder",
    $fields: "files(id, name, parents, mimeType)",
  );

  return fileList.files ?? [];
}

Future<String> uploadAppData(DriveApi drive, AppManager appm) async {
  try {
    // clean
    for (var f in await listFiles(drive)) {
      await deleteFile(drive, fileId: f.id);
    }

    List<String> filesAlreadyUploaded = [];

    Future<void> push(
      manager.FileSystemEntity entity, {
      String parent = '',
    }) async {
      final stat = await entity.stat();
      final name = entity.path.split('/').last;
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
      await push(e);
    }
    return 'Sauvegarde terminée ✅';
  } catch (e) {
    return 'Échec de la sauvegarde : $e';
  }
}

Future<String> downloadAppData(DriveApi drive, AppManager appm) async {
  try {
    final files = await listFiles(drive);
    final path = await appm.path;
    // we need to put each data in their correct folder.
    // let's create a map of the folders
    Map<String, String> folders = {};
    for (var f in files) {
      if (f.mimeType == 'application/vnd.google-apps.folder') {
        folders[f.id!] = f.name!;
      }
    }
    // let's create the folders
    for (var f in folders.entries) {
      final dir = manager.Directory('$path/apps/${f.value}');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }

    // let's download the files
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

    return 'Récupération terminée ✅';
  } catch (e) {
    return 'Échec de la récupération : $e';
  }
}
