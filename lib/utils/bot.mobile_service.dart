part of 'bot.dart';

Future<void> startService() async {
  debugPrint('[Bot] startService() called');
  await FlutterForegroundTask.startService(
    serviceId: 110,
    notificationTitle: 'Bot is running',
    notificationText: 'Bot is running in the background',
    callback: startCallback,
    notificationButtons: [NotificationButton(id: 'stop', text: 'Stop')],
  );
}

@pragma('vm:entry-point')
void startCallback() {
  ui.DartPluginRegistrant.ensureInitialized();
  debugPrint('[Bot] startCallback() invoked');
  FlutterForegroundTask.setTaskHandler(DiscordBotTaskHandler());
}

@pragma('vm:entry-point')
void stopCallback() {
  FlutterForegroundTask.stopService();
}

@pragma('vm:entry-point')
class DiscordBotTaskHandler extends TaskHandler {
  NyxxGateway? client;
  bool isReady = false;
  AppManager? _manager;
  String? _botId;
  StreamSubscription<LogRecord>? _mobileNyxxLogsSubscription;
  bool? _lastKnownDebugEnabled;

  Future<void> _syncDebugFlagFromMain() async {
    try {
      final persisted = await FlutterForegroundTask.getData<bool>(
        key: _debugLogsEnabledDataKey,
      );
      if (persisted != null) {
        final changed = _lastKnownDebugEnabled != persisted;
        _debugBotLogsEnabled = persisted;
        _lastKnownDebugEnabled = persisted;
        if (changed) {
          await _emitTaskLogToMain(
            persisted
                ? 'Debug logs mobile activés'
                : 'Debug logs mobile désactivés',
            botId: _botId,
          );
        }
      }
    } catch (_) {}
  }

  void _bindMobileNyxxLogs() {
    unawaited(_mobileNyxxLogsSubscription?.cancel());
    Logger.root.level = Level.ALL;
    _mobileNyxxLogsSubscription = Logger.root.onRecord.listen((record) {
      // Sur mobile, certains logs Nyxx n'utilisent pas toujours le préfixe
      // logger attendu. On laisse passer les records et le filtre final se fait
      // via _emitTaskDebugLogToMain (actif uniquement en mode debug).
      unawaited(
        _emitTaskDebugLogToMain(_formatNyxxLogRecord(record), botId: _botId),
      );
    });
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    ui.DartPluginRegistrant.ensureInitialized();
    debugPrint('[Bot] DiscordBotTaskHandler.onStart()');
    await _syncDebugFlagFromMain();
    await _emitTaskLogToMain('Service mobile démarré');
    await _emitTaskMetricsToMain(botId: _botId);
    developer.log('Starting Discord bot', name: 'DiscordBotTaskHandler');
    _manager ??= AppManager();

    final token = await FlutterForegroundTask.getData<String>(key: 'token');
    debugPrint(
      '[Bot] token present: ${token != null && token.trim().isNotEmpty}',
    );
    if (token != null && token.toString().trim().isNotEmpty) {
      try {
        _bindMobileNyxxLogs();
        await _emitTaskLogToMain('Token trouvé, connexion en cours');
        await _emitTaskDebugLogToMain('Longueur token: ${token.length}');
        developer.log('Token: $token', name: 'DiscordBotTaskHandler');

        final botUser = await getDiscordUser(token);
        _botId = botUser.id.toString();
        await _emitTaskLogToMain(
          'Authentification Discord réussie (${botUser.username})',
          botId: _botId,
        );
        final appData = await _manager!.getApp(botUser.id.toString());
        final intentsMap = Map<String, bool>.from(
          appData['intents'] as Map? ?? {},
        );
        final intents = buildGatewayIntents(intentsMap);
        await _emitTaskDebugLogToMain(
          'Intents actifs: ${intentsMap.entries.where((e) => e.value).length}',
          botId: _botId,
        );

        final gateway = await Nyxx.connectGateway(
          token,
          intents,
          options: GatewayClientOptions(
            loggerName: 'CardiaKexa',
            plugins: [Logging(logLevel: Level.ALL)],
          ),
        );
        gateway.onReady.listen((event) async {
          debugPrint('[Bot] Gateway connected and ready');
          await _emitTaskLifecycleToMain('started', botId: _botId);
          await _emitTaskLogToMain(
            'Bot mobile connecté et prêt',
            botId: _botId,
          );
          await _emitTaskMetricsToMain(botId: _botId);
          isReady = true;
          gateway.onInteractionCreate.listen((event) async {
            await handleLocalCommands(event, _manager!);
          });
        });

        client = gateway;
      } catch (e) {
        debugPrint('[Bot] Failed to connect to Discord: $e');
        await _emitTaskLifecycleToMain('stopped', botId: _botId);
        await _emitTaskLogToMain(
          'Échec de connexion Discord: $e',
          botId: _botId,
        );
        developer.log(
          'Failed to connect to Discord: $e',
          name: 'DiscordBotTaskHandler',
        );
      }
    } else {
      debugPrint('[Bot] Token not found or empty');
      await _emitTaskLifecycleToMain('stopped', botId: _botId);
      await _emitTaskLogToMain('Token absent ou vide');
      developer.log('Token not found or empty', name: 'DiscordBotTaskHandler');
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      unawaited(
        _emitTaskLogToMain(
          'Arrêt demandé depuis la notification',
          botId: _botId,
        ),
      );
      stopCallback();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _emitTaskLifecycleToMain('stopped', botId: _botId);
    await _mobileNyxxLogsSubscription?.cancel();
    _mobileNyxxLogsSubscription = null;
    await client?.close();
    client = null;
    if (isTimeout) {
      await _emitTaskLogToMain(
        'Service interrompu (timeout), redémarrage...',
        botId: _botId,
      );
      developer.log('Service timeout', name: 'DiscordBotTaskHandler');
      await startService();
    } else {
      await _emitTaskLogToMain('Service arrêté', botId: _botId);
      developer.log('Service stopped', name: 'DiscordBotTaskHandler');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_syncDebugFlagFromMain());
    unawaited(_emitTaskMetricsToMain(botId: _botId));
    unawaited(_emitTaskLogToMain('Heartbeat service', botId: _botId));
    developer.log('Repeat event', name: 'DiscordBotTaskHandler');
  }
}
