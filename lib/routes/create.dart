import 'package:cardia_kexa/main.dart';
import 'package:cardia_kexa/utils/global.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

class AppCreatePage extends StatefulWidget {
  const AppCreatePage({super.key});

  @override
  State<AppCreatePage> createState() => _AppCreatePageState();
}

class _AppCreatePageState extends State<AppCreatePage> {
  String _token = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create a new App")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Create a new App"),
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
                try {
                  // Let's fetch the App first.
                  User discordUser = await getDiscordUser(_token);

                  await appManager.addApp(
                    discordUser.id.toString(),
                    discordUser.username,
                    _token,
                  );
                  Navigator.pop(context);
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
