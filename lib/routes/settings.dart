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

  Future<void> _ensureDriveApiConnected({bool interactive = true}) async {
    if (driveApi != null) {
      return;
    }
    final drive = await getDriveApi(interactive: interactive);
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
      await _ensureDriveApiConnected(interactive: false);
    } catch (e, st) {
      debugPrint('Drive API init failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final iconSize = isMobile ? 60.0 : 80.0;
    final titleSize = isMobile ? 24.0 : 28.0;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.settings,
                  size: iconSize,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  "Backup and Restore",
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Manage your data synchronization with Google Drive",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_isBusy)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
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
                // Connection Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Google Drive Connection",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (driveApi == null) ...[
                        Text(
                          "Connect your Google Drive account to sync your data",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _isBusy
                                    ? null
                                    : () async {
                                      await _runWithLoading(
                                        'Connexion à Google Drive…',
                                        () async {
                                          try {
                                            await _ensureDriveApiConnected();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Connected to Google Drive",
                                                ),
                                              ),
                                            );
                                          } catch (e, st) {
                                            debugPrint(
                                              'Connect to Google Drive failed: $e',
                                            );
                                            debugPrintStack(stackTrace: st);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text("Error: $e"),
                                              ),
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
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green[400],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Connected",
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.green[400]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
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
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Déconnecté de Google Drive',
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout),
                                SizedBox(width: 8),
                                Text("Disconnect"),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Data Operations Section
                Text(
                  "Data Operations",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (isWideScreen)
                  Row(
                    children: [
                      Expanded(
                        child: _buildDataButton(
                          context,
                          icon: Icons.upload_file,
                          label: "Export",
                          onPressed:
                              _isBusy
                                  ? null
                                  : () async {
                                    await _runWithLoading(
                                      'Export en cours…',
                                      () async {
                                        try {
                                          await _ensureDriveApiConnected();
                                          final message = await uploadAppData(
                                            driveApi!,
                                            appManager,
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(message)),
                                          );
                                        } catch (e, st) {
                                          debugPrint(
                                            'Export App Data failed: $e',
                                          );
                                          debugPrintStack(stackTrace: st);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text("Error: $e"),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDataButton(
                          context,
                          icon: Icons.file_download_outlined,
                          label: "Import",
                          onPressed:
                              _isBusy
                                  ? null
                                  : () async {
                                    await _runWithLoading(
                                      'Import en cours…',
                                      () async {
                                        try {
                                          await _ensureDriveApiConnected();
                                          final message = await downloadAppData(
                                            driveApi!,
                                            appManager,
                                          );
                                          await appManager.refreshApps();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(message)),
                                          );
                                        } catch (e, st) {
                                          debugPrint(
                                            'Import App Data failed: $e',
                                          );
                                          debugPrintStack(stackTrace: st);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text("Error: $e"),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildDataButton(
                        context,
                        icon: Icons.upload_file,
                        label: "Export App Data",
                        onPressed:
                            _isBusy
                                ? null
                                : () async {
                                  await _runWithLoading(
                                    'Export en cours…',
                                    () async {
                                      try {
                                        await _ensureDriveApiConnected();
                                        final message = await uploadAppData(
                                          driveApi!,
                                          appManager,
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(message)),
                                        );
                                      } catch (e, st) {
                                        debugPrint(
                                          'Export App Data failed: $e',
                                        );
                                        debugPrintStack(stackTrace: st);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text("Error: $e")),
                                        );
                                      }
                                    },
                                  );
                                },
                      ),
                      const SizedBox(height: 12),
                      _buildDataButton(
                        context,
                        icon: Icons.file_download_outlined,
                        label: "Import App Data",
                        onPressed:
                            _isBusy
                                ? null
                                : () async {
                                  await _runWithLoading(
                                    'Import en cours…',
                                    () async {
                                      try {
                                        await _ensureDriveApiConnected();
                                        final message = await downloadAppData(
                                          driveApi!,
                                          appManager,
                                        );
                                        await appManager.refreshApps();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(message)),
                                        );
                                      } catch (e, st) {
                                        debugPrint(
                                          'Import App Data failed: $e',
                                        );
                                        debugPrintStack(stackTrace: st);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text("Error: $e")),
                                        );
                                      }
                                    },
                                  );
                                },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 10 : 12,
          horizontal: isMobile ? 12 : 16,
        ),
      ),
    );
  }
}
