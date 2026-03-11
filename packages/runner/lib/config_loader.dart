import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:bot_creator_shared/bot/bot_config.dart';

/// Extracts a [BotConfig] from a ZIP file that contains a single `bot.json` entry.
///
/// The ZIP must contain a `bot.json` file at its root with the schema:
/// ```json
/// {
///   "token": "...",
///   "intents": { "Guild Messages": true, ... },
///   "globalVariables": { "key": "value" },
///   "workflows": [ ... ],
///   "commands": [ { "id": "...", "name": "...", "data": { ... } } ]
/// }
/// ```
BotConfig loadConfigFromZip(String zipPath) {
  final bytes = File(zipPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);

  ArchiveFile? botJsonFile;
  for (final file in archive) {
    if (file.isFile && file.name.endsWith('bot.json')) {
      botJsonFile = file;
      break;
    }
  }

  if (botJsonFile == null) {
    throw ArgumentError(
      'No bot.json found in $zipPath. '
      'Make sure the ZIP contains a bot.json at its root.',
    );
  }

  final jsonString = utf8.decode(botJsonFile.content as List<int>);
  final config = parseBotConfig(jsonString);
  config.validate();
  return config;
}
