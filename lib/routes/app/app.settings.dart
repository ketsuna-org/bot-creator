import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';
import 'dart:developer' as developer;

class AppSettingsPage extends StatefulWidget {
  final NyxxRest client;
  const AppSettingsPage({super.key, required this.client});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  String _token = "";
  Application? app;
  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    final app = await widget.client.applications.fetchCurrentApplication();
    setState(() {
      this.app = app;
    });
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> flagsMap = {
      'Application Command Badge':
          app?.flags.hasApplicationCommandBadge ?? false,
      'Guild Member Intents': app?.flags.hasGatewayGuildMembers ?? false,
      'Guild Member Intents Limited':
          app?.flags.hasGatewayGuildMembersLimited ?? false,
      'Message Content Intents': app?.flags.hasGatewayMessageContent ?? false,
      'Message Content Intents Limited':
          app?.flags.hasGatewayMessageContentLimited ?? false,
      'Presence Intents': app?.flags.hasGatewayPresence ?? false,
      'Presence Intents Limited': app?.flags.hasGatewayPresenceLimited ?? false,
      'Embedded App': app?.flags.isEmbedded ?? false,
      'Verification Pending Guild Limit':
          app?.flags.isVerificationPendingGuildLimit ?? false,
      'Auto Moderation Rule Create Badge':
          app?.flags.usesApplicationAutoModerationRuleCreateBadge ?? false,
      'Hash Code': app?.flags.hashCode ?? 0,
    };

    return Scaffold(
      appBar: AppBar(title: Text("Application Settings")),
      body: Scrollable(
        controller: ScrollController(),
        viewportBuilder:
            (context, position) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: ScrollController(),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 20),
                    if (app != null)
                      ListView.separated(
                        shrinkWrap: true, // ← limite la hauteur
                        physics:
                            const NeverScrollableScrollPhysics(), // ← désactive son propre scroll
                        itemCount: flagsMap.length,
                        itemBuilder: (context, index) {
                          final flagName = flagsMap.keys.elementAt(index);
                          final flagValue = flagsMap[flagName];

                          if (flagName == 'Hash Code') {
                            // ← même casse que dans la map
                            return ListTile(
                              title: Text(flagName),
                              trailing: Text(flagValue.toString()),
                            );
                          }

                          return CheckboxListTile(
                            title: Text(flagName),
                            value: flagValue,
                            onChanged: null,
                            controlAffinity: ListTileControlAffinity.trailing,
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(),
                      ),

                    const SizedBox(height: 20),
                    TextField(
                      decoration: InputDecoration(
                        labelText: "Update Bot Token",
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
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          // Let's fetch the App first.
                          User discordUser = await getDiscordUser(_token);

                          await appManager.createOrUpdateApp(
                            discordUser,
                            _token,
                          );
                          Navigator.pop(context);
                        } catch (e) {
                          // Handle error
                          developer.log(
                            "Error creating app: $e",
                            name: "AppSettingsPage",
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
            ),
      ),
    );
  }
}
