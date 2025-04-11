import 'package:cardia_kexa/main.dart';
import 'package:cardia_kexa/utils/global.dart';
import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';
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
  late Collection appCol;
  NyxxRest? client; // Changez en nullable
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    final app = await appManager.getApp(widget.id.toString());
    final token = app?.string("token");
    if (token != null) {
      client = await Nyxx.connectRest(token);
      setState(() {
        _isLoading = false;
      });
    }
    setState(() {
      _appName = app?.string("name") ?? widget.appName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit $_appName"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              // Handle button press

              // First we need to check if a Token is provided
              if (_token.isEmpty) {
                final dialog = AlertDialog(
                  title: const Text("Error"),
                  content: const Text("Please provide a token"),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text("OK"),
                    ),
                  ],
                );
                showDialog(context: context, builder: (context) => dialog);
                return;
              }
              try {
                // Let's fetch the App first.
                User discordUser = await getDiscordUser(_token);
                var app = await appManager.getApp(discordUser.id.toString());
                if (app != null &&
                    discordUser.id.toString() != widget.id.toString()) {
                  // let's remove this app id from the database
                  await appManager.removeApp(discordUser.id.toString());
                }
                // Now let's update the app in the database
                if (discordUser.id.toString() != widget.id.toString()) {
                  // let's remove this app id from the database
                  await appManager.removeApp(widget.id.toString());
                  await appManager.addApp(
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
                  appManager.updateApp(
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
                        Navigator.of(context).pop();
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
                        Navigator.of(context).pop();
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
                    height: 180,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Settings"),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            // Handle button press
                            try {
                              // Let's fetch the App first.
                              final app = await appManager.getApp(
                                widget.id.toString(),
                              );
                              if (app == null) {
                                throw Exception("App not found");
                              }

                              final token = app.string("token");
                              if (token == null) {
                                throw Exception("Token not found");
                              }
                              // Perform any additional actions with the fetched app
                              User discordUser = await getDiscordUser(token);

                              _appName = discordUser.username;
                              appManager.updateApp(
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
                          child: const Text("Sync App"),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              178,
                              45,
                              35,
                            ),
                          ),
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
                                    await appManager.removeApp(
                                      widget.id.toString(),
                                    );
                                    Navigator.of(context).pop();
                                    Navigator.pop(context);
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
                          child: const Text("Delete"),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Text("Update the token of ($_appName)"),
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
            const SizedBox(height: 20),
            const Text(
              "Commands",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              FutureBuilder(
                future: client?.commands.list(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  } else {
                    final commands = snapshot.data;
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: commands?.length ?? 0,
                      itemBuilder: (context, index) {
                        return ListTile(
                          trailing: const Icon(
                            Icons.arrow_forward_ios_outlined,
                          ),
                          title: Text(commands![index].name),
                          subtitle: Text(commands[index].description),
                          onTap: () {
                            // Handle command tap
                            final dialog = AlertDialog(
                              title: const Text("Command Details"),
                              content: Text(
                                "Name: ${commands[index].name}\nDescription: ${commands[index].description}",
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
                          },
                        );
                      },
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
