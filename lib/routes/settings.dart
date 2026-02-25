import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/drive.dart';
import 'package:flutter/foundation.dart';
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
  bool _isBusy = false;
  String _busyMessage = '';

  Future<void> _runWithLoading(
    String message,
    Future<void> Function() action,
  ) async {
    if (!mounted) return;
    setState(() {
      _isBusy = true;
      _busyMessage = message;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _busyMessage = '';
        });
      }
    }
  }

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
    // getSignedInAccount() works on both Android and iOS.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      try {
        final account = await getSignedInAccount(interactive: false);
        userId = account.id;
      } catch (_) {}
    }

    await AppAnalytics.logScreenView(
      screenName: "SettingPage",
      screenClass: "SettingPage",
      parameters: {"user_id": userId as Object},
    );

    try {
      await _ensureDriveApiConnected();
    } catch (e, st) {
      debugPrint('Drive API init failed: $e');
      debugPrintStack(stackTrace: st);
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
            if (_isBusy)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 12),
                    Flexible(child: Text(_busyMessage)),
                  ],
                ),
              ),
            ElevatedButton(
              onPressed:
                  _isBusy
                      ? null
                      : () async {
                        await _runWithLoading(
                          'Connexion à Google Drive…',
                          () async {
                            try {
                              await _ensureDriveApiConnected();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Connected to Google Drive"),
                                ),
                              );
                            } catch (e, st) {
                              debugPrint('Connect to Google Drive failed: $e');
                              debugPrintStack(stackTrace: st);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          },
                        );
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
              onPressed:
                  _isBusy
                      ? null
                      : () async {
                        await _runWithLoading(
                          'Déconnexion en cours…',
                          () async {
                            await disconnectDriveAccount();
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              driveApi = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Déconnecté de Google Drive'),
                              ),
                            );
                          },
                        );
                      },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text("Se déconnecter de Google Drive"),
                ],
              ),
            ),
            ElevatedButton(
              onPressed:
                  _isBusy
                      ? null
                      : () async {
                        await _runWithLoading('Export en cours…', () async {
                          try {
                            await _ensureDriveApiConnected();
                            final message = await uploadAppData(
                              driveApi!,
                              appManager,
                            );
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          } catch (e, st) {
                            debugPrint('Export App Data failed: $e');
                            debugPrintStack(stackTrace: st);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        });
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
              onPressed:
                  _isBusy
                      ? null
                      : () async {
                        await _runWithLoading('Import en cours…', () async {
                          try {
                            await _ensureDriveApiConnected();
                            final message = await downloadAppData(
                              driveApi!,
                              appManager,
                            );
                            await appManager.refreshApps();
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          } catch (e, st) {
                            debugPrint('Import App Data failed: $e');
                            debugPrintStack(stackTrace: st);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        });
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
