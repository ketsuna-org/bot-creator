import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth show AuthClient;
import 'dart:io' as manager show File;

/// Provides the `GoogleSignIn` class
import 'package:google_sign_in/google_sign_in.dart';

final signIn = GoogleSignIn(scopes: <String>[DriveApi.driveFileScope]);

Future<DriveApi> getDriveApi(GoogleSignIn signInButton) async {
  GoogleSignInAccount? account = await signInButton.signInSilently();
  account ??= await signInButton.signIn();
  final auth.AuthClient? client = await signInButton.authenticatedClient();

  return DriveApi(client!);
}

Future<void> uploadFile(
  DriveApi drive, {
  filePath = '',
  fileName = '',
  mimeType = 'application/json',
  manager.File? file,
}) async {
  file ??= manager.File(filePath);

  if (!file.existsSync()) {
    throw Exception('File does not exist');
  }
  final media = Media(file.openRead(), file.lengthSync());
  final fileMetadata = File();
  fileMetadata.name = fileName;
  fileMetadata.mimeType = mimeType;
  fileMetadata.parents = ['appDataFolder'];
  await drive.files.create(fileMetadata, uploadMedia: media);
}

Future<void> downloadFile(DriveApi drive, {fileId = '', filePath = ''}) async {
  final file = manager.File(filePath);
  if (file.existsSync()) {
    throw Exception('File already exists');
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
  final fileList = await drive.files.list(q: "trashed=false");
  return fileList.files ?? [];
}

Future<void> createFolder(DriveApi drive, {folderName = ''}) async {
  final folderMetadata = File();
  folderMetadata.name = folderName;
  folderMetadata.mimeType = 'application/vnd.google-apps.folder';
  await drive.files.create(folderMetadata);
}
