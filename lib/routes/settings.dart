import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/app_diagnostics.dart';
import 'package:bot_creator/utils/drive.dart';
import 'package:bot_creator/utils/recovery_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:provider/provider.dart';

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
  RecoverySettings _recoverySettings = RecoverySettings.defaults();
  bool _loadingRecoverySettings = true;
  bool _loadingSnapshots = false;
  List<BackupSnapshotSummary> _snapshots = const [];

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
    _loadRecoverySettings();
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
    // La connexion à Google Drive se fait uniquement sur action de l'utilisateur.
  }

  Future<void> _loadRecoverySettings() async {
    final settings = await RecoveryManager.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _recoverySettings = settings;
      _loadingRecoverySettings = false;
    });
  }

  Future<void> _saveRecoverySettings(RecoverySettings settings) async {
    await RecoveryManager.saveSettings(settings);
    if (!mounted) {
      return;
    }
    setState(() {
      _recoverySettings = settings;
    });
  }

  Future<void> _refreshSnapshots() async {
    if (driveApi == null) {
      return;
    }
    setState(() {
      _loadingSnapshots = true;
    });
    try {
      final snapshots = await listBackupSnapshots(driveApi!);
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshots = snapshots;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSnapshots = false;
        });
      }
    }
  }

  Future<void> _runAutoBackupCheck({
    required bool force,
    required bool showSnack,
  }) async {
    if (driveApi == null) {
      return;
    }
    final result = await RecoveryManager.runAutoBackupIfDue(
      drive: driveApi!,
      appManager: appManager,
      force: force,
    );
    if (!mounted) {
      return;
    }

    if (result.executed) {
      final updated = _recoverySettings.copyWith(
        lastAutoBackupAt: DateTime.now().toUtc(),
      );
      await _saveRecoverySettings(updated);
      await _refreshSnapshots();
    }

    if (showSnack) {
      final suffix =
          result.snapshot == null
              ? ''
              : ' (${result.snapshot!.snapshotId.substring(0, 19)})';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${result.message}$suffix')));
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSnapshotPreview(BackupSnapshotSummary snapshot) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Snapshot Preview'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${snapshot.snapshotId}'),
                  Text('Label: ${snapshot.label}'),
                  Text('Created: ${snapshot.createdAt.toLocal()}'),
                  Text(
                    'Files: ${snapshot.fileCount} • Size: ${_formatBytes(snapshot.totalBytes)}',
                  ),
                  Text('Apps: ${snapshot.appCount}'),
                  const SizedBox(height: 10),
                  Text(
                    'Apps in this snapshot',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  if (snapshot.apps.isEmpty)
                    const Text('No app metadata available.')
                  else
                    ...snapshot.apps.map((entry) {
                      final appName = (entry['name'] ?? '').trim();
                      final appId = (entry['id'] ?? '').trim();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          appName.isEmpty ? appId : '$appName ($appId)',
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _runWithLoading('Suppression snapshot…', () async {
                  try {
                    await _ensureDriveApiConnected();
                    await deleteBackupSnapshot(
                      driveApi!,
                      snapshotId: snapshot.snapshotId,
                    );
                    await _refreshSnapshots();
                    if (!mounted) {
                      return;
                    }
                    _showSnack('Snapshot deleted');
                  } catch (e, st) {
                    debugPrint('Delete snapshot failed: $e');
                    debugPrintStack(stackTrace: st);
                    if (!mounted) {
                      return;
                    }
                    _showSnack('Error: $e');
                  }
                });
              },
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _runWithLoading('Restore snapshot en cours…', () async {
                  try {
                    await _ensureDriveApiConnected();
                    final message = await restoreBackupSnapshot(
                      driveApi!,
                      appManager,
                      snapshotId: snapshot.snapshotId,
                    );
                    await appManager.refreshApps();
                    await _refreshSnapshots();
                    if (!mounted) {
                      return;
                    }
                    _showSnack(message);
                  } catch (e, st) {
                    debugPrint('Restore snapshot failed: $e');
                    debugPrintStack(stackTrace: st);
                    if (!mounted) {
                      return;
                    }
                    _showSnack('Error: $e');
                  }
                });
              },
              icon: const Icon(Icons.restore),
              label: const Text('Restore This Snapshot'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDiagnosticsDialog() async {
    final text = await AppDiagnostics.readLog(maxLines: 250);
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Startup Diagnostics'),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await AppDiagnostics.copyLogToClipboard(maxLines: 300);
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Diagnostics copied to clipboard'),
                  ),
                );
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final iconSize = isMobile ? 60.0 : 80.0;
    final titleSize = isMobile ? 24.0 : 28.0;

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: isDark ? 'Passer en mode clair' : 'Passer en mode sombre',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
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
                                            await _refreshSnapshots();
                                            await _runAutoBackupCheck(
                                              force: false,
                                              showSnack: false,
                                            );
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
                                            _snapshots = const [];
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
                                          await _refreshSnapshots();
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
                                          await _refreshSnapshots();
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
                                        await _refreshSnapshots();
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
                                        await _refreshSnapshots();
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
                const SizedBox(height: 32),
                Text(
                  "Recovery Pro",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable auto-backup'),
                          subtitle: const Text(
                            'Create versioned snapshots automatically when due.',
                          ),
                          value:
                              !_loadingRecoverySettings &&
                              _recoverySettings.autoBackupEnabled,
                          onChanged:
                              _loadingRecoverySettings
                                  ? null
                                  : (enabled) async {
                                    final next = _recoverySettings.copyWith(
                                      autoBackupEnabled: enabled,
                                    );
                                    await _saveRecoverySettings(next);
                                  },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                            'auto_backup_interval_${_recoverySettings.autoBackupIntervalHours}',
                          ),
                          initialValue:
                              _recoverySettings.autoBackupIntervalHours,
                          decoration: const InputDecoration(
                            labelText: 'Auto-backup interval',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 6, child: Text('Every 6h')),
                            DropdownMenuItem(
                              value: 12,
                              child: Text('Every 12h'),
                            ),
                            DropdownMenuItem(
                              value: 24,
                              child: Text('Every 24h'),
                            ),
                            DropdownMenuItem(
                              value: 72,
                              child: Text('Every 72h'),
                            ),
                          ],
                          onChanged:
                              (!_recoverySettings.autoBackupEnabled ||
                                      _loadingRecoverySettings)
                                  ? null
                                  : (value) async {
                                    if (value == null) {
                                      return;
                                    }
                                    final next = _recoverySettings.copyWith(
                                      autoBackupIntervalHours: value,
                                    );
                                    await _saveRecoverySettings(next);
                                  },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _recoverySettings.lastAutoBackupAt == null
                              ? 'Last auto-backup: never'
                              : 'Last auto-backup: ${_recoverySettings.lastAutoBackupAt!.toLocal()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed:
                                  _isBusy
                                      ? null
                                      : () async {
                                        await _runWithLoading(
                                          'Création du snapshot…',
                                          () async {
                                            try {
                                              await _ensureDriveApiConnected();
                                              final snapshot =
                                                  await createBackupSnapshot(
                                                    driveApi!,
                                                    appManager,
                                                    label: 'Manual snapshot',
                                                  );
                                              await _refreshSnapshots();
                                              if (!mounted) {
                                                return;
                                              }
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Snapshot created: ${snapshot.snapshotId}',
                                                  ),
                                                ),
                                              );
                                            } catch (e, st) {
                                              debugPrint(
                                                'Manual snapshot failed: $e',
                                              );
                                              debugPrintStack(stackTrace: st);
                                              if (!mounted) {
                                                return;
                                              }
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      },
                              icon: const Icon(Icons.backup),
                              label: const Text('Backup now'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  _isBusy ||
                                          !_recoverySettings.autoBackupEnabled
                                      ? null
                                      : () async {
                                        await _runWithLoading(
                                          'Auto-backup check…',
                                          () async {
                                            await _ensureDriveApiConnected();
                                            await _runAutoBackupCheck(
                                              force: true,
                                              showSnack: true,
                                            );
                                          },
                                        );
                                      },
                              icon: const Icon(Icons.schedule_send),
                              label: const Text('Run auto-backup now'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Snapshots',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh snapshots',
                              onPressed:
                                  _isBusy || _loadingSnapshots
                                      ? null
                                      : () async {
                                        await _runWithLoading(
                                          'Actualisation des snapshots…',
                                          () async {
                                            await _ensureDriveApiConnected();
                                            await _refreshSnapshots();
                                          },
                                        );
                                      },
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        if (_loadingSnapshots)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_snapshots.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No snapshots found yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          ..._snapshots.take(8).map((snapshot) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(snapshot.label),
                              subtitle: Text(
                                '${snapshot.createdAt.toLocal()} • ${snapshot.fileCount} files • ${_formatBytes(snapshot.totalBytes)}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showSnapshotPreview(snapshot),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "Diagnostics",
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
                          icon: Icons.bug_report_outlined,
                          label: "View startup logs",
                          onPressed:
                              _isBusy
                                  ? null
                                  : () async {
                                    await _showDiagnosticsDialog();
                                  },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDataButton(
                          context,
                          icon: Icons.delete_outline,
                          label: "Clear logs",
                          onPressed:
                              _isBusy
                                  ? null
                                  : () async {
                                    await AppDiagnostics.clearLog();
                                    if (!mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Diagnostics log cleared',
                                        ),
                                      ),
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
                        icon: Icons.bug_report_outlined,
                        label: "View startup logs",
                        onPressed:
                            _isBusy
                                ? null
                                : () async {
                                  await _showDiagnosticsDialog();
                                },
                      ),
                      const SizedBox(height: 12),
                      _buildDataButton(
                        context,
                        icon: Icons.delete_outline,
                        label: "Clear logs",
                        onPressed:
                            _isBusy
                                ? null
                                : () async {
                                  await AppDiagnostics.clearLog();
                                  if (!mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Diagnostics log cleared'),
                                    ),
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
