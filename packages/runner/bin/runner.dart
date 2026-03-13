import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_runner/config_loader.dart';
import 'package:bot_creator_runner/drive_config_loader.dart';
import 'package:bot_creator_runner/discord_runner.dart';
import 'package:logging/logging.dart';

const _usageHeader =
    'Bot Creator Runner\n'
    '\n'
    'Runs a Discord bot from a local ZIP export OR from Google Drive backups.\n'
    '\n'
    'Usage:\n'
    '  dart run packages/runner/bin/runner.dart --config <path/to/export.zip>\n'
    '  dart run packages/runner/bin/runner.dart <path/to/export.zip>\n'
    '  dart run packages/runner/bin/runner.dart --drive-bot-id <bot_id>\n';

Future<void> main(List<String> args) async {
  final parser =
      ArgParser()
        ..addOption(
          'config',
          abbr: 'c',
          help: 'Path to the bot export ZIP file.',
          valueHelp: 'file.zip',
        )
        ..addOption(
          'drive-bot-id',
          help:
              'Load bot configuration from Google Drive backups for this bot '
              'ID (uses appDataFolder/backups_v2).',
          valueHelp: '123456789012345678',
        )
        ..addOption(
          'drive-snapshot',
          help:
              'Specific snapshot ID to use when loading from Google Drive. '
              'If omitted, the latest snapshot is used.',
          valueHelp: '2026-03-11T22-01-09-000Z',
        )
        ..addOption(
          'drive-client-id',
          help:
              'Override Google OAuth desktop client ID for Drive mode. '
              'Defaults to the app client ID.',
          valueHelp: 'xxxx.apps.googleusercontent.com',
        )
        ..addOption(
          'drive-client-secret',
          help:
              'Override Google OAuth desktop client secret for Drive mode. '
              'Defaults to the app client secret.',
          valueHelp: 'GOCSPX-...',
        )
        ..addFlag(
          'drive-no-open',
          negatable: false,
          help:
              'Do not try to open the browser automatically in Drive mode. '
              'Auth URL will still be printed.',
        )
        ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help.');

  late final ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    stderr.writeln('Invalid arguments: $e');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (results.flag('help')) {
    _printUsage(parser);
    return;
  }

  var configPath = (results.option('config') ?? '').trim();
  if (configPath.isEmpty && results.rest.isNotEmpty) {
    configPath = results.rest.first.trim();
  }
  final driveBotId = (results.option('drive-bot-id') ?? '').trim();
  final driveSnapshot = (results.option('drive-snapshot') ?? '').trim();
  final driveClientId = (results.option('drive-client-id') ?? '').trim();
  final driveClientSecret =
      (results.option('drive-client-secret') ?? '').trim();
  final driveNoOpen = results.flag('drive-no-open');

  if (configPath.isNotEmpty && driveBotId.isNotEmpty) {
    stderr.writeln(
      'Options conflict: use either --config or --drive-bot-id, not both.',
    );
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (configPath.isEmpty && driveBotId.isEmpty) {
    stderr.writeln('Missing required option: --config or --drive-bot-id');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (configPath.isNotEmpty) {
    final configFile = File(configPath);
    if (!configFile.existsSync()) {
      stderr.writeln('Config ZIP not found: $configPath');
      exitCode = 66;
      return;
    }
  }

  Logger.root
    ..level = Level.INFO
    ..onRecord.listen((record) {
      final errorPart = record.error == null ? '' : ' | ${record.error}';
      stdout.writeln(
        '[${record.level.name}] ${record.loggerName}: ${record.message}$errorPart',
      );
      if (record.stackTrace != null) {
        stdout.writeln(record.stackTrace);
      }
    });

  late final BotConfig config;
  try {
    if (configPath.isNotEmpty) {
      config = loadConfigFromZip(configPath);
    } else {
      config = await loadConfigFromGoogleDrive(
        botId: driveBotId,
        snapshotId: driveSnapshot.isEmpty ? null : driveSnapshot,
        clientId: driveClientId.isEmpty ? null : driveClientId,
        clientSecret: driveClientSecret.isEmpty ? null : driveClientSecret,
        openBrowser: !driveNoOpen,
        onInfo: stdout.writeln,
      );
    }
  } catch (e, st) {
    stderr.writeln('Failed to load config: $e');
    stderr.writeln(st);
    exitCode = 65;
    return;
  }

  final runner = DiscordRunner(config);

  final shutdownCompleter = Completer<void>();
  Future<void> shutdown() async {
    if (shutdownCompleter.isCompleted) return;
    shutdownCompleter.complete();
    await runner.stop();
  }

  ProcessSignal.sigint.watch().listen((_) async {
    await shutdown();
  });

  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) async {
      await shutdown();
    });
  }

  try {
    await runner.start();
    stdout.writeln('Runner started. Press Ctrl+C to stop.');
    await shutdownCompleter.future;
  } catch (e, st) {
    stderr.writeln('Failed to start runner: $e');
    stderr.writeln(st);
    exitCode = 1;
  }
}

void _printUsage(ArgParser parser) {
  stdout
    ..writeln(_usageHeader)
    ..writeln(parser.usage);
}
