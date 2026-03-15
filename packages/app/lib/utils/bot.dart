library;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:bot_creator/actions/handler.dart';
import 'package:bot_creator/main.dart';
import 'package:bot_creator/types/action.dart';
import 'package:bot_creator_shared/actions/handle_component_interaction.dart';
import 'package:bot_creator_shared/actions/interaction_response.dart';
import 'package:bot_creator/utils/database.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:bot_creator/utils/template_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';

part 'bot.logs.dart';
part 'bot.template.dart';
part 'bot.mobile_service.dart';
part 'bot.commands.dart';

NyxxGateway? _desktopGateway;
StreamSubscription<LogRecord>? _desktopNyxxLogsSubscription;
Timer? _desktopMetricsTimer;
Timer? _desktopStatusRotationTimer;
String? _desktopRunningBotId;
String? get desktopRunningBotId => _desktopRunningBotId;
String? _mobileRunningBotId;
String? get mobileRunningBotId => _mobileRunningBotId;
void setMobileRunningBotId(String? id) => _mobileRunningBotId = id;

const int _maxBotLogLines = 500;
final StreamController<List<String>> _botLogsController =
    StreamController<List<String>>.broadcast();
final StreamController<int?> _botProcessRssController =
    StreamController<int?>.broadcast();
final StreamController<int?> _botEstimatedRssController =
    StreamController<int?>.broadcast();
final StreamController<double?> _botProcessCpuController =
    StreamController<double?>.broadcast();
final StreamController<int?> _botProcessStorageController =
    StreamController<int?>.broadcast();
List<String> _botLogs = <String>[];
String? _activeBotLogBotId;
bool _debugBotLogsEnabled = false;
const String _debugLogsEnabledDataKey = 'debugLogsEnabled';
int? _botProcessRssBytes;
int? _botBaselineRssBytes;
DateTime? _botBaselineCapturedAt;
int? _botEstimatedRssBytes;
double? _botProcessCpuPercent;
int? _botProcessStorageBytes;
bool _botRuntimeActive = false;
final Random _desktopStatusRandom = Random();

bool get isDesktopBotRunning => _desktopGateway != null;
bool get isBotDebugLogsEnabled => _debugBotLogsEnabled;
bool get isBotRuntimeActive => _botRuntimeActive;

void applyDesktopRuntimeSettings({
  required String botId,
  required Map<String, dynamic> appData,
}) {
  final gateway = _desktopGateway;
  if (gateway == null) {
    return;
  }
  if (_desktopRunningBotId != null && _desktopRunningBotId != botId) {
    return;
  }

  _startDesktopStatusRotation(gateway, appData);
}

void setBotDebugLogsEnabled(bool enabled) {
  _debugBotLogsEnabled = enabled;
  appendBotLog(
    enabled ? 'Mode debug logs activé' : 'Mode debug logs désactivé',
  );
  unawaited(_persistDebugLogsEnabled(enabled));
}

String _two(int value) => value < 10 ? '0$value' : '$value';

String _timestampNow() {
  final now = DateTime.now();
  return '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
}

/// Convert the intents configuration map to GatewayIntents
Flags<GatewayIntents> buildGatewayIntents(Map<String, bool>? intentsMap) {
  if (intentsMap == null || intentsMap.isEmpty) {
    return GatewayIntents.allUnprivileged;
  }

  Flags<GatewayIntents> intents = GatewayIntents.none;

  if (intentsMap['Guild Presence'] == true) {
    intents = intents | GatewayIntents.guildPresences;
  }
  if (intentsMap['Guild Members'] == true) {
    intents = intents | GatewayIntents.guildMembers;
  }
  if (intentsMap['Message Content'] == true) {
    intents = intents | GatewayIntents.messageContent;
  }
  if (intentsMap['Direct Messages'] == true) {
    intents = intents | GatewayIntents.directMessages;
  }
  if (intentsMap['Guilds'] == true) {
    intents = intents | GatewayIntents.guilds;
  }
  if (intentsMap['Guild Messages'] == true) {
    intents = intents | GatewayIntents.guildMessages;
  }
  if (intentsMap['Guild Message Reactions'] == true) {
    intents = intents | GatewayIntents.guildMessageReactions;
  }
  if (intentsMap['Direct Message Reactions'] == true) {
    intents = intents | GatewayIntents.directMessageReactions;
  }
  if (intentsMap['Guild Message Typing'] == true) {
    intents = intents | GatewayIntents.guildMessageTyping;
  }
  if (intentsMap['Direct Message Typing'] == true) {
    intents = intents | GatewayIntents.directMessageTyping;
  }
  if (intentsMap['Guild Scheduled Events'] == true) {
    intents = intents | GatewayIntents.guildScheduledEvents;
  }
  if (intentsMap['Auto Moderation Configuration'] == true) {
    intents = intents | GatewayIntents.autoModerationConfiguration;
  }
  if (intentsMap['Auto Moderation Execution'] == true) {
    intents = intents | GatewayIntents.autoModerationExecution;
  }

  if (intents == GatewayIntents.none) {
    return GatewayIntents.allUnprivileged;
  }

  return intents;
}

