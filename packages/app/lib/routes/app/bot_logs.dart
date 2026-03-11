import 'package:bot_creator/utils/bot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BotLogsPage extends StatefulWidget {
  const BotLogsPage({super.key});

  @override
  State<BotLogsPage> createState() => _BotLogsPageState();
}

class _BotLogsPageState extends State<BotLogsPage> {
  late bool _debugEnabled;
  final Set<String> _expandedLogs = <String>{};
  final ScrollController _scrollController = ScrollController();
  bool _showNewestFirst = true;
  int _visibleLimit = 200;

  static const int _collapseThreshold = 240;

  @override
  void initState() {
    super.initState();
    _debugEnabled = isBotDebugLogsEnabled;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToEdge() {
    if (!_scrollController.hasClients) {
      return;
    }

    final target =
        _showNewestFirst
            ? _scrollController.position.minScrollExtent
            : _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bot Logs'),
        actions: [
          IconButton(
            tooltip:
                _debugEnabled ? 'Désactiver debug logs' : 'Activer debug logs',
            icon: Icon(
              _debugEnabled ? Icons.bug_report : Icons.bug_report_outlined,
            ),
            onPressed: () {
              setState(() {
                _debugEnabled = !_debugEnabled;
                setBotDebugLogsEnabled(_debugEnabled);
              });
            },
          ),
          IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final logs = getBotLogsSnapshot();
              await Clipboard.setData(ClipboardData(text: logs.join('\n')));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Logs copiés')));
              }
            },
          ),
          IconButton(
            tooltip:
                _showNewestFirst
                    ? 'Afficher les plus anciens en premier'
                    : 'Afficher les plus récents en premier',
            icon: Icon(
              _showNewestFirst
                  ? Icons.vertical_align_top
                  : Icons.vertical_align_bottom,
            ),
            onPressed: () {
              setState(() {
                _showNewestFirst = !_showNewestFirst;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _jumpToEdge();
              });
            },
          ),
          PopupMenuButton<int>(
            tooltip: 'Nombre de logs affichés',
            icon: const Icon(Icons.filter_list),
            initialValue: _visibleLimit,
            onSelected: (value) {
              setState(() {
                _visibleLimit = value;
              });
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(value: 100, child: Text('Afficher 100 logs')),
                  PopupMenuItem(value: 200, child: Text('Afficher 200 logs')),
                  PopupMenuItem(value: 500, child: Text('Afficher 500 logs')),
                  PopupMenuItem(value: 0, child: Text('Afficher tout')),
                ],
          ),
        ],
      ),
      body: StreamBuilder<int?>(
        stream: getBotProcessRssStream(),
        initialData: getBotProcessRssBytes(),
        builder: (context, metricsSnapshot) {
          final memoryText = _formatMemory(metricsSnapshot.data);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.memory, size: 18),
                      const SizedBox(width: 8),
                      Text('RAM process bot: $memoryText'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<String>>(
                  stream: getBotLogsStream(),
                  initialData: getBotLogsSnapshot(),
                  builder: (context, snapshot) {
                    final allLogs = snapshot.data ?? const <String>[];
                    if (allLogs.isEmpty) {
                      return const Center(
                        child: Text('Aucun log pour le moment'),
                      );
                    }

                    final sourceLogs =
                        (_visibleLimit > 0 && allLogs.length > _visibleLimit)
                            ? allLogs.sublist(allLogs.length - _visibleLimit)
                            : allLogs;

                    final logs =
                        _showNewestFirst
                            ? sourceLogs.reversed.toList(growable: false)
                            : sourceLogs;

                    final textTheme = Theme.of(context).textTheme;
                    final bottomInset = MediaQuery.of(context).padding.bottom;

                    return ListView.separated(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        12,
                        12,
                        12,
                        16 + bottomInset + 64,
                      ),
                      itemCount: logs.length,
                      separatorBuilder:
                          (BuildContext context, int index) =>
                              const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final raw = logs[index];
                        final parsed = _parseLog(raw);
                        final displayMessage = _formatMessageForDisplay(
                          parsed.message,
                        );
                        final isExpanded = _expandedLogs.contains(raw);
                        final shouldCollapse =
                            displayMessage.length > _collapseThreshold;
                        final visibleMessage =
                            shouldCollapse && !isExpanded
                                ? '${displayMessage.substring(0, _collapseThreshold)}…'
                                : displayMessage;

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _Badge(
                                    text: parsed.time,
                                    background:
                                        Theme.of(context).colorScheme.surface,
                                    foreground:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 8),
                                  _Badge(
                                    text: parsed.level,
                                    background: _levelBackground(
                                      context,
                                      parsed.level,
                                      parsed.isDebug,
                                    ),
                                    foreground: _levelForeground(
                                      context,
                                      parsed.level,
                                      parsed.isDebug,
                                    ),
                                  ),
                                  if (parsed.logger.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        parsed.logger,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.labelMedium,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                visibleMessage,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  height: 1.35,
                                ),
                              ),
                              if (shouldCollapse)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedLogs.remove(raw);
                                        } else {
                                          _expandedLogs.add(raw);
                                        }
                                      });
                                    },
                                    icon: Icon(
                                      isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                    ),
                                    label: Text(
                                      isExpanded
                                          ? 'Afficher moins'
                                          : 'Afficher plus',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: _showNewestFirst ? 'Aller au dernier log' : 'Aller au bas',
        onPressed: _jumpToEdge,
        child: Icon(
          _showNewestFirst
              ? Icons.vertical_align_top
              : Icons.vertical_align_bottom,
        ),
      ),
    );
  }

  String _formatMemory(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return 'N/A';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  _ParsedLog _parseLog(String raw) {
    final source = _stripAnsi(raw).trimLeft();
    final timeMatch = RegExp(
      r'\[\s*(\d{1,2})\s*:\s*(\d{2})\s*:\s*(\d{2})(?:\s*\.\s*\d+)?\s*\]',
    ).firstMatch(source);
    if (timeMatch == null) {
      return _ParsedLog(
        time: '--:--:--',
        level: 'LOG',
        logger: '',
        message: source,
        isDebug: false,
      );
    }

    final hours = (timeMatch.group(1) ?? '--').padLeft(2, '0');
    final minutes = timeMatch.group(2) ?? '--';
    final seconds = timeMatch.group(3) ?? '--';
    final time = '$hours:$minutes:$seconds';
    var rest = source.substring(timeMatch.end).trimLeft();

    final isDebug = RegExp(r'^DEBUG\s*:', caseSensitive: false).hasMatch(rest);
    if (isDebug) {
      rest = rest.replaceFirst(RegExp(r'^DEBUG\s*:', caseSensitive: false), '');
      rest = rest.trimLeft();
    }

    var cursor = 0;
    while (cursor < rest.length && rest[cursor] == ' ') {
      cursor++;
    }

    final levelToken = _readBracketToken(rest, cursor);
    if (levelToken != null) {
      cursor = levelToken.end;
      while (cursor < rest.length && rest[cursor] == ' ') {
        cursor++;
      }

      final loggerToken = _readBracketToken(rest, cursor);
      if (loggerToken != null) {
        cursor = loggerToken.end;
        while (cursor < rest.length && rest[cursor] == ' ') {
          cursor++;
        }

        return _ParsedLog(
          time: time,
          level: levelToken.value.trim(),
          logger: loggerToken.value.trim(),
          message: rest.substring(cursor),
          isDebug: isDebug,
        );
      }

      return _ParsedLog(
        time: time,
        level: levelToken.value.trim(),
        logger: '',
        message: rest.substring(cursor).trimLeft(),
        isDebug: isDebug,
      );
    }

    return _ParsedLog(
      time: time,
      level: isDebug ? 'DEBUG' : 'LOG',
      logger: '',
      message: rest,
      isDebug: isDebug,
    );
  }

  String _stripAnsi(String input) {
    return input.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
  }

  _BracketToken? _readBracketToken(String source, int start) {
    if (start < 0 || start >= source.length || source[start] != '[') {
      return null;
    }

    final token = StringBuffer();
    var depth = 0;

    for (var index = start; index < source.length; index++) {
      final char = source[index];

      if (char == '[') {
        if (depth > 0) {
          token.write(char);
        }
        depth++;
        continue;
      }

      if (char == ']') {
        depth--;
        if (depth == 0) {
          return _BracketToken(value: token.toString(), end: index + 1);
        }
        if (depth < 0) {
          return null;
        }
        token.write(char);
        continue;
      }

      if (depth > 0) {
        token.write(char);
      }
    }

    return null;
  }

  String _formatMessageForDisplay(String message) {
    if (message.length < 40) {
      return message;
    }

    final firstOpenBrace = message.indexOf('{');
    final lastCloseBrace = message.lastIndexOf('}');
    if (firstOpenBrace == -1 ||
        lastCloseBrace == -1 ||
        lastCloseBrace <= firstOpenBrace) {
      return message;
    }

    final prefix = message.substring(0, firstOpenBrace).trimRight();
    final structured = message.substring(firstOpenBrace, lastCloseBrace + 1);
    final suffix = message.substring(lastCloseBrace + 1).trimLeft();

    final prettyStructured = _prettyStructuredText(structured);
    final parts = <String>[];
    if (prefix.isNotEmpty) {
      parts.add(prefix);
    }
    parts.add(prettyStructured);
    if (suffix.isNotEmpty) {
      parts.add(suffix);
    }

    return parts.join('\n');
  }

  String _prettyStructuredText(String input) {
    final out = StringBuffer();
    var indent = 0;
    var inSingleQuote = false;
    var inDoubleQuote = false;
    var escaping = false;

    void writeIndent() {
      out.write('  ' * indent);
    }

    for (var index = 0; index < input.length; index++) {
      final char = input[index];

      if (escaping) {
        out.write(char);
        escaping = false;
        continue;
      }

      if (char == r'\') {
        out.write(char);
        escaping = true;
        continue;
      }

      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        out.write(char);
        continue;
      }

      if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        out.write(char);
        continue;
      }

      if (inSingleQuote || inDoubleQuote) {
        out.write(char);
        continue;
      }

      if (char == '{' || char == '[') {
        out.write(char);
        indent++;
        out.write('\n');
        writeIndent();
        continue;
      }

      if (char == '}' || char == ']') {
        if (indent > 0) {
          indent--;
        }

        final current = out.toString();
        if (!current.endsWith('\n')) {
          out.write('\n');
        }
        writeIndent();
        out.write(char);
        continue;
      }

      if (char == ',') {
        out.write(char);
        out.write('\n');
        writeIndent();
        continue;
      }

      out.write(char);
    }

    return out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  Color _levelBackground(BuildContext context, String level, bool isDebug) {
    final scheme = Theme.of(context).colorScheme;
    final upper = level.toUpperCase();
    if (upper == 'SEVERE' || upper == 'ERROR') {
      return scheme.errorContainer;
    }
    if (upper == 'WARNING' || upper == 'WARN') {
      return scheme.tertiaryContainer;
    }
    if (upper == 'INFO') {
      return scheme.primaryContainer;
    }
    if (isDebug || upper == 'FINE' || upper == 'FINER' || upper == 'FINEST') {
      return scheme.secondaryContainer;
    }
    return scheme.surfaceContainerHighest;
  }

  Color _levelForeground(BuildContext context, String level, bool isDebug) {
    final scheme = Theme.of(context).colorScheme;
    final upper = level.toUpperCase();
    if (upper == 'SEVERE' || upper == 'ERROR') {
      return scheme.onErrorContainer;
    }
    if (upper == 'WARNING' || upper == 'WARN') {
      return scheme.onTertiaryContainer;
    }
    if (upper == 'INFO') {
      return scheme.onPrimaryContainer;
    }
    if (isDebug || upper == 'FINE' || upper == 'FINER' || upper == 'FINEST') {
      return scheme.onSecondaryContainer;
    }
    return scheme.onSurfaceVariant;
  }
}

class _ParsedLog {
  const _ParsedLog({
    required this.time,
    required this.level,
    required this.logger,
    required this.message,
    required this.isDebug,
  });

  final String time;
  final String level;
  final String logger;
  final String message;
  final bool isDebug;
}

class _BracketToken {
  const _BracketToken({required this.value, required this.end});

  final String value;
  final int end;
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
