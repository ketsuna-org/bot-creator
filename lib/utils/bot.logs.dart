part of 'bot.dart';

class _CpuSample {
  const _CpuSample({required this.jiffies, required this.timestampMs});

  final int jiffies;
  final int timestampMs;
}

_CpuSample? _lastCpuSample;

Future<void> _persistDebugLogsEnabled(bool enabled) async {
  try {
    await FlutterForegroundTask.saveData(
      key: _debugLogsEnabledDataKey,
      value: enabled,
    );
  } catch (_) {}
}

int? _readCurrentProcessRssBytes() {
  try {
    return ProcessInfo.currentRss;
  } catch (_) {
    return null;
  }
}

void captureBotBaselineRss({bool force = false}) {
  if (!force && _botBaselineRssBytes != null) {
    return;
  }
  final current = _readCurrentProcessRssBytes();
  if (current == null) {
    return;
  }
  _botBaselineRssBytes = current;
  _botBaselineCapturedAt = DateTime.now();
  if (!_botEstimatedRssController.isClosed) {
    _botEstimatedRssController.add(_botEstimatedRssBytes);
  }
}

void clearBotBaselineRss() {
  _botBaselineRssBytes = null;
  _botBaselineCapturedAt = null;
  _botEstimatedRssBytes = null;
  if (!_botEstimatedRssController.isClosed) {
    _botEstimatedRssController.add(null);
  }
}

void setBotRuntimeActive(bool active) {
  _botRuntimeActive = active;
  if (active) {
    return;
  }

  clearBotBaselineRss();
  _lastCpuSample = null;
  _updateBotMetrics(
    rssBytes: null,
    cpuPercent: null,
    storageBytes: null,
    overwriteNulls: true,
  );
}

int? _readCurrentProcessCpuJiffies() {
  if (!(Platform.isAndroid || Platform.isLinux)) {
    return null;
  }

  try {
    final stat = File('/proc/self/stat').readAsStringSync();
    final lastParen = stat.lastIndexOf(')');
    if (lastParen == -1 || lastParen + 2 >= stat.length) {
      return null;
    }
    final afterState = stat.substring(lastParen + 2).trim();
    final fields = afterState.split(RegExp(r'\s+'));
    if (fields.length <= 11) {
      return null;
    }

    final utime = int.tryParse(fields[10]);
    final stime = int.tryParse(fields[11]);
    if (utime == null || stime == null) {
      return null;
    }
    return utime + stime;
  } catch (_) {
    return null;
  }
}

double? _readCurrentProcessCpuPercent() {
  final jiffies = _readCurrentProcessCpuJiffies();
  if (jiffies == null) {
    return null;
  }

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final prev = _lastCpuSample;
  _lastCpuSample = _CpuSample(jiffies: jiffies, timestampMs: nowMs);

  if (prev == null) {
    return 0.0;
  }

  final deltaJiffies = jiffies - prev.jiffies;
  final deltaMs = nowMs - prev.timestampMs;
  if (deltaJiffies <= 0 || deltaMs <= 0) {
    return 0;
  }

  const ticksPerSecond = 100.0;
  final elapsedSeconds = deltaMs / 1000.0;
  final cpuSeconds = deltaJiffies / ticksPerSecond;
  final cores = Platform.numberOfProcessors.clamp(1, 64);
  final percent = (cpuSeconds / elapsedSeconds) * 100.0 / cores;
  if (percent.isNaN || percent.isInfinite) {
    return null;
  }
  return percent.clamp(0, 100.0);
}

Future<int?> _readBotStorageBytes({String? botId}) async {
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final basePath = docsDir.path;
    final appsDir = Directory('$basePath/apps');
    if (!await appsDir.exists()) {
      return 0;
    }

    Future<int> dirSize(Directory dir) async {
      var total = 0;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
      return total;
    }

    if (botId == null || botId.isEmpty) {
      return await dirSize(appsDir);
    }

    var total = 0;
    final botJson = File('$basePath/apps/$botId.json');
    if (await botJson.exists()) {
      total += await botJson.length();
    }
    final botDir = Directory('$basePath/apps/$botId');
    if (await botDir.exists()) {
      total += await dirSize(botDir);
    }
    return total;
  } catch (_) {
    return null;
  }
}

