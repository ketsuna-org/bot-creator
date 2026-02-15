import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/drive.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  List<File> files = [];
  DriveApi? driveApi;

  Future<void> _ensureDriveApiConnected() async {
    final drive = await getDriveApi();
    if (!mounted) {
      return;
    }
    setState(() {
      driveApi = drive;
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeDriveApi();
  }

  Future<void> _initializeDriveApi() async {
    String userId = 'unknown';
    try {
      final account = await getSignedInAccount(interactive: false);
      userId = account.id;
    } catch (_) {}

    await FirebaseAnalytics.instance.logScreenView(
      screenName: "SettingPage",
      screenClass: "SettingPage",
      parameters: {"user_id": userId},
    );

    try {
      await _ensureDriveApiConnected();
    } catch (e) {
      if (context.mounted) {
        // Show an error message if the context is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error initializing Drive API: $e")),
        );
      }
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
                  await _ensureDriveApiConnected();
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
                  await _ensureDriveApiConnected();
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
                  await _ensureDriveApiConnected();
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
