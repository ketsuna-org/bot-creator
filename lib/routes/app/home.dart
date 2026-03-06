import 'dart:io';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/bot_logs.dart';
import 'package:bot_creator/routes/app/bot_stats.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'package:nyxx/nyxx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

class AppHomePage extends StatefulWidget {
  final NyxxRest client;
  const AppHomePage({super.key, required this.client});

  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage>
    with TickerProviderStateMixin {
  String _appName = "";
  NyxxRest? client; // Changez en nullable
  String avatar = "";
  bool _botLaunched = false;
  void Function(Object)? _taskDataCallback;

  bool get _supportsForegroundTask => Platform.isAndroid || Platform.isIOS;

  Future<void> _requestPermissions() async {
    if (!_supportsForegroundTask) {
      return;
    }

    // Android 13+, you need to allow notification permission to display foreground service notification.
    //
    // iOS: If you need notification, ask for permission.
    try {
      final NotificationPermission notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      if (Platform.isAndroid) {
        if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }
      }
    } on MissingPluginException {
      // No-op on unsupported platforms.
    }
  }

  Future<void> _initService() async {
    if (!_supportsForegroundTask) {
      return;
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription:
            'This notification appears when the foreground service is running.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (_supportsForegroundTask) {
      _taskDataCallback = (Object data) {
        consumeForegroundTaskDataForBotLogs(data);
        if (mounted) {
          setState(() {});
        }
      };
      try {
        FlutterForegroundTask.addTaskDataCallback(_taskDataCallback!);
      } on MissingPluginException {
        debugPrint('Foreground callback registration unavailable on platform');
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Request permissions and initialize the service.
      _requestPermissions();
      _initService();
    });
    _init();
  }

  @override
  void dispose() {
    final callback = _taskDataCallback;
    if (callback != null) {
      try {
        FlutterForegroundTask.removeTaskDataCallback(callback);
      } on MissingPluginException {
        debugPrint('Foreground callback removal unavailable on platform');
      }
    }
    super.dispose();
  }

  Future<List<ApplicationCommand>> getCommands() async {
    if (client == null) {
      throw Exception("Client is not initialized");
    }
    final commands = await client!.commands.list();
    return commands;
  }

