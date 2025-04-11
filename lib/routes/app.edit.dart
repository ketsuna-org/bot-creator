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

class _AppEditPageState extends State<AppEditPage> {
  String _token = "";
  String _appName = "";
  late Collection appCol;
  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    final app = await appManager.getApp(widget.id.toString());
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
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await appManager.removeApp(widget.id.toString());
              // Handle save action
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Edit $_appName"),
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
            ElevatedButton(
              onPressed: () async {
                // Handle button press
                try {
                  // Let's fetch the App first.
                  final app = await appManager.getApp(widget.id.toString());
                  if (app == null) {
                    throw Exception("App not found");
                  }
                  // Perform any additional actions with the fetched app
                  User discordUser = await getDiscordUser(
                    app.string("token") ?? _token,
                  );

                  appManager.updateApp(
                    discordUser.id.toString(),
                    discordUser.username,
                    _token,
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

                  showDialog(context: context, builder: (context) => dialog);
                }
              },
              child: const Text("Sync App"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Handle button press
                try {
                  // Let's fetch the App first.
                  User discordUser = await getDiscordUser(_token);
                  var app = await appManager.getApp(discordUser.id.toString());
                  if (app != null) {
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
                      _appName = discordUser.username ?? "Unknown Name";
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
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
