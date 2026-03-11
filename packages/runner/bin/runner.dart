import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:bot_creator_runner/config_loader.dart';
import 'package:bot_creator_runner/discord_runner.dart';
import 'package:logging/logging.dart';

const _usageHeader =
    'Bot Creator Runner\n'
    '\n'
    'Runs a Discord bot from a ZIP export that contains bot.json.\n'
    '\n'
    'Usage:\n'
    '  dart run packages/runner/bin/runner.dart --config <path/to/export.zip>\n'
    '  dart run packages/runner/bin/runner.dart <path/to/export.zip>\n';

Future<void> main(List<String> args) async {
  final parser =
      ArgParser()
        ..addOption(
          'config',
          abbr: 'c',
          help: 'Path to the bot export ZIP file.',
          valueHelp: 'file.zip',
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

  if (configPath.isEmpty) {
    stderr.writeln('Missing required option: --config');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    stderr.writeln('Config ZIP not found: $configPath');
    exitCode = 66;
    return;
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

  final config = loadConfigFromZip(configPath);
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