void _updateBotMetrics({
  int? rssBytes,
  double? cpuPercent,
  int? storageBytes,
  String? botId,
  bool overwriteNulls = false,
}) {
  if (_activeBotLogBotId != null &&
      botId != null &&
      _activeBotLogBotId != botId) {
    return;
  }

  if (overwriteNulls || rssBytes != null) {
    _botProcessRssBytes = rssBytes;
  }
  if (overwriteNulls || cpuPercent != null) {
    _botProcessCpuPercent = cpuPercent;
  }
  if (overwriteNulls || storageBytes != null) {
    _botProcessStorageBytes = storageBytes;
  }

  if (!_botProcessRssController.isClosed) {
    _botProcessRssController.add(_botProcessRssBytes);
  }

  final currentRss = _botProcessRssBytes;
  if (currentRss != null && _botBaselineRssBytes != null) {
    _botEstimatedRssBytes = (currentRss - _botBaselineRssBytes!).clamp(
      0,
      currentRss,
    );
  } else if (overwriteNulls || currentRss == null) {
    _botEstimatedRssBytes = null;
  }

  if (!_botEstimatedRssController.isClosed) {
    _botEstimatedRssController.add(_botEstimatedRssBytes);
  }

  if (!_botProcessCpuController.isClosed) {
    _botProcessCpuController.add(_botProcessCpuPercent);
  }
  if (!_botProcessStorageController.isClosed) {
    _botProcessStorageController.add(_botProcessStorageBytes);
  }
}

Future<void> _refreshBotMetrics({String? botId}) async {
  final rss = _readCurrentProcessRssBytes();
  final cpu = _readCurrentProcessCpuPercent();
  final storage = await _readBotStorageBytes(botId: botId);
  _updateBotMetrics(
    rssBytes: rss,
    cpuPercent: cpu,
    storageBytes: storage,
    botId: botId,
  );
}

Future<void> refreshBotStatsNow({
  String? botId,
  bool captureBaseline = false,
}) async {
  if (!isBotRuntimeActive) {
    _updateBotMetrics(
      rssBytes: null,
      cpuPercent: null,
      storageBytes: null,
      botId: botId,
      overwriteNulls: true,
    );
    return;
  }

  if (captureBaseline) {
    captureBotBaselineRss(force: true);
  }
  await _refreshBotMetrics(botId: botId);
}

Stream<int?> getBotProcessRssStream() => _botProcessRssController.stream;

int? getBotProcessRssBytes() => _botProcessRssBytes;

Stream<int?> getBotEstimatedRssStream() => _botEstimatedRssController.stream;

int? getBotEstimatedRssBytes() => _botEstimatedRssBytes;

int? getBotBaselineRssBytes() => _botBaselineRssBytes;

DateTime? getBotBaselineCapturedAt() => _botBaselineCapturedAt;

Stream<double?> getBotProcessCpuStream() => _botProcessCpuController.stream;

double? getBotProcessCpuPercent() => _botProcessCpuPercent;

Stream<int?> getBotProcessStorageStream() =>
    _botProcessStorageController.stream;

int? getBotProcessStorageBytes() => _botProcessStorageBytes;

