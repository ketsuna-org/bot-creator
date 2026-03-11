import 'dart:convert';
import 'dart:io' as io;

import 'package:bot_creator/utils/app_diagnostics.dart';
import 'package:bot_creator/utils/database.dart';
import 'package:bot_creator/utils/drive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/drive/v3.dart';

class RecoverySettings {
  const RecoverySettings({
    required this.autoBackupEnabled,
    required this.autoBackupIntervalHours,
    required this.lastAutoBackupAt,
  });

  factory RecoverySettings.defaults() {
    return const RecoverySettings(
      autoBackupEnabled: false,
      autoBackupIntervalHours: 24,
      lastAutoBackupAt: null,
    );
  }

  factory RecoverySettings.fromJson(Map<String, dynamic> json) {
    return RecoverySettings(
      autoBackupEnabled: json['autoBackupEnabled'] == true,
      autoBackupIntervalHours:
          (json['autoBackupIntervalHours'] as num?)?.toInt() ?? 24,
      lastAutoBackupAt: DateTime.tryParse(
        (json['lastAutoBackupAt'] ?? '').toString(),
      ),
    );
  }

  final bool autoBackupEnabled;
  final int autoBackupIntervalHours;
  final DateTime? lastAutoBackupAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'autoBackupEnabled': autoBackupEnabled,
      'autoBackupIntervalHours': autoBackupIntervalHours,
      'lastAutoBackupAt': lastAutoBackupAt?.toUtc().toIso8601String(),
    };
  }

  RecoverySettings copyWith({
    bool? autoBackupEnabled,
    int? autoBackupIntervalHours,
    DateTime? lastAutoBackupAt,
  }) {
    return RecoverySettings(
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupIntervalHours:
          autoBackupIntervalHours ?? this.autoBackupIntervalHours,
      lastAutoBackupAt: lastAutoBackupAt ?? this.lastAutoBackupAt,
    );
  }
}

class AutoBackupRunResult {
  const AutoBackupRunResult({
    required this.executed,
    required this.message,
    this.snapshot,
  });

  final bool executed;
  final String message;
  final BackupSnapshotSummary? snapshot;
}

class RecoveryManager {
  static const String _fileName = 'recovery_settings.json';

  static Future<io.File> _settingsFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return io.File('${docs.path}/$_fileName');
  }

  static Future<RecoverySettings> loadSettings() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) {
        return RecoverySettings.defaults();
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return RecoverySettings.defaults();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return RecoverySettings.defaults();
      }
      return RecoverySettings.fromJson(
        Map<String, dynamic>.from(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    } catch (_) {
      return RecoverySettings.defaults();
    }
  }

  static Future<void> saveSettings(RecoverySettings settings) async {
    final file = await _settingsFile();
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
  }

  static bool isAutoBackupDue(RecoverySettings settings, DateTime nowUtc) {
    if (!settings.autoBackupEnabled) {
      return false;
    }
    final last = settings.lastAutoBackupAt?.toUtc();
    if (last == null) {
      return true;
    }
    final elapsed = nowUtc.difference(last);
    return elapsed.inHours >= settings.autoBackupIntervalHours;
  }

  static Future<AutoBackupRunResult> runAutoBackupIfDue({
    required DriveApi drive,
    required AppManager appManager,
    bool force = false,
  }) async {
    final settings = await loadSettings();
    final now = DateTime.now().toUtc();
    final shouldRun = force || isAutoBackupDue(settings, now);
    if (!shouldRun) {
      return const AutoBackupRunResult(
        executed: false,
        message: 'Auto-backup not due yet.',
      );
    }

    try {
      final snapshot = await createBackupSnapshot(
        drive,
        appManager,
        label: force ? 'Manual forced auto-backup' : 'Scheduled auto-backup',
      );
      await saveSettings(settings.copyWith(lastAutoBackupAt: now));

      await AppDiagnostics.logInfo(
        'Auto-backup snapshot created',
        data: <String, Object?>{
          'snapshotId': snapshot.snapshotId,
          'fileCount': snapshot.fileCount,
          'appCount': snapshot.appCount,
        },
      );

      return AutoBackupRunResult(
        executed: true,
        message: 'Auto-backup completed.',
        snapshot: snapshot,
      );
    } catch (error, stack) {
      await AppDiagnostics.logError(
        'Auto-backup failed',
        error,
        stack,
        fatal: false,
      );
      return AutoBackupRunResult(
        executed: false,
        message: 'Auto-backup failed: $error',
      );
    }
  }
}
