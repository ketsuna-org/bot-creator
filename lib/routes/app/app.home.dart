import 'dart:io';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:nyxx/nyxx.dart';

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
  bool _botLaunched = false;

  Future<void> _requestPermissions() async {
    // Android 13+, you need to allow notification permission to display foreground service notification.
    //
    // iOS: If you need notification, ask for permission.
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      // Android 12+, there are restrictions on starting a foreground service.
      //
      // To restart the service on device reboot or unexpected problem, you need to allow below permission.
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        // This function requires `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission.
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  Future<void> _initService() async {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Request permissions and initialize the service.
      _requestPermissions();
      _initService();
    });
    _init();
  }

  Future<List<ApplicationCommand>> getCommands() async {
    if (client == null) {
      throw Exception("Client is not initialized");
    }
    final commands = await client!.commands.list();
    return commands;
  }

  _init() async {
    final app = await appManager.getApp(widget.client.user.id.toString());
    final isRunning = await FlutterForegroundTask.isRunningService;
    await analytics.logScreenView(
      screenName: "AppHomePage",
      screenClass: "AppHomePage",
      parameters: {
        "app_name": app["name"],
        "app_id": widget.client.user.id.toString(),
        "is_running": isRunning,
      },
    );
    setState(() {
      _botLaunched = isRunning;
      _appName = app["name"];
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
      body: Center(
        child: Scrollable(
          controller: ScrollController(),
          viewportBuilder:
              (context, position) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 80),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _botLaunched ? Colors.red : Colors.green,
                          maximumSize: const Size(200, 40),
                        ),
                        onPressed: () async {
                          if (_botLaunched) {
                            setState(() {
                              _botLaunched = false;
                            });
                            await FlutterForegroundTask.stopService();
                            await FlutterForegroundTask.removeData(
                              key: "token",
                            );
                            return;
                          }
                          final app = await appManager.getApp(
                            widget.client.user.id.toString(),
                          );

                          final token = app["token"];
                          if (token == null) {
                            throw Exception("Token not found");
                          }
                          await FlutterForegroundTask.saveData(
                            key: "token",
                            value: token,
                          );
                          await Future.delayed(const Duration(seconds: 1));
                          await startService();

                          setState(() {
                            _botLaunched = true;
                          });
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
                          maximumSize: const Size(200, 40),
                        ),
                        onPressed: () async {
                          final user = await widget.client.user.get();
                          final app = await appManager.getApp(
                            user.id.toString(),
                          );
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
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          maximumSize: const Size(200, 40),
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
        ),
      ),
    );
  }
}