Future<void> _emitTaskMetricsToMain({String? botId}) async {
  final rssBytes = _readCurrentProcessRssBytes();
  final cpuPercent = _readCurrentProcessCpuPercent();
  final storageBytes = await _readBotStorageBytes(botId: botId);
  try {
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{
      'type': 'bot_metrics',
      'botId': botId,
      'rssBytes': rssBytes,
      'cpuPercent': cpuPercent,
      'storageBytes': storageBytes,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {}
}

void _publishBotLogs() {
  if (_botLogsController.isClosed) {
    return;
  }
  _botLogsController.add(List<String>.unmodifiable(_botLogs));
}

Stream<List<String>> getBotLogsStream() => _botLogsController.stream;

List<String> getBotLogsSnapshot() => List<String>.unmodifiable(_botLogs);

void startBotLogSession({required String botId}) {
  _activeBotLogBotId = botId;
  _botLogs = <String>[];
  captureBotBaselineRss(force: true);
  _lastCpuSample = null;
  _updateBotMetrics(
    rssBytes: null,
    cpuPercent: null,
    storageBytes: null,
    botId: botId,
    overwriteNulls: true,
  );
  appendBotLog('Session de logs démarrée', botId: botId);
}

void appendBotLog(String message, {String? botId}) {
  if (_activeBotLogBotId != null &&
      botId != null &&
      _activeBotLogBotId != botId) {
    return;
  }
  final line = '[${_timestampNow()}] $message';
  _botLogs.add(line);
  if (_botLogs.length > _maxBotLogLines) {
    _botLogs = _botLogs.sublist(_botLogs.length - _maxBotLogLines);
  }
  _publishBotLogs();
}

void appendBotDebugLog(String message, {String? botId}) {
  if (!_debugBotLogsEnabled) {
    return;
  }
  appendBotLog('DEBUG: $message', botId: botId);
}

String _formatNyxxLogRecord(LogRecord record) {
  final buffer = StringBuffer(
    '[${record.level.name}] [${record.loggerName}] ${record.message}',
  );
  if (record.error != null) {
    buffer.write(' | error=${record.error}');
  }
  return buffer.toString();
}

void _bindDesktopNyxxLogs({String? botId}) {
  _desktopNyxxLogsSubscription?.cancel();
  Logger.root.level = Level.ALL;
  _desktopNyxxLogsSubscription = Logger.root.onRecord.listen((record) {
    final name = record.loggerName;
    if (!name.startsWith('CardiaKexa')) {
      return;
    }
    appendBotDebugLog(_formatNyxxLogRecord(record), botId: botId);
  });
}

void consumeForegroundTaskDataForBotLogs(Object data) {
  if (data is! Map) {
    return;
  }
  final map = Map<String, dynamic>.from(data.cast<dynamic, dynamic>());
  if (map['type'] == 'bot_lifecycle') {
    final state = map['state']?.toString();
    if (state == 'started') {
      setBotRuntimeActive(true);
      return;
    }
    if (state == 'stopped') {
      setBotRuntimeActive(false);
    }
    return;
  }

  if (map['type'] == 'bot_metrics') {
    final botId = map['botId']?.toString();
    final rssBytes = map['rssBytes'];
    final rssAsInt =
        (rssBytes is int)
            ? rssBytes
            : int.tryParse((rssBytes ?? '').toString());
    final cpuRaw = map['cpuPercent'];
    final cpuAsDouble =
        (cpuRaw is num) ? cpuRaw.toDouble() : double.tryParse('$cpuRaw');
    final storageRaw = map['storageBytes'];
    final storageAsInt =
        (storageRaw is int)
            ? storageRaw
            : int.tryParse((storageRaw ?? '').toString());
    _updateBotMetrics(
      rssBytes: rssAsInt,
      cpuPercent: cpuAsDouble,
      storageBytes: storageAsInt,
      botId: botId,
    );
    return;
  }

  if (map['type'] != 'bot_log') {
    return;
  }
  final botId = map['botId']?.toString();
  final message = map['message']?.toString();
  if (message == null || message.isEmpty) {
    return;
  }
  appendBotLog(message, botId: botId);
}

Future<void> _emitTaskLifecycleToMain(String state, {String? botId}) async {
  try {
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{
      'type': 'bot_lifecycle',
      'state': state,
      'botId': botId,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {}
}

Future<void> _emitTaskLogToMain(String message, {String? botId}) async {
  try {
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{
      'type': 'bot_log',
      'botId': botId,
      'message': message,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {}
}

Future<void> _emitTaskDebugLogToMain(String message, {String? botId}) async {
  if (!_debugBotLogsEnabled) {
    return;
  }
  await _emitTaskLogToMain('DEBUG: $message', botId: botId);
}
