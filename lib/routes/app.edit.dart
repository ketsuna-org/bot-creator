import 'package:cardia_kexa/main.dart';
import 'package:cardia_kexa/models/discord.dart';
import 'package:cardia_kexa/utils/global.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    // Fetch the app data from the database
    final app = await db.getApp(widget.id);
    setState(() {
      _appName = app.name;
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
            onPressed: () {
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
                  final app = await db.getApp(widget.id);
                  // Perform any additional actions with the fetched app
                  DiscordUser discordUser = await getDiscordUser(app.token);
                  await db.updateApp(
                    widget.id,
                    name: discordUser.username ?? "Unknown Name",
                    token: _token,
                  );
                  setState(() {
                    _appName = discordUser.username ?? "Unknown Name";
                    _token = _token;
                  });
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
                  DiscordUser discordUser = await getDiscordUser(_token);
                  await db.updateApp(
                    widget.id,
                    name: discordUser.username ?? "Unknown Name",
                    token: _token,
                  );
                  setState(() {
                    _appName = discordUser.username ?? "Unknown Name";
                    _token = _token;
                  });
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