Future<void> startDesktopBot(String token) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    throw Exception('Desktop bot mode is only available on desktop platforms.');
  }

  if (_desktopGateway != null) {
    appendBotLog('Le bot desktop est déjà en cours d’exécution');
    return;
  }
  appendBotLog('Démarrage du bot desktop...');
  appendBotDebugLog('Plateforme desktop détectée');

  final botUser = await getDiscordUser(token);
  final appData = await appManager.getApp(botUser.id.toString());
  final intentsMap = Map<String, bool>.from(appData['intents'] as Map? ?? {});
  final intents = buildGatewayIntents(intentsMap);
  _bindDesktopNyxxLogs(botId: botUser.id.toString());
  appendBotDebugLog(
    'Intents actifs: ${intentsMap.entries.where((e) => e.value).length}',
    botId: botUser.id.toString(),
  );

  final gateway = await Nyxx.connectGateway(
    token,
    intents,
    options: GatewayClientOptions(
      loggerName: 'CardiaKexaDesktop',
      plugins: [Logging(logLevel: Level.ALL)],
    ),
  );

  gateway.onReady.listen((event) async {
    final botId = event.gateway.client.user.id.toString();
    _desktopRunningBotId = botId;
    setBotRuntimeActive(true);
    appendBotLog('Bot desktop connecté et prêt', botId: botId);
    unawaited(appManager.updateGuildCount(botId, event.guilds.length));
    unawaited(_refreshBotMetrics(botId: botId));
    _desktopMetricsTimer?.cancel();
    _desktopMetricsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refreshBotMetrics(botId: botId));
    });
    _startDesktopStatusRotation(gateway, appData);
    appManager = AppManager();
    gateway.onInteractionCreate.listen((event) async {
      await handleLocalCommands(event, appManager);
    });
  });

  _desktopGateway = gateway;
}

Future<void> stopDesktopBot() async {
  appendBotLog('Arrêt du bot desktop demandé');
  _desktopMetricsTimer?.cancel();
  _desktopMetricsTimer = null;
  _desktopStatusRotationTimer?.cancel();
  _desktopStatusRotationTimer = null;
  await _desktopGateway?.close();
  _desktopGateway = null;
  _desktopRunningBotId = null;
  await _desktopNyxxLogsSubscription?.cancel();
  _desktopNyxxLogsSubscription = null;
  _updateBotMetrics(
    rssBytes: null,
    cpuPercent: null,
    storageBytes: null,
    overwriteNulls: true,
  );
  setBotRuntimeActive(false);
}

void _startDesktopStatusRotation(
  NyxxGateway gateway,
  Map<String, dynamic> appData,
) {
  _desktopStatusRotationTimer?.cancel();
  _desktopStatusRotationTimer = null;

  final statuses = _normalizeStatuses(appData['statuses']);
  if (statuses.isEmpty) {
    return;
  }

  unawaited(_applyDesktopInitialStatusThenRotate(gateway, statuses));
}

Future<void> _applyDesktopInitialStatusThenRotate(
  NyxxGateway gateway,
  List<Map<String, dynamic>> statuses,
) async {
  if (statuses.isEmpty) {
    return;
  }

  final firstStatus = statuses.first;
  await _applyDesktopStatus(gateway, firstStatus);

  // Re-send once after READY to avoid occasional dropped first presence frame.
  Timer(const Duration(seconds: 3), () {
    unawaited(_applyDesktopStatus(gateway, firstStatus));
  });

  final min = (firstStatus['minIntervalSeconds'] as int?) ?? 60;
  final max = (firstStatus['maxIntervalSeconds'] as int?) ?? min;
  final delaySeconds =
      max <= min ? min : min + _desktopStatusRandom.nextInt(max - min + 1);

  _desktopStatusRotationTimer?.cancel();
  _desktopStatusRotationTimer = Timer(Duration(seconds: delaySeconds), () {
    unawaited(_applyDesktopRandomStatus(gateway, statuses));
  });
}

