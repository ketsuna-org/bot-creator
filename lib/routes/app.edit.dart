import 'dart:io';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/command.create.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:nyxx/nyxx.dart';

class AppEditPage extends StatefulWidget {
  final String appName;
  final int id;
  const AppEditPage({super.key, required this.appName, required this.id});

  @override
  State<AppEditPage> createState() => _AppEditPageState();
}

class _AppEditPageState extends State<AppEditPage>
    with TickerProviderStateMixin {
  String _token = "";
  String _appName = "";
  NyxxRest? client; // Changez en nullable
  bool _isLoading = true;
  bool _editMode = false;
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
    final app = await appManager.getApp(widget.id.toString());
    final token = app["token"];
    if (token != null) {
      client = await Nyxx.connectRest(token);
      setState(() {
        _isLoading = false;
      });
    }

    final isRunning = await FlutterForegroundTask.isRunningService;
    setState(() {
      _botLaunched = isRunning;
      _appName = app["name"] ?? widget.appName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
        actions: [
          IconButton(
            icon: _editMode ? const Icon(Icons.check) : const Icon(Icons.edit),
            onPressed: () async {
              if (_editMode == false) {
                setState(() {
                  _editMode = true;
                });
                return;
              }
              // Handle button press

              // First we need to check if a Token is provided
              if (_token.isEmpty) {
                setState(() {
                  _editMode = false;
                });
                return;
              }
              try {
                // Let's fetch the App first.
                User discordUser = await getDiscordUser(_token);
                if (discordUser.id.toString() != widget.id.toString()) {
                  // let's remove this app id from the database
                  await appManager.deleteApp(discordUser.id.toString());
                }
                // Now let's update the app in the database
                if (discordUser.id.toString() != widget.id.toString()) {
                  // let's remove this app id from the database
                  await appManager.deleteApp(widget.id.toString());
                  await appManager.createOrUpdateApp(
                    discordUser.id.toString(),
                    discordUser.username,
                    _token,
                  );
                  setState(() {
                    _appName = discordUser.username;
                    _token = _token;
                  });
                  return;
                } else {
                  appManager.createOrUpdateApp(
                    discordUser.id.toString(),
                    discordUser.username.toString(),
                    _token,
                  );
                }
                // Let's show the Username found
                final dialog = AlertDialog(
                  title: const Text("Success"),
                  content: Text("Username found: ${discordUser.username}"),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("OK"),
                    ),
                  ],
                );
                showDialog(context: context, builder: (context) => dialog);
              } catch (e) {
                // Handle error
                final errorText = e.toString();
                final dialog = AlertDialog(
                  title: const Text("Error"),
                  content: Text(errorText),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("OK"),
                    ),
                  ],
                );

                showDialog(context: context, builder: (context) => dialog);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              final bottomSheet = BottomSheet(
                onClosing: () => {},
                showDragHandle: true,
                animationController: BottomSheet.createAnimationController(
                  this,
                  sheetAnimationStyle: AnimationStyle(
                    curve: Curves.easeInOut,
                    duration: const Duration(milliseconds: 300),
                  ),
                ),
                enableDrag: true,
                builder: (context) {
                  return SizedBox(
                    height: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Column(
                          children: [
                            IconButton(
                              onPressed: () async {
                                // Handle button press
                                try {
                                  // Let's fetch the App first.
                                  final app = await appManager.getApp(
                                    widget.id.toString(),
                                  );

                                  final token = app["token"];
                                  if (token == null) {
                                    throw Exception("Token not found");
                                  }
                                  // Perform any additional actions with the fetched app
                                  User discordUser = await getDiscordUser(
                                    token,
                                  );

                                  _appName = discordUser.username;
                                  appManager.createOrUpdateApp(
                                    discordUser.id.toString(),
                                    discordUser.username,
                                    token,
                                  );

                                  // let's show that the Sync was successful
                                  final dialog = AlertDialog(
                                    title: const Text("Success"),
                                    content: Text(
                                      "Sync successful: ${discordUser.username}",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text("OK"),
                                      ),
                                    ],
                                  );
                                  showDialog(
                                    context: context,
                                    builder: (context) => dialog,
                                  );
                                } catch (e) {
                                  // Handle error
                                  final errorText = e.toString();
                                  final dialog = AlertDialog(
                                    title: const Text("Error"),
                                    content: Text(errorText),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text("OK"),
                                      ),
                                    ],
                                  );

                                  showDialog(
                                    context: context,
                                    builder: (context) => dialog,
                                  );
                                }
                              },
                              icon: const Icon(Icons.sync),
                              style: IconButton.styleFrom(iconSize: 40),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Sync",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 40),
                        Column(
                          children: [
                            IconButton(
                              onPressed: () {
                                final finalDialog = AlertDialog(
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
                                        // Handle delete action
                                        await appManager.deleteApp(
                                          widget.id.toString(),
                                        );
                                        Navigator.of(context).pop();
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        }
                                      },
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                );
                                Navigator.of(context).pop();
                                showDialog(
                                  context: context,
                                  builder: (context) => finalDialog,
                                );
                              },
                              icon: const Icon(Icons.delete),
                              style: IconButton.styleFrom(
                                iconSize: 40,
                                backgroundColor: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Delete",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );

              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return bottomSheet;
                },
                isScrollControlled: true,
                isDismissible: true,
                sheetAnimationStyle: AnimationStyle(
                  curve: Curves.easeInOut,
                  duration: const Duration(milliseconds: 300),
                ),
              );
            },
          ),
        ],
      ),
      body: Scrollable(
        controller: ScrollController(),
        viewportBuilder:
            (context, position) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Edit $_appName",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_editMode)
                      Column(
                        children: [
                          Text("Edit the token of ($_appName)"),
                          const SizedBox(height: 20),
                          TextField(
                            decoration: InputDecoration(
                              labelText: "Token App Name",
                              border: OutlineInputBorder(),
                            ),
                            onChanged:
                                (value) => setState(() {
                                  _token = value;
                                }),
                          ),
                        ],
                      )
                    else
                      const SizedBox(),
                    const SizedBox(height: 20),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor:
                            _botLaunched ? Colors.red : Colors.green,
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: () async {
                        if (_botLaunched) {
                          setState(() {
                            _botLaunched = false;
                          });
                          await FlutterForegroundTask.stopService();
                          await FlutterForegroundTask.removeData(key: "token");
                          return;
                        }
                        final app = await appManager.getApp(
                          widget.id.toString(),
                        );

                        final token = app["token"];
                        if (token == null) {
                          throw Exception("Token not found");
                        }
                        print("Token: $token");
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
                      child: Text(
                        _botLaunched ? "Stop Bot" : "Start Bot",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(
                      height: 40,
                      thickness: 2,
                      indent: 20,
                      endIndent: 20,
                    ),
                    Column(
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          "Commands",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isLoading)
                          const CircularProgressIndicator()
                        else
                          FutureBuilder(
                            future: getCommands(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const CircularProgressIndicator(
                                  strokeAlign: 0.5,
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue,
                                  ),
                                );
                              } else if (snapshot.hasError) {
                                return Text("Error: ${snapshot.error}");
                              } else {
                                final commands = snapshot.data;

                                if (commands!.isEmpty) {
                                  return const Text("No commands found");
                                }
                                return ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: commands.length,
                                  scrollDirection: Axis.vertical,
                                  controller: ScrollController(),
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios_outlined,
                                      ),
                                      title: Text(
                                        commands[index].name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        commands[index].description,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      onTap: () {
                                        // Handle command tap
                                        final command = commands[index];
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => CommandCreatePage(
                                                  client: client!,
                                                  id: command.id,
                                                ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      ),
      floatingActionButton:
          !_isLoading
              ? FloatingActionButton.extended(
                onPressed:
                    () => {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => CommandCreatePage(client: client!),
                        ),
                      ),
                    },
                label: Text("Create Command"),
                icon: const Icon(Icons.add),
              )
              : null,
    );
  }
}
