import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/drive.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  List<File> files = [];
  DriveApi? driveApi;
  final signIn = GoogleSignIn(scopes: <String>[DriveApi.driveAppdataScope]);

  @override
  void initState() {
    super.initState();
    _initializeDriveApi();
  }

  Future<void> _initializeDriveApi() async {
    await analytics.logScreenView(
      screenName: "SettingPage",
      screenClass: "SettingPage",
      parameters: {"user_id": signIn.currentUser?.id ?? "unknown"},
    );
    try {
      if (driveApi == null) {
        final drive = await getDriveApi();
        setState(() {
          driveApi = drive;
        });
      }
      if (!await signIn.isSignedIn()) {
        final drive = await getDriveApi();
        setState(() {
          driveApi = drive;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error initializing Drive API: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              Icons.settings,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const Text("Backup and Restore", style: TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (driveApi == null) {
                    final drive = await getDriveApi();
                    setState(() {
                      driveApi = drive;
                    });
                  }
                  if (!await signIn.isSignedIn()) {
                    final drive = await getDriveApi();
                    setState(() {
                      driveApi = drive;
                    });
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Connected to Google Drive")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.g_mobiledata),
                  SizedBox(width: 8),
                  Text("Connect to Google Drive"),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (driveApi == null) {
                    final drive = await getDriveApi();
                    setState(() {
                      driveApi = drive;
                    });
                  }
                  if (!await signIn.isSignedIn()) {
                    final drive = await getDriveApi();
                    setState(() {
                      driveApi = drive;
                    });
                  }
                  final message = await uploadAppData(driveApi!, appManager);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file),
                  SizedBox(width: 8),
                  Text("Export App Data"),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (driveApi == null) {
                    final drive = await getDriveApi();
                    setState(() {
                      driveApi = drive;
                    });
                  }
                  if (!await signIn.isSignedIn()) {
                    final drive = await getDriveApi();
                    setState(() {
                      driveApi = drive;
                    });
                  }
                  final message = await downloadAppData(driveApi!, appManager);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_download_outlined),
                  SizedBox(width: 8),
                  Text("Import App Data"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