Future<void> _applyDesktopStatus(
  NyxxGateway gateway,
  Map<String, dynamic> status,
) async {
  final type = (status['type'] ?? 'playing').toString();
  final text = _sanitizeDesktopActivityText((status['text'] ?? '').toString());

  if (text.isEmpty) {
    return;
  }

  try {
    gateway.updatePresence(
      PresenceBuilder(
        status: CurrentUserStatus.online,
        isAfk: false,
        activities: <ActivityBuilder>[
          ActivityBuilder(name: text, type: _mapDesktopActivityType(type)),
        ],
      ),
    );
    appendBotLog(
      'Presence desktop appliquée: $type $text',
      botId: _desktopRunningBotId,
    );
  } catch (error) {
    appendBotDebugLog('Status rotation update failed: $error');
  }
}

Future<void> _applyDesktopRandomStatus(
  NyxxGateway gateway,
  List<Map<String, dynamic>> statuses,
) async {
  if (statuses.isEmpty) {
    return;
  }

  final picked = statuses[_desktopStatusRandom.nextInt(statuses.length)];
  final min = (picked['minIntervalSeconds'] as int?) ?? 60;
  final max = (picked['maxIntervalSeconds'] as int?) ?? min;

  await _applyDesktopStatus(gateway, picked);

  final delaySeconds =
      max <= min ? min : min + _desktopStatusRandom.nextInt(max - min + 1);
  _desktopStatusRotationTimer?.cancel();
  _desktopStatusRotationTimer = Timer(Duration(seconds: delaySeconds), () {
    unawaited(_applyDesktopRandomStatus(gateway, statuses));
  });
}

List<Map<String, dynamic>> _normalizeStatuses(dynamic raw) {
  if (raw is! List) {
    return const <Map<String, dynamic>>[];
  }

  final normalized = <Map<String, dynamic>>[];
  for (final entry in raw.whereType<Map>()) {
    final map = Map<String, dynamic>.from(entry);
    final text = (map['text'] ?? '').toString().trim();
    if (text.isEmpty) {
      continue;
    }
    final min =
        int.tryParse((map['minIntervalSeconds'] ?? '').toString()) ?? 60;
    final maxRaw =
        int.tryParse((map['maxIntervalSeconds'] ?? '').toString()) ?? min;
    final max = maxRaw < min ? min : maxRaw;
    normalized.add({
      'type': (map['type'] ?? 'playing').toString().trim().toLowerCase(),
      'text': text,
      'minIntervalSeconds': min > 0 ? min : 60,
      'maxIntervalSeconds': max > 0 ? max : 60,
    });
  }

  return normalized;
}

ActivityType _mapDesktopActivityType(String rawType) {
  switch (rawType.trim().toLowerCase()) {
    case 'streaming':
      // Streaming requires URL support; fallback to game for reliable display.
      return ActivityType.game;
    case 'listening':
      return ActivityType.listening;
    case 'watching':
      return ActivityType.watching;
    case 'competing':
      return ActivityType.competing;
    case 'playing':
    default:
      return ActivityType.game;
  }
}

String _sanitizeDesktopActivityText(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.length > 120) {
    return trimmed.substring(0, 120);
  }
  return trimmed;
}

Future<void> createCommand(
  NyxxRest client,
  ApplicationCommandBuilder commandBuilder, {
  Map<String, dynamic> data = const {},
}) async {
  try {
    final command = await client.commands.create(commandBuilder);
    final Map<String, dynamic> commandData = {
      'name': command.name,
      'description': command.description,
      'id': command.id.toString(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    if (data.isNotEmpty) {
      commandData['data'] = data;
    }
    appManager.saveAppCommand(
      client.user.id.toString(),
      command.id.toString(),
      commandData,
    );
  } catch (e) {
    throw Exception('Failed to create command: $e');
  }
}

Future<void> updateCommand(
  NyxxRest client,
  Snowflake commandId, {
  required ApplicationCommandUpdateBuilder commandBuilder,
  Map<String, dynamic> data = const {},
}) async {
  try {
    final command = await client.commands.update(commandId, commandBuilder);
    final Map<String, dynamic> commandData = {
      'name': command.name,
      'description': command.description,
      'id': command.id.toString(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (data.isNotEmpty) {
      commandData['data'] = data;
    }
    appManager.saveAppCommand(
      client.user.id.toString(),
      command.id.toString(),
      commandData,
    );
  } catch (e) {
    throw Exception('Failed to update command: $e');
  }
}