  Future<void> _init() async {
    final app = await appManager.getApp(widget.client.user.id.toString());
    var isRunning = false;
    if (_supportsForegroundTask) {
      try {
        isRunning = await FlutterForegroundTask.isRunningService;
      } on MissingPluginException {
        isRunning = false;
      }
    } else {
      isRunning = isDesktopBotRunning;
    }

    await AppAnalytics.logScreenView(
      screenName: "AppHomePage",
      screenClass: "AppHomePage",
      parameters: {
        "app_name": app["name"],
        "app_id": widget.client.user.id.toString(),
        "is_running": isRunning ? "true" : "false",
      },
    );
    setState(() {
      _botLaunched = isRunning;
      _appName = app["name"];
      avatar = app["avatar"] ?? "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
        title: Text(_appName),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentMaxWidth = constraints.maxWidth >= 900 ? 560.0 : 460.0;
          return Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // let's show the app icon
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.center,
                      child:
                          avatar.isNotEmpty
                              ? CircleAvatar(
                                radius: 40,
                                backgroundImage: NetworkImage(avatar),
                              )
                              : const Icon(Icons.account_circle, size: 80),
                    ),
                    const SizedBox(height: 20),
                    // App Name
                    Text(
                      _appName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _botLaunched ? Colors.red : Colors.green,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () async {
                        try {
                          final app = await appManager.getApp(
                            widget.client.user.id.toString(),
                          );

                          final token = app["token"]?.toString();
                          if (token == null || token.trim().isEmpty) {
                            throw Exception("Token not found");
                          }

                          final botId = widget.client.user.id.toString();
                          if (!_botLaunched) {
                            clearBotBaselineRss();
                            startBotLogSession(botId: botId);
                            appendBotLog(
                              'Démarrage du bot demandé',
                              botId: botId,
                            );
                          }

                          if (_supportsForegroundTask) {
                            await _requestPermissions();
                            await _initService();

                            final notificationPermission =
                                await FlutterForegroundTask.checkNotificationPermission();
                            if (notificationPermission !=
                                NotificationPermission.granted) {
                              throw Exception(
                                'Notification permission is required to start the bot service.',
                              );
                            }

                            if (_botLaunched) {
                              appendBotLog(
                                'Arrêt du bot demandé',
                                botId: botId,
                              );
                              await FlutterForegroundTask.stopService();
                              await FlutterForegroundTask.removeData(
                                key: "token",
                              );
                              setBotRuntimeActive(false);
                              clearBotBaselineRss();
                              if (mounted) {
                                setState(() {
                                  _botLaunched = false;
                                });
                              }
                              return;
                            }

                            await FlutterForegroundTask.saveData(
                              key: "token",
                              value: token,
                            );
                            developer.log(
                              'Token saved, starting foreground service',
                              name: 'AppHomePage',
                            );
                            await startService();

                            final running =
                                await FlutterForegroundTask.isRunningService;
                            if (!running) {
                              throw Exception(
                                'Foreground service did not start.',
                              );
                            }
                          } else {
                            if (_botLaunched) {
                              appendBotLog(
                                'Arrêt du bot desktop demandé',
                                botId: botId,
                              );
                              await stopDesktopBot();
                              setBotRuntimeActive(false);
                              clearBotBaselineRss();
                              if (mounted) {
                                setState(() {
                                  _botLaunched = false;
                                });
                              }
                              return;
                            }

                            await startDesktopBot(token);
                          }

                          if (mounted) {
                            setState(() {
                              _botLaunched = true;
                            });
                          }
                        } catch (e) {
                          if (!mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Impossible de démarrer: $e'),
                            ),
                          );
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_botLaunched ? Icons.stop : Icons.play_arrow),
                          const SizedBox(width: 8),
                          Text(_botLaunched ? "Stop Bot" : "Start Bot"),
                        ],
                      ),
                    ),
                    const Divider(
                      height: 40,
                      thickness: 2,
                      indent: 20,
                      endIndent: 20,
                    ),
                    // Sync Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BotLogsPage(),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long),
                          SizedBox(width: 8),
                          Text('Voir les logs du bot'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BotStatsPage(),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.monitor_heart_outlined),
                          SizedBox(width: 8),
                          Text('Voir les stats du bot'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () async {
                        final user = await widget.client.user.get();
                        final app = await appManager.getApp(user.id.toString());
                        final token = app["token"];
                        if (token == null) {
                          throw Exception("Token not found");
                        }
                        // let's update the user
                        await appManager.createOrUpdateApp(user, token);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("App synced successfully"),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sync),
                          SizedBox(width: 8),
                          Text("Sync App"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Invite Bot Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () async {
                        final botId = widget.client.user.id.toString();
                        final inviteUrl = Uri.parse(
                          'https://discord.com/api/oauth2/authorize?client_id=$botId&scope=bot&permissions=8',
                        );

                        if (await canLaunchUrl(inviteUrl)) {
                          await launchUrl(inviteUrl);
                          await AppAnalytics.logEvent(
                            name: "invite_bot",
                            parameters: {"bot_id": botId},
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Could not open invite link"),
                            ),
                          );
                        }
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add),
                          SizedBox(width: 8),
                          Text("Invite Bot"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () async {
                        final dialog = AlertDialog.adaptive(
                          title: const Text("Delete App"),
                          content: const Text(
                            "Are you sure you want to delete this app?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () async {
                                await appManager.deleteApp(
                                  widget.client.user.id.toString(),
                                );
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                              },
                              child: const Text("Delete"),
                            ),
                          ],
                        );
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return dialog;
                          },
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete),
                          SizedBox(width: 8),
                          Text("Delete App"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
