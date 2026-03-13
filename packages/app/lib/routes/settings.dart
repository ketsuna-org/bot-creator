import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/onboarding.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/app_diagnostics.dart';
import 'package:bot_creator/utils/drive.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/onboarding_manager.dart';
import 'package:bot_creator/utils/recovery_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Widget _dropdownLabel(String text) {
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  String _languagePreferenceLabel(
    AppLocalePreference preference,
    AppLocale detectedLocale,
  ) {
    switch (preference) {
      case AppLocalePreference.system:
        return '${AppStrings.t('settings_language_system')} • ${detectedLocale.label}';
      case AppLocalePreference.en:
        return AppLocale.en.label;
      case AppLocalePreference.fr:
        return AppLocale.fr.label;
    }
  }

  String _formatErrorMessage(Object error) {
    return AppStrings.tr(
      'error_with_details',
      params: {'error': error.toString()},
    );
  }

  String _autoBackupIntervalLabel(int hours) {
    switch (hours) {
      case 6:
        return AppStrings.t('settings_auto_backup_every_6h');
      case 12:
        return AppStrings.t('settings_auto_backup_every_12h');
      case 24:
        return AppStrings.t('settings_auto_backup_every_24h');
      case 72:
        return AppStrings.t('settings_auto_backup_every_72h');
      default:
        return '$hours h';
    }
  }

  String _lastAutoBackupLabel() {
    if (_recoverySettings.lastAutoBackupAt == null) {
      return AppStrings.t('settings_last_auto_backup_never');
    }

    return AppStrings.tr(
      'settings_last_auto_backup_at',
      params: {
        'date': _recoverySettings.lastAutoBackupAt!.toLocal().toString(),
      },
    );
  }

  String _snapshotListEntryLabel(BackupSnapshotSummary snapshot) {
    return AppStrings.tr(
      'settings_snapshot_list_entry',
      params: {
        'date': snapshot.createdAt.toLocal().toString(),
        'count': snapshot.fileCount.toString(),
        'size': _formatBytes(snapshot.totalBytes),
      },
    );
  }

  Future<void> _resetLocalPreferences({bool showSnack = true}) async {
    final onboardingManager = context.read<OnboardingManager>();
    final themeProvider = context.read<ThemeProvider>();
    final localeProvider = context.read<LocaleProvider>();

    await _runWithLoading(AppStrings.t('settings_reset_preferences'), () async {
      await onboardingManager.reset();
      await themeProvider.resetToDefault();
      await localeProvider.resetToSystem();
    });

    if (!mounted || !showSnack) {
      return;
    }

    _showSnack(AppStrings.t('settings_preferences_reset_done'));
  }

  Future<void> _replayOnboarding() async {
    await _resetLocalPreferences(showSnack: false);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder:
            (routeContext) => OnboardingPage(
              onComplete: () {
                if (routeContext.mounted) {
                  Navigator.of(
                    routeContext,
                  ).pushNamedAndRemoveUntil('/home', (route) => false);
                }
              },
            ),
      ),
      (route) => false,
    );
  }

  Future<void> _showSnapshotPreview(BackupSnapshotSummary snapshot) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppStrings.t('settings_snapshot_preview_title')),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.tr(
                      'settings_snapshot_id',
                      params: {'id': snapshot.snapshotId},
                    ),
                  ),
                  Text(
                    AppStrings.tr(
                      'settings_snapshot_label',
                      params: {'label': snapshot.label},
                    ),
                  ),
                  Text(
                    AppStrings.tr(
                      'settings_snapshot_created_at',
                      params: {'date': snapshot.createdAt.toLocal().toString()},
                    ),
                  ),
                  Text(
                    AppStrings.tr(
                      'settings_snapshot_files_size',
                      params: {
                        'count': snapshot.fileCount.toString(),
                        'size': _formatBytes(snapshot.totalBytes),
                      },
                    ),
                  ),
                  Text(
                    AppStrings.tr(
                      'settings_snapshot_apps_count',
                      params: {'count': snapshot.appCount.toString()},
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.t('settings_snapshot_apps_list'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  if (snapshot.apps.isEmpty)
                    Text(AppStrings.t('settings_snapshot_no_metadata'))
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
                await _runWithLoading(
                  AppStrings.t('settings_snapshot_delete_loading'),
                  () async {
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
                      _showSnack(AppStrings.t('settings_snapshot_deleted'));
                    } catch (e, st) {
                      debugPrint('Delete snapshot failed: $e');
                      debugPrintStack(stackTrace: st);
                      if (!mounted) {
                        return;
                      }
                      _showSnack(_formatErrorMessage(e));
                    }
                  },
                );
              },
              child: Text(AppStrings.t('delete')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppStrings.t('close')),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _runWithLoading(
                  AppStrings.t('settings_snapshot_restore_loading'),
                  () async {
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
                      _showSnack(_formatErrorMessage(e));
                    }
                  },
                );
              },
              icon: const Icon(Icons.restore),
              label: Text(AppStrings.t('settings_restore_snapshot')),
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
          title: Text(AppStrings.t('settings_diagnostics_dialog_title')),
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
                  SnackBar(
                    content: Text(AppStrings.t('settings_diagnostics_copied')),
                  ),
                );
              },
              child: Text(AppStrings.t('copy')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppStrings.t('close')),
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
    final localeProvider = context.watch<LocaleProvider>();
    final detectedLocale = AppStrings.detectSystemLocale(
      Localizations.maybeLocaleOf(context),
    );
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('settings_tab')),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip:
                isDark
                    ? AppStrings.t('settings_theme_switch_light')
                    : AppStrings.t('settings_theme_switch_dark'),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
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
                    AppStrings.t('settings_backup_restore_title'),
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.t('settings_backup_restore_desc'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // ── Support Discord card ────────────────────────────────────
                  _SupportDiscordCard(),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t('settings_appearance_title'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.t('settings_language_desc'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<AppLocalePreference>(
                            initialValue: localeProvider.preference,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: AppStrings.t(
                                'settings_language_title',
                              ),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: AppLocalePreference.system,
                                child: _dropdownLabel(
                                  _languagePreferenceLabel(
                                    AppLocalePreference.system,
                                    detectedLocale,
                                  ),
                                ),
                              ),
                              ...AppLocale.values.map(
                                (locale) => DropdownMenuItem(
                                  value:
                                      locale == AppLocale.fr
                                          ? AppLocalePreference.fr
                                          : AppLocalePreference.en,
                                  child: _dropdownLabel(locale.label),
                                ),
                              ),
                            ],
                            selectedItemBuilder:
                                (context) =>
                                    AppLocalePreference.values
                                        .map(
                                          (preference) => Align(
                                            alignment: Alignment.centerLeft,
                                            child: _dropdownLabel(
                                              _languagePreferenceLabel(
                                                preference,
                                                detectedLocale,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                            onChanged: (value) async {
                              if (value == null) {
                                return;
                              }

                              await localeProvider.setPreference(value);
                              if (!mounted) {
                                return;
                              }
                              _showSnack(
                                AppStrings.t('settings_language_updated'),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (kDebugMode) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.t('settings_debug_title'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppStrings.t('settings_debug_desc'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.t('settings_reset_preferences_desc'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _isBusy
                                        ? null
                                        : () => _resetLocalPreferences(),
                                icon: const Icon(Icons.restart_alt),
                                label: Text(
                                  AppStrings.t('settings_reset_preferences'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.t('settings_replay_onboarding_desc'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isBusy ? null : () => _replayOnboarding(),
                                icon: const Icon(Icons.rocket_launch_outlined),
                                label: Text(
                                  AppStrings.t('settings_replay_onboarding'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
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
                          AppStrings.t('settings_drive_title'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (driveApi == null) ...[
                          Text(
                            AppStrings.t('settings_drive_desc'),
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
                                          AppStrings.t(
                                            'settings_drive_connect_loading',
                                          ),
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
                                                SnackBar(
                                                  content: Text(
                                                    AppStrings.t(
                                                      'settings_drive_connected',
                                                    ),
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
                                                  content: Text(
                                                    _formatErrorMessage(e),
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.g_mobiledata),
                                  const SizedBox(width: 8),
                                  Text(AppStrings.t('settings_drive_connect')),
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
                                AppStrings.t('settings_drive_status_connected'),
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
                                          AppStrings.t(
                                            'settings_drive_disconnect_loading',
                                          ),
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
                                              SnackBar(
                                                content: Text(
                                                  AppStrings.t(
                                                    'settings_drive_disconnected',
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.logout),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppStrings.t('settings_drive_disconnect'),
                                  ),
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
                    AppStrings.t('settings_data_operations_title'),
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
                            label: AppStrings.t('settings_export'),
                            onPressed:
                                _isBusy
                                    ? null
                                    : () async {
                                      await _runWithLoading(
                                        AppStrings.t('settings_export_loading'),
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
                                                content: Text(
                                                  _formatErrorMessage(e),
                                                ),
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
                            label: AppStrings.t('settings_import'),
                            onPressed:
                                _isBusy
                                    ? null
                                    : () async {
                                      await _runWithLoading(
                                        AppStrings.t('settings_import_loading'),
                                        () async {
                                          try {
                                            await _ensureDriveApiConnected();
                                            final message =
                                                await downloadAppData(
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
                                                content: Text(
                                                  _formatErrorMessage(e),
                                                ),
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
                          label: AppStrings.t('settings_export_app_data'),
                          onPressed:
                              _isBusy
                                  ? null
                                  : () async {
                                    await _runWithLoading(
                                      AppStrings.t('settings_export_loading'),
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
                                              content: Text(
                                                _formatErrorMessage(e),
                                              ),
                                            ),
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
                          label: AppStrings.t('settings_import_app_data'),
                          onPressed:
                              _isBusy
                                  ? null
                                  : () async {
                                    await _runWithLoading(
                                      AppStrings.t('settings_import_loading'),
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
                                              content: Text(
                                                _formatErrorMessage(e),
                                              ),
                                            ),
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
                    AppStrings.t('settings_recovery_title'),
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
                            title: Text(
                              AppStrings.t('settings_enable_auto_backup'),
                            ),
                            subtitle: Text(
                              AppStrings.t('settings_enable_auto_backup_desc'),
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
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: AppStrings.t(
                                'settings_auto_backup_interval',
                              ),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 6,
                                child: Text(_autoBackupIntervalLabel(6)),
                              ),
                              DropdownMenuItem(
                                value: 12,
                                child: Text(_autoBackupIntervalLabel(12)),
                              ),
                              DropdownMenuItem(
                                value: 24,
                                child: Text(_autoBackupIntervalLabel(24)),
                              ),
                              DropdownMenuItem(
                                value: 72,
                                child: Text(_autoBackupIntervalLabel(72)),
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
                            _lastAutoBackupLabel(),
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
                                            AppStrings.t(
                                              'settings_snapshot_create_loading',
                                            ),
                                            () async {
                                              try {
                                                await _ensureDriveApiConnected();
                                                final snapshot =
                                                    await createBackupSnapshot(
                                                      driveApi!,
                                                      appManager,
                                                      label: AppStrings.t(
                                                        'settings_manual_snapshot_label',
                                                      ),
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
                                                      AppStrings.tr(
                                                        'settings_snapshot_created_message',
                                                        params: {
                                                          'id':
                                                              snapshot
                                                                  .snapshotId,
                                                        },
                                                      ),
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
                                                    content: Text(
                                                      _formatErrorMessage(e),
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        },
                                icon: const Icon(Icons.backup),
                                label: Text(
                                  AppStrings.t('settings_backup_now'),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _isBusy ||
                                            !_recoverySettings.autoBackupEnabled
                                        ? null
                                        : () async {
                                          await _runWithLoading(
                                            AppStrings.t(
                                              'settings_auto_backup_check_loading',
                                            ),
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
                                label: Text(
                                  AppStrings.t('settings_run_auto_backup_now'),
                                ),
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
                              Expanded(
                                child: Text(
                                  AppStrings.t('settings_snapshots_title'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: AppStrings.t(
                                  'settings_snapshots_refresh',
                                ),
                                onPressed:
                                    _isBusy || _loadingSnapshots
                                        ? null
                                        : () async {
                                          await _runWithLoading(
                                            AppStrings.t(
                                              'settings_snapshots_refresh_loading',
                                            ),
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
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                AppStrings.t('settings_snapshots_empty'),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          else
                            ..._snapshots.take(8).map((snapshot) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(snapshot.label),
                                subtitle: Text(
                                  _snapshotListEntryLabel(snapshot),
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
                    AppStrings.t('settings_diagnostics_section_title'),
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
                            label: AppStrings.t('settings_view_startup_logs'),
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
                            label: AppStrings.t('settings_clear_logs'),
                            onPressed:
                                _isBusy
                                    ? null
                                    : () async {
                                      await AppDiagnostics.clearLog();
                                      if (!mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            AppStrings.t(
                                              'settings_logs_cleared',
                                            ),
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
                          label: AppStrings.t('settings_view_startup_logs'),
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
                          label: AppStrings.t('settings_clear_logs'),
                          onPressed:
                              _isBusy
                                  ? null
                                  : () async {
                                    await AppDiagnostics.clearLog();
                                    if (!mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppStrings.t('settings_logs_cleared'),
                                        ),
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

// ── Support Discord Card ───────────────────────────────────────────────────

class _SupportDiscordCard extends StatelessWidget {
  const _SupportDiscordCard();

  static const _discordUrl = 'https://discord.gg/gyEGNBUZdA';
  static const _discordColor = Color(0xFF5865F2);

  Future<void> _open() async {
    final uri = Uri.parse(_discordUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_discordColor, Color(0xFF7983F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      AppStrings.t('support_discord_badge'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.forum_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppStrings.t('support_card_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t('support_card_desc'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.90),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _open,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(AppStrings.t('support_join_discord')),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _discordColor,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
