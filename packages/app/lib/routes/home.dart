import 'dart:async';
import 'dart:io';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app.dart';
import 'package:bot_creator/routes/app/bot_logs.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:developer' as developer;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  /// ID du bot actuellement en cours d'exécution (null = aucun).
  String? _runningBotId;

  /// Vrai pendant qu'un démarrage/arrêt est en cours.
  bool _isTogglingBot = false;

  /// Un AnimationController par carte (clé = bot id) pour l'effet pulse.
  final Map<String, AnimationController> _pulseControllers = {};

  bool get _supportsForegroundTask => Platform.isAndroid || Platform.isIOS;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    AppAnalytics.logScreenView(screenName: 'HomePage', screenClass: 'HomePage');
    AppAnalytics.logEvent(name: 'home_page_opened');
    _initRunningState();
  }

  @override
  void dispose() {
    for (final ctrl in _pulseControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ── Initialisation de l'état running ───────────────────────────────────────

  Future<void> _initRunningState() async {
    String? runningId;
    if (_supportsForegroundTask) {
      try {
        final running = await FlutterForegroundTask.isRunningService;
        if (running) runningId = mobileRunningBotId;
      } on MissingPluginException {
        // Plateforme non supportée.
      }
    } else {
      if (isDesktopBotRunning) runningId = desktopRunningBotId;
    }
    if (!mounted) return;
    setState(() => _runningBotId = runningId);
    _syncPulse(runningId);
  }

  // ── Gestion des animations pulse ───────────────────────────────────────────

  AnimationController _getOrCreatePulseController(String botId) {
    return _pulseControllers.putIfAbsent(
      botId,
      () => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _syncPulse(String? runningId) {
    for (final entry in _pulseControllers.entries) {
      if (entry.key == runningId) {
        if (!entry.value.isAnimating) {
          entry.value.repeat(reverse: true);
        }
      } else {
        entry.value
          ..stop()
          ..value = 0;
      }
    }
  }

  // ── Démarrage / Arrêt du bot ───────────────────────────────────────────────

  Future<void> _toggleBot({
    required String botId,
    required String botName,
  }) async {
    if (_isTogglingBot) return;
    setState(() => _isTogglingBot = true);

    try {
      final isRunning = _runningBotId == botId;
      final app = await appManager.getApp(botId);
      final token = app['token']?.toString();
      if (token == null || token.trim().isEmpty) {
        throw Exception('Token introuvable pour $botName');
      }

      if (!isRunning) {
        clearBotBaselineRss();
        startBotLogSession(botId: botId);
        appendBotLog('Démarrage du bot demandé', botId: botId);
      }

      if (_supportsForegroundTask) {
        // ── Mobile (Android / iOS) ─────────────────────────────────────────
        if (isRunning) {
          appendBotLog('Arrêt du bot demandé', botId: botId);
          await FlutterForegroundTask.stopService();
          try {
            await FlutterForegroundTask.removeData(key: 'token');
          } catch (_) {}
          setMobileRunningBotId(null);
          setBotRuntimeActive(false);
          clearBotBaselineRss();
          if (mounted) setState(() => _runningBotId = null);
        } else {
          // Vérifier / demander la permission de notification.
          try {
            var perm =
                await FlutterForegroundTask.checkNotificationPermission();
            if (perm != NotificationPermission.granted) {
              await FlutterForegroundTask.requestNotificationPermission();
              perm = await FlutterForegroundTask.checkNotificationPermission();
              if (perm != NotificationPermission.granted) {
                throw Exception(
                  'Permission notification requise pour lancer le bot.',
                );
              }
            }
          } on MissingPluginException {
            // Continuer sans vérification sur les plateformes non supportées.
          }

          await initForegroundService();
          await FlutterForegroundTask.saveData(key: 'token', value: token);
          await startService();

          try {
            final running = await FlutterForegroundTask.isRunningService;
            if (!running) {
              throw Exception("Le service foreground n'a pas démarré.");
            }
          } on MissingPluginException {
            // Accepter sur les plateformes de dev.
          }

          setMobileRunningBotId(botId);
          if (mounted) setState(() => _runningBotId = botId);
        }
      } else {
        // ── Desktop (Linux / Windows / macOS) ─────────────────────────────
        if (isRunning) {
          appendBotLog('Arrêt du bot desktop demandé', botId: botId);
          await stopDesktopBot();
          setBotRuntimeActive(false);
          clearBotBaselineRss();
          if (mounted) setState(() => _runningBotId = null);
        } else {
          await startDesktopBot(token);
          if (mounted) setState(() => _runningBotId = botId);
        }
      }

      _syncPulse(_runningBotId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _isTogglingBot = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount;
        if (width >= 1200) {
          crossAxisCount = 4;
        } else if (width >= 900) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 2;
        }

        final horizontalPadding = width >= 900 ? 24.0 : 12.0;
        final cardHeight =
            width >= 1200 ? 340.0 : (width >= 900 ? 320.0 : 300.0);
        final cardWidth =
            (width - (horizontalPadding * 2) - ((crossAxisCount - 1) * 12)) /
            crossAxisCount;
        final childAspectRatio = cardWidth / cardHeight;

        return Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: StreamBuilder<List<dynamic>>(
            stream: appManager.getAppStream(),
            initialData: const <dynamic>[],
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                developer.log(
                  'Error loading data: ${snapshot.error}',
                  name: 'HomePage',
                );
                return const Center(child: Text('Erreur de chargement'));
              }

              final apps = snapshot.data;
              if (apps == null || apps.isEmpty) {
                return const Center(child: Text('Aucune application trouvée'));
              }

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  final name = app['name']?.toString() ?? 'Inconnu';
                  final id = app['id']?.toString() ?? '';
                  final avatar = app['avatar']?.toString();
                  final guildCount = app['guild_count'] as int?;
                  final isRunning = _runningBotId == id;
                  // On ne peut démarrer que si aucun autre bot ne tourne.
                  final canToggle =
                      !_isTogglingBot && (_runningBotId == null || isRunning);

                  final pulseCtrl = _getOrCreatePulseController(id);

                  return _BotCard(
                    name: name,
                    id: id,
                    avatar: avatar,
                    guildCount: guildCount,
                    isRunning: isRunning,
                    canToggle: canToggle,
                    isTogglingThisBot: _isTogglingBot && isRunning,
                    pulseController: pulseCtrl,
                    onManage:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => AppEditPage(
                                  appName: name,
                                  id: int.tryParse(id) ?? 0,
                                ),
                          ),
                        ),
                    onToggle: () => _toggleBot(botId: id, botName: name),
                    onLogs:
                        isRunning
                            ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BotLogsPage(),
                              ),
                            )
                            : null,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

// ── Widget carte ─────────────────────────────────────────────────────────────

class _BotCard extends StatelessWidget {
  const _BotCard({
    required this.name,
    required this.id,
    required this.avatar,
    required this.guildCount,
    required this.isRunning,
    required this.canToggle,
    required this.isTogglingThisBot,
    required this.pulseController,
    required this.onManage,
    required this.onToggle,
    required this.onLogs,
  });

  final String name;
  final String id;
  final String? avatar;
  final int? guildCount;
  final bool isRunning;
  final bool canToggle;
  final bool isTogglingThisBot;
  final AnimationController pulseController;
  final VoidCallback onManage;
  final VoidCallback onToggle;
  final VoidCallback? onLogs;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side:
            isRunning
                ? BorderSide(color: Colors.green.shade400, width: 1.5)
                : BorderSide.none,
      ),
      elevation: isRunning ? 6 : 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Avatar ──────────────────────────────────────────────────────
            avatar != null && avatar!.isNotEmpty
                ? CircleAvatar(
                  radius: 36,
                  backgroundImage: NetworkImage(avatar!),
                )
                : const Icon(Icons.account_circle, size: 72),

            const SizedBox(height: 8),

            // ── Nom ─────────────────────────────────────────────────────────
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 4),

            // ── Statut avec animation pulse ──────────────────────────────────
            AnimatedBuilder(
              animation: pulseController,
              builder: (_, _) {
                final opacity =
                    isRunning ? 0.4 + 0.6 * pulseController.value : 1.0;
                return Opacity(
                  opacity: opacity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRunning ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isRunning ? 'En ligne' : 'Hors ligne',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isRunning ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Compteur de serveurs ─────────────────────────────────────────
            if (guildCount != null && guildCount! > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups,
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$guildCount serveur${guildCount! > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],

            const Spacer(),

            // ── Bouton Lancer / Arrêter ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canToggle ? onToggle : null,
                icon:
                    isTogglingThisBot
                        ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Icon(
                          isRunning
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 16,
                        ),
                label: Text(isRunning ? 'Arrêter' : 'Lancer'),
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: isRunning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── Ligne inférieure : Gérer + Logs ──────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onManage,
                    icon: const Icon(Icons.tune, size: 14),
                    label: const Text('Gérer'),
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: onLogs,
                  icon: const Icon(Icons.article_outlined, size: 18),
                  tooltip: 'Logs du bot',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        onLogs != null
                            ? Colors.deepPurple.shade100
                            : Colors.grey.shade200,
                    foregroundColor:
                        onLogs != null ? Colors.deepPurple : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
