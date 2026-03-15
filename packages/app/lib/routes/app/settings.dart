import 'dart:io';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/workflow_docs.page.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:file_picker/file_picker.dart';
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
  Application? app;
  bool _isSavingToken = false;
  bool _isSavingIntents = false;
  bool _isSavingProfile = false;
  bool _isEditingToken = false;
  String _savedToken = '';
  late Map<String, bool> _intentsMap;
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  String? _selectedAvatarPath;
  final List<_StatusDraft> _statusDrafts = <_StatusDraft>[];

  static const List<String> _statusTypes = <String>[
    'playing',
    'streaming',
    'listening',
    'watching',
    'competing',
  ];

  String _statusTypeLabel(String type) {
    switch (type) {
      case 'streaming':
        return AppStrings.t('bot_settings_status_type_streaming');
      case 'listening':
        return AppStrings.t('bot_settings_status_type_listening');
      case 'watching':
        return AppStrings.t('bot_settings_status_type_watching');
      case 'competing':
        return AppStrings.t('bot_settings_status_type_competing');
      case 'playing':
      default:
        return AppStrings.t('bot_settings_status_type_playing');
    }
  }

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

  @override
  void dispose() {
    _tokenController.dispose();
    _usernameController.dispose();
    for (final status in _statusDrafts) {
      status.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    final fetchedApp =
        await widget.client.applications.fetchCurrentApplication();
    final persistedApp = await appManager.getApp(
      widget.client.user.id.toString(),
    );
    final persistedIntents = Map<String, bool>.from(
      (persistedApp['intents'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value == true),
          ) ??
          const <String, bool>{},
    );

    for (final entry in persistedIntents.entries) {
      if (_intentsMap.containsKey(entry.key)) {
        _intentsMap[entry.key] = entry.value;
      }
    }

    final persistedStatuses = List<Map<String, dynamic>>.from(
      (persistedApp['statuses'] as List?)?.whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ) ??
          const <Map<String, dynamic>>[],
    );

    for (final status in _statusDrafts) {
      status.dispose();
    }
    _statusDrafts.clear();

    if (persistedStatuses.isEmpty) {
      _statusDrafts.add(_StatusDraft.empty());
    } else {
      for (final status in persistedStatuses) {
        _statusDrafts.add(_StatusDraft.fromMap(status));
      }
    }

    setState(() {
      app = fetchedApp;
      _savedToken = (persistedApp['token'] ?? '').toString().trim();
      _tokenController.text = _savedToken;
      _usernameController.text = '';
      _selectedAvatarPath = null;
    });
  }

  Future<void> _saveIntentsOnly() async {
    setState(() {
      _isSavingIntents = true;
    });

    try {
      final appData = Map<String, dynamic>.from(
        await appManager.getApp(widget.client.user.id.toString()),
      );
      final token = (appData['token'] ?? _savedToken).toString().trim();
      if (token.isEmpty) {
        throw Exception(AppStrings.t('bot_settings_save_token_first'));
      }

      final discordUser = await getDiscordUser(token);
      await appManager.createOrUpdateApp(
        discordUser,
        token,
        intents: _intentsMap,
      );

      final latestAppData = Map<String, dynamic>.from(
        await appManager.getApp(discordUser.id.toString()),
      );
      latestAppData.remove('username');
      latestAppData.remove('avatarPath');
      await appManager.saveApp(discordUser.id.toString(), latestAppData);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('bot_settings_intents_saved'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingIntents = false;
        });
      }
    }
  }

  Future<void> _saveTokenOnly() async {
    setState(() {
      _isSavingToken = true;
    });

    try {
      final effectiveToken = _tokenController.text.trim();
      if (effectiveToken.isEmpty) {
        throw Exception(AppStrings.t('bot_settings_token_required'));
      }

      final discordUser = await getDiscordUser(effectiveToken);
      final existingAppData = Map<String, dynamic>.from(
        await appManager.getApp(widget.client.user.id.toString()),
      );
      final existingIntents = Map<String, bool>.from(
        (existingAppData['intents'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value == true),
            ) ??
            const <String, bool>{},
      );
      final intentsToKeep =
          existingIntents.isEmpty ? _intentsMap : existingIntents;

      await appManager.createOrUpdateApp(
        discordUser,
        effectiveToken,
        intents: intentsToKeep,
      );

      final appData = Map<String, dynamic>.from(
        await appManager.getApp(discordUser.id.toString()),
      );
      appData.remove('username');
      appData.remove('avatarPath');
      await appManager.saveApp(discordUser.id.toString(), appData);

      _savedToken = effectiveToken;
      _isEditingToken = false;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('bot_settings_token_saved'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingToken = false;
        });
      }
    }
  }

  Future<void> _saveProfileAndStatuses() async {
    setState(() {
      _isSavingProfile = true;
    });

    try {
      final statuses = _collectStatuses();
      final appData = Map<String, dynamic>.from(
        await appManager.getApp(widget.client.user.id.toString()),
      );
      final token = (appData['token'] ?? _savedToken).toString().trim();
      if (token.isEmpty) {
        throw Exception(AppStrings.t('bot_settings_save_token_first'));
      }

      final trimmedUsername = _usernameController.text.trim();
      final trimmedAvatarPath = (_selectedAvatarPath ?? '').trim();
      if (trimmedAvatarPath.isNotEmpty &&
          !isSupportedDiscordAvatarPath(trimmedAvatarPath)) {
        final ext = avatarFileExtension(trimmedAvatarPath) ?? 'unknown';
        throw Exception(
          AppStrings.tr(
            'bot_settings_avatar_unsupported_format',
            params: {
              'ext': ext,
              'formats': supportedDiscordAvatarFormatsLabel(),
            },
          ),
        );
      }
      final shouldUpdateProfile =
          trimmedUsername.isNotEmpty || trimmedAvatarPath.isNotEmpty;

      User discordUser;
      if (shouldUpdateProfile) {
        discordUser = await updateDiscordBotProfile(
          token,
          username: trimmedUsername.isNotEmpty ? trimmedUsername : null,
          avatarPath: trimmedAvatarPath.isNotEmpty ? trimmedAvatarPath : null,
        );

        final intents = Map<String, bool>.from(
          (appData['intents'] as Map?)?.map(
                (key, value) => MapEntry(key.toString(), value == true),
              ) ??
              const <String, bool>{},
        );
        await appManager.createOrUpdateApp(
          discordUser,
          token,
          intents: intents,
        );
      } else {
        discordUser = await getDiscordUser(token);
      }

      final latestAppData = Map<String, dynamic>.from(
        await appManager.getApp(discordUser.id.toString()),
      );
      latestAppData['statuses'] = statuses;
      latestAppData.remove('username');
      latestAppData.remove('avatarPath');

      await appManager.saveApp(discordUser.id.toString(), latestAppData);

      applyDesktopRuntimeSettings(
        botId: discordUser.id.toString(),
        appData: latestAppData,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('bot_settings_profile_saved'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _collectStatuses() {
    final normalized = <Map<String, dynamic>>[];

    for (var i = 0; i < _statusDrafts.length; i++) {
      final draft = _statusDrafts[i];
      final text = draft.textController.text.trim();
      final min = int.tryParse(draft.minController.text.trim()) ?? 60;
      final max = int.tryParse(draft.maxController.text.trim()) ?? min;

      if (text.isEmpty) {
        throw FormatException('Status #${i + 1}: text is required.');
      }
      if (min <= 0 || max <= 0) {
        throw FormatException(
          'Status #${i + 1}: min/max interval must be > 0.',
        );
      }
      if (max < min) {
        throw FormatException(
          'Status #${i + 1}: max interval must be >= min interval.',
        );
      }

      normalized.add({
        'type': draft.type,
        'text': text,
        'minIntervalSeconds': min,
        'maxIntervalSeconds': max,
      });
    }

    return normalized;
  }

  Future<void> _pickAvatarFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedDiscordAvatarFormats,
      allowMultiple: false,
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }

    final path = picked.files.single.path;
    if (path == null || path.isEmpty) {
      return;
    }

    if (!isSupportedDiscordAvatarPath(path)) {
      if (!mounted) {
        return;
      }
      final ext = avatarFileExtension(path) ?? 'unknown';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.tr(
              'bot_settings_avatar_unsupported_format',
              params: {
                'ext': ext,
                'formats': supportedDiscordAvatarFormatsLabel(),
              },
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedAvatarPath = path;
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
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.t('bot_settings_save_intents_caption'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isSavingIntents
                                ? null
                                : () async {
                                  try {
                                    await _saveIntentsOnly();
                                  } catch (e) {
                                    developer.log(
                                      'Error saving intents: $e',
                                      name: 'AppSettingsPage',
                                    );
                                    if (!mounted) return;
                                    final dialog = AlertDialog(
                                      title: Text(AppStrings.t('error')),
                                      content: Text(e.toString()),
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
                        icon: const Icon(Icons.tune),
                        label: Text(
                          AppStrings.t('bot_settings_save_intents_btn'),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        AppStrings.t('bot_settings_profile_title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextField(
                      decoration: InputDecoration(
                        labelText: AppStrings.t(
                          'bot_settings_username_override',
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(8),
                        hintText: AppStrings.t('bot_settings_username_hint'),
                      ),
                      controller: _usernameController,
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _pickAvatarFile,
                        icon: const Icon(Icons.folder_open),
                        label: Text(AppStrings.t('bot_settings_browse')),
                      ),
                    ),
                    if (_selectedAvatarPath != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.tr(
                          'bot_settings_avatar_selected_file',
                          params: {'path': _selectedAvatarPath!},
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2D31),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E1F22)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF1E1F22),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.file(
                                  File(_selectedAvatarPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) {
                                    return Container(
                                      color: const Color(0xFF404249),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                        color: Color(0xFFB5BAC1),
                                        size: 20,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (_usernameController.text.trim().isNotEmpty)
                                        ? _usernameController.text.trim()
                                        : 'Bot Creator',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFF2F3F5),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF5865F2),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'APP',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          AppStrings.t(
                                            'bot_settings_avatar_preview_label',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFB5BAC1),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedAvatarPath = null;
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: Text(
                            AppStrings.t('bot_settings_avatar_clear_selection'),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        AppStrings.t('bot_settings_status_rotation_title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        AppStrings.t('bot_settings_status_rotation_desc'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _statusDrafts.add(_StatusDraft.empty());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: Text(AppStrings.t('bot_settings_add_status')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_statusDrafts.length, (index) {
                      final draft = _statusDrafts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      AppStrings.tr(
                                        'bot_settings_status_item_title',
                                        params: {'index': '${index + 1}'},
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: AppStrings.t(
                                      'bot_settings_remove_status',
                                    ),
                                    onPressed:
                                        _statusDrafts.length <= 1
                                            ? null
                                            : () {
                                              setState(() {
                                                final removed = _statusDrafts
                                                    .removeAt(index);
                                                removed.dispose();
                                              });
                                            },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: draft.type,
                                decoration: InputDecoration(
                                  labelText: AppStrings.t(
                                    'bot_settings_status_type_label',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                items: _statusTypes
                                    .map(
                                      (type) => DropdownMenuItem<String>(
                                        value: type,
                                        child: Text(_statusTypeLabel(type)),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    draft.type = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: draft.textController,
                                decoration: InputDecoration(
                                  labelText: AppStrings.t(
                                    'bot_settings_status_text_label',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: draft.minController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: AppStrings.t(
                                          'bot_settings_status_min_interval',
                                        ),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: draft.maxController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: AppStrings.t(
                                          'bot_settings_status_max_interval',
                                        ),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                    Text(
                      AppStrings.t('bot_settings_save_profile_caption'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isSavingProfile
                                ? null
                                : () async {
                                  try {
                                    await _saveProfileAndStatuses();
                                  } catch (e) {
                                    developer.log(
                                      'Error saving profile/statuses: $e',
                                      name: 'AppSettingsPage',
                                    );
                                    if (!mounted) return;
                                    final dialog = AlertDialog(
                                      title: Text(AppStrings.t('error')),
                                      content: Text(e.toString()),
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
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          AppStrings.t('bot_settings_save_profile_status_btn'),
                        ),
                      ),
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
                    if (!_isEditingToken) ...[
                      Text(
                        AppStrings.t('bot_settings_token_hidden_desc'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _tokenController.text = _savedToken;
                              _isEditingToken = true;
                            });
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(
                            AppStrings.t('bot_settings_edit_token_btn'),
                          ),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: _tokenController,
                        decoration: InputDecoration(
                          labelText: AppStrings.t('bot_settings_update_token'),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.all(8),
                          hintText: AppStrings.t('bot_settings_token_hint'),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _isSavingToken
                                  ? null
                                  : () {
                                    setState(() {
                                      _tokenController.text = _savedToken;
                                      _isEditingToken = false;
                                    });
                                  },
                          icon: const Icon(Icons.close),
                          label: Text(
                            AppStrings.t('bot_settings_cancel_token_edit_btn'),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.t('bot_settings_save_token_caption'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isSavingToken || !_isEditingToken)
                                ? null
                                : () async {
                                  try {
                                    await _saveTokenOnly();
                                  } catch (e) {
                                    developer.log(
                                      'Error saving token: $e',
                                      name: 'AppSettingsPage',
                                    );
                                    if (!mounted) return;
                                    final dialog = AlertDialog(
                                      title: Text(AppStrings.t('error')),
                                      content: Text(e.toString()),
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
                        icon: const Icon(Icons.vpn_key_outlined),
                        label: Text(
                          AppStrings.t('bot_settings_save_token_only_btn'),
                        ),
                      ),
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

class _StatusDraft {
  String type;
  final TextEditingController textController;
  final TextEditingController minController;
  final TextEditingController maxController;

  _StatusDraft({
    required this.type,
    required this.textController,
    required this.minController,
    required this.maxController,
  });

  factory _StatusDraft.empty() {
    return _StatusDraft(
      type: 'playing',
      textController: TextEditingController(),
      minController: TextEditingController(text: '60'),
      maxController: TextEditingController(text: '60'),
    );
  }

  factory _StatusDraft.fromMap(Map<String, dynamic> map) {
    final min =
        int.tryParse((map['minIntervalSeconds'] ?? '').toString()) ?? 60;
    final maxRaw =
        int.tryParse((map['maxIntervalSeconds'] ?? '').toString()) ?? min;
    final max = maxRaw < min ? min : maxRaw;

    final type = (map['type'] ?? 'playing').toString().trim().toLowerCase();
    return _StatusDraft(
      type:
          _AppSettingsPageState._statusTypes.contains(type) ? type : 'playing',
      textController: TextEditingController(
        text: (map['text'] ?? '').toString(),
      ),
      minController: TextEditingController(text: '$min'),
      maxController: TextEditingController(text: '$max'),
    );
  }

  void dispose() {
    textController.dispose();
    minController.dispose();
    maxController.dispose();
  }
}
