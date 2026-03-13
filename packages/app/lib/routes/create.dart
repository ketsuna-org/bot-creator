import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/global.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

class AppCreatePage extends StatefulWidget {
  const AppCreatePage({super.key});

  @override
  State<AppCreatePage> createState() => _AppCreatePageState();
}

class _AppCreatePageState extends State<AppCreatePage> {
  String _token = "";
  bool _isSaving = false;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    // Log the opening of the create app page
    AppAnalytics.logScreenView(
      screenName: "AppCreatePage",
      screenClass: "AppCreatePage",
    );
  }

  Future<void> _openExternalPage(String url) async {
    final uri = Uri.parse(url);

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showErrorDialog(AppStrings.t('app_open_link_error'));
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String message) {
    final dialog = AlertDialog(
      title: Text(AppStrings.t('error')),
      content: Text(message),
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

  Future<void> _saveBot() async {
    final token = _token.trim();
    if (_isSaving || token.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final discordUser = await getDiscordUser(token);

      await appManager.createOrUpdateApp(discordUser, token);
      await AppAnalytics.logEvent(
        name: "create_app",
        parameters: {
          "app_name": discordUser.username as Object,
          "app_id": discordUser.id.toString() as Object,
        },
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      developer.log("Error creating app: $e", name: "AppCreatePage");
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final maxWidth = ResponsiveHelper.getContentMaxWidth(context);
    final horizontalPadding = ResponsiveHelper.getHorizontalPaddingValue(
      context,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final sectionSpacing = ResponsiveHelper.getSpacing(context, factor: 1.5);
    final cardPadding = EdgeInsets.all(isMobile ? 16 : 20);

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('app_create_page_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.secondaryContainer,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.smart_toy_rounded,
                            size: isMobile ? 40 : 48,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppStrings.t('app_create_hero_title'),
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.t('app_create_hero_desc'),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: sectionSpacing),
                    Card(
                      child: Padding(
                        padding: cardPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.t('app_resources_title'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppStrings.t('app_resources_desc'),
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ExternalActionCard(
                              icon: Icons.open_in_new_rounded,
                              title: AppStrings.t('app_open_discord_portal'),
                              subtitle: AppStrings.t(
                                'app_open_discord_portal_desc',
                              ),
                              badgeLabel: AppStrings.t(
                                'app_external_link_badge',
                              ),
                              onTap:
                                  () => _openExternalPage(
                                    'https://discord.com/developers/applications',
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _ExternalActionCard(
                              icon: Icons.school_rounded,
                              title: AppStrings.t('app_open_token_tutorial'),
                              subtitle: AppStrings.t(
                                'app_open_token_tutorial_desc',
                              ),
                              badgeLabel: AppStrings.t(
                                'app_external_link_badge',
                              ),
                              onTap:
                                  () => _openExternalPage(
                                    'https://bot-creator.fr/tutorials/2025/05/18/how-to-create-a-bot-token-bot-creator.html',
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: sectionSpacing),
                    Card(
                      child: Padding(
                        padding: cardPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.t('app_token_section_title'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppStrings.t('app_token_section_desc'),
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              decoration: InputDecoration(
                                labelText: AppStrings.t('app_bot_token'),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                hintText: AppStrings.t('app_enter_token'),
                                helperText: AppStrings.t(
                                  'app_token_field_helper',
                                ),
                                isDense: isMobile,
                                prefixIcon: const Icon(Icons.key_rounded),
                                suffixIcon: IconButton(
                                  tooltip:
                                      _obscureToken
                                          ? AppStrings.t('app_show_token')
                                          : AppStrings.t('app_hide_token'),
                                  onPressed: () {
                                    setState(
                                      () => _obscureToken = !_obscureToken,
                                    );
                                  },
                                  icon: Icon(
                                    _obscureToken
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                  ),
                                ),
                              ),
                              obscureText: _obscureToken,
                              enableSuggestions: false,
                              autocorrect: false,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              onChanged:
                                  (value) => setState(() {
                                    _token = value;
                                  }),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      AppStrings.t('app_token_security_hint'),
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed:
                                    _token.trim().isEmpty || _isSaving
                                        ? null
                                        : _saveBot,
                                icon:
                                    _isSaving
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.check_circle_outline_rounded,
                                        ),
                                label: Text(AppStrings.t('app_save_bot')),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExternalActionCard extends StatelessWidget {
  const _ExternalActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeLabel,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new_rounded, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
