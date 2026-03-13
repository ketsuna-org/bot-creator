import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/workflow_docs.page.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:bot_creator/utils/i18n.dart';
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
  late Map<String, bool> _intentsMap;

  @override
  void initState() {
    super.initState();
    AppAnalytics.logScreenView(
      screenName: "AppSettingsPage",
      screenClass: "AppSettingsPage",
      parameters: {"app_id": widget.client.application.id.toString()},
    );
    _initIntents();
    _init();
  }

  void _initIntents() {
    _intentsMap = {
      'Guild Presence': false,
      'Guild Members': false,
      'Message Content': false,
      'Direct Messages': false,
      'Guilds': false,
      'Guild Messages': false,
      'Guild Message Reactions': false,
      'Direct Message Reactions': false,
      'Guild Message Typing': false,
      'Direct Message Typing': false,
      'Guild Scheduled Events': false,
      'Auto Moderation Configuration': false,
      'Auto Moderation Execution': false,
    };
  }

  Future<void> _init() async {
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
      appBar: AppBar(title: Text(AppStrings.t('bot_settings_title'))),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentMaxWidth = constraints.maxWidth >= 900 ? 760.0 : 640.0;
          return Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 20),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(AppStrings.t('bot_settings_workflow_docs')),
                        subtitle: Text(
                          AppStrings.t('bot_settings_workflow_docs_desc'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      const WorkflowDocumentationPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        AppStrings.t('bot_settings_app_flags'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (app != null)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: flagsMap.length,
                        itemBuilder: (context, index) {
                          final flagName = flagsMap.keys.elementAt(index);
                          final flagValue = flagsMap[flagName];

                          if (flagName == 'Hash Code') {
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
                        separatorBuilder: (_, _) => const Divider(),
                      ),

                    const SizedBox(height: 30),
                    // Intents Configuration Section
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        AppStrings.t('bot_settings_gateway_intents'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        AppStrings.t('bot_settings_gateway_intents_desc'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _intentsMap.length,
                      itemBuilder: (context, index) {
                        final intentName = _intentsMap.keys.elementAt(index);
                        final intentValue = _intentsMap[intentName] ?? false;

                        return CheckboxListTile(
                          title: Text(intentName),
                          value: intentValue,
                          onChanged: (newValue) {
                            setState(() {
                              _intentsMap[intentName] = newValue ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                      separatorBuilder: (_, _) => const Divider(),
                    ),

                    const SizedBox(height: 30),
                    // Token Update Section
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        AppStrings.t('bot_settings_token_title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextField(
                      decoration: InputDecoration(
                        labelText: AppStrings.t('bot_settings_update_token'),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(8),
                        hintText: AppStrings.t('bot_settings_token_hint'),
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
                            intents: _intentsMap,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppStrings.t('bot_settings_save_success'),
                              ),
                            ),
                          );
                          Navigator.pop(context);
                        } catch (e) {
                          developer.log(
                            "Error creating app: $e",
                            name: "AppSettingsPage",
                          );
                          final errorText = e.toString();
                          final dialog = AlertDialog(
                            title: Text(AppStrings.t('error')),
                            content: Text(errorText),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text(AppStrings.t('ok')),
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
                      child: Text(AppStrings.t('app_save')),
                    ),
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
