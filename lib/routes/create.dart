import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

class AppCreatePage extends StatefulWidget {
  const AppCreatePage({super.key});

  @override
  State<AppCreatePage> createState() => _AppCreatePageState();
}

class _AppCreatePageState extends State<AppCreatePage> {
  String _token = "";
  @override
  void initState() {
    super.initState();
    // Log the opening of the create app page
    AppAnalytics.logScreenView(
      screenName: "AppCreatePage",
      screenClass: "AppCreatePage",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create a new App")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: () async {
                // open link in browser
                final url = Uri.parse(
                  "https://discord.com/developers/applications",
                );

                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  throw 'Could not launch $url';
                }
              },
              child: Text(
                "Create a new App",
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                // open link in browser
                final url = Uri.parse(
                  "https://jeremysoler.com/tutorials/2025/05/18/how-to-create-a-bot-token-bot-creator.html",
                );

                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  throw 'Could not launch $url';
                }
              },
              child: const Text("How to create a Bot Token?"),
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: "Bot Token",
                border: OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(8),
                hintText: "Enter your bot token here",
              ),
              onChanged:
                  (value) => setState(() {
                    _token = value;
                  }),
            ),
            const SizedBox(height: 20),
            const Text(
              "Note: You need to create a new App in the Discord Developer Portal and get your bot token.",
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Let's fetch the App first.
                  User discordUser = await getDiscordUser(_token);

                  await appManager.createOrUpdateApp(discordUser, _token);
                  await AppAnalytics.logEvent(
                    name: "create_app",
                    parameters: {
                      "app_name": discordUser.username as Object,
                      "app_id": discordUser.id.toString() as Object,
                    },
                  );
                  Navigator.pop(context);
                } catch (e) {
                  // Handle error
                  developer.log(
                    "Error creating app: $e",
                    name: "AppCreatePage",
                  );
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
                    builder: (BuildContext context) {
                      return dialog;
                    },
                  );
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
