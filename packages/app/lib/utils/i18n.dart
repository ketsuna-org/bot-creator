import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locales supportées
enum AppLocale {
  en('English', 'en'),
  fr('Français', 'fr');

  final String label;
  final String code;

  const AppLocale(this.label, this.code);
}

enum AppLocalePreference {
  system('Automatic', 'system'),
  en('English', 'en'),
  fr('Français', 'fr');

  final String label;
  final String code;

  const AppLocalePreference(this.label, this.code);
}

/// Translations for all strings in the app
class AppStrings {
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'app_title': 'Bot Creator',

      // Onboarding
      'onboarding_welcome_title': 'Welcome to Bot Creator',
      'onboarding_welcome_desc':
          'Create your first Discord bot in 3 simple steps. We\'ll guide you through each step.',
      'onboarding_welcome_start': 'Get Started',
      'onboarding_welcome_skip': 'Skip',

      'onboarding_create_title': 'Step 1: Create a Bot',
      'onboarding_create_desc': 'Get your Discord token',
      'onboarding_create_steps':
          '1. Go to Discord Developer Portal\n2. Create a new app\n3. Copy the bot token\n4. Paste it below',
      'onboarding_create_tip':
          '💡 Tip: Never share your token! It gives full access to your bot.',
      'onboarding_create_tutorial': 'Tutorial: How to get a token',
      'onboarding_create_button': 'Continue',

      'onboarding_command_title': 'Step 2: Add a Command',
      'onboarding_command_desc': 'Create your first command',
      'onboarding_command_text':
          'Commands are the heart of your bot. They allow users to interact with your bot via Discord.',
      'onboarding_command_example':
          'Example:\n/hello → Bot replies "Hello! 👋"',
      'onboarding_command_button': 'Continue',

      'onboarding_start_title': 'Step 3: Start the Bot',
      'onboarding_start_desc': 'Launch your bot!',
      'onboarding_start_text':
          'Click the "Start" button on your bot card. Then test your command in Discord!',
      'onboarding_start_tip':
          '✨ Great! You\'ve created your first Discord bot. You can now add more commands and customize it!',
      'onboarding_start_button': 'Continue',

      'onboarding_success_title': 'Congratulations! 🎉',
      'onboarding_success_desc': 'Your Discord bot is ready to go!',
      'onboarding_success_whatsnext': 'What\'s next?',
      'onboarding_success_tip1': 'Add more commands',
      'onboarding_success_tip2': 'Create workflows',
      'onboarding_success_tip3': 'Backup your data',
      'onboarding_success_button': 'Start!',

      // App UI
      'app_create_new': 'Create a new App',
      'app_create_page_title': 'Create a bot',
      'app_create_hero_title': 'Connect your Discord bot',
      'app_create_hero_desc':
          'A guided setup to open the right pages, copy your token and import the bot safely.',
      'app_resources_title': 'Guided setup',
      'app_resources_desc':
          'These actions open the official pages you need before saving your bot here.',
      'app_open_discord_portal': 'Open Discord Developer Portal',
      'app_open_discord_portal_desc':
          'Create your application and enable the bot section.',
      'app_open_token_tutorial': 'Read the token tutorial',
      'app_open_token_tutorial_desc':
          'A step-by-step guide to generate and copy your bot token.',
      'app_external_link_badge': 'External link',
      'app_token_section_title': 'Paste your bot token',
      'app_token_section_desc':
          'Once the token is copied, paste it below to add your bot to the app.',
      'app_token_field_helper':
          'Paste the token exactly as provided by Discord.',
      'app_token_security_hint':
          'Keep this token private. Anyone with it can control your bot.',
      'app_show_token': 'Show token',
      'app_hide_token': 'Hide token',
      'app_save_bot': 'Add bot',
      'app_open_link_error': 'Unable to open this external page.',
      'app_how_to_create_token': 'How to create a Bot Token?',
      'app_bot_token': 'Bot Token',
      'app_enter_token': 'Enter your bot token here',
      'app_note':
          'Note: You need to create a new App in the Discord Developer Portal and get your bot token.',
      'app_save': 'Save Changes',
      'app_no_apps': 'No applications found',
      'app_loading_error': 'Loading error',
      'app_create_button': 'Create a bot',

      'home_tab': 'Home',
      'commands_tab': 'Commands',
      'commands_tab_short': 'Cmd',
      'globals_tab': 'Globals',
      'globals_tab_short': 'Vars',
      'workflows_tab': 'Workflows',
      'workflows_tab_short': 'Flow',
      'settings_tab': 'Settings',
      'settings_theme_switch_light': 'Switch to light mode',
      'settings_theme_switch_dark': 'Switch to dark mode',
      'settings_appearance_title': 'Appearance & language',
      'settings_language_title': 'Language',
      'settings_language_desc': 'Choose the language used by the app.',
      'settings_language_system': 'Automatic (device)',
      'settings_language_updated': 'Language updated',
      'settings_debug_title': 'Debug tools',
      'settings_debug_desc':
          'Reset local preferences or replay onboarding for testing.',
      'settings_reset_preferences': 'Reset preferences',
      'settings_reset_preferences_desc':
          'Reset theme, language and onboarding progress.',
      'settings_replay_onboarding': 'Replay onboarding',
      'settings_replay_onboarding_desc':
          'Reset onboarding and launch it again now.',
      'settings_preferences_reset_done': 'Preferences reset',
      'settings_backup_restore_title': 'Backup and Restore',
      'settings_backup_restore_desc':
          'Manage your data synchronization with Google Drive',
      'settings_snapshot_preview_title': 'Snapshot Preview',
      'settings_snapshot_id': 'ID: {id}',
      'settings_snapshot_label': 'Label: {label}',
      'settings_snapshot_created_at': 'Created: {date}',
      'settings_snapshot_files_size': 'Files: {count} • Size: {size}',
      'settings_snapshot_apps_count': 'Apps: {count}',
      'settings_snapshot_apps_list': 'Apps in this snapshot',
      'settings_snapshot_no_metadata': 'No app metadata available.',
      'settings_snapshot_delete_loading': 'Deleting snapshot…',
      'settings_snapshot_deleted': 'Snapshot deleted',
      'settings_snapshot_restore_loading': 'Restoring snapshot…',
      'settings_restore_snapshot': 'Restore This Snapshot',
      'settings_diagnostics_dialog_title': 'Startup Diagnostics',
      'settings_diagnostics_copied': 'Diagnostics copied to clipboard',
      'settings_drive_title': 'Google Drive Connection',
      'settings_drive_desc':
          'Connect your Google Drive account to sync your data',
      'settings_drive_connect_loading': 'Connecting to Google Drive…',
      'settings_drive_connected': 'Connected to Google Drive',
      'settings_drive_connect': 'Connect to Google Drive',
      'settings_drive_status_connected': 'Connected',
      'settings_drive_disconnect_loading': 'Disconnecting…',
      'settings_drive_disconnected': 'Disconnected from Google Drive',
      'settings_drive_disconnect': 'Disconnect',
      'settings_data_operations_title': 'Data Operations',
      'settings_export': 'Export',
      'settings_import': 'Import',
      'settings_export_app_data': 'Export App Data',
      'settings_import_app_data': 'Import App Data',
      'settings_export_loading': 'Exporting…',
      'settings_import_loading': 'Importing…',
      'settings_recovery_title': 'Recovery Pro',
      'settings_enable_auto_backup': 'Enable auto-backup',
      'settings_enable_auto_backup_desc':
          'Create versioned snapshots automatically when due.',
      'settings_auto_backup_interval': 'Auto-backup interval',
      'settings_auto_backup_every_6h': 'Every 6h',
      'settings_auto_backup_every_12h': 'Every 12h',
      'settings_auto_backup_every_24h': 'Every 24h',
      'settings_auto_backup_every_72h': 'Every 72h',
      'settings_last_auto_backup_never': 'Last auto-backup: never',
      'settings_last_auto_backup_at': 'Last auto-backup: {date}',
      'settings_snapshot_create_loading': 'Creating snapshot…',
      'settings_manual_snapshot_label': 'Manual snapshot',
      'settings_snapshot_created_message': 'Snapshot created: {id}',
      'settings_backup_now': 'Backup now',
      'settings_run_auto_backup_now': 'Run auto-backup now',
      'settings_auto_backup_check_loading': 'Auto-backup check…',
      'settings_snapshots_title': 'Snapshots',
      'settings_snapshots_refresh': 'Refresh snapshots',
      'settings_snapshots_refresh_loading': 'Refreshing snapshots…',
      'settings_snapshots_empty': 'No snapshots found yet.',
      'settings_snapshot_list_entry': '{date} • {count} files • {size}',
      'settings_diagnostics_section_title': 'Diagnostics',
      'settings_view_startup_logs': 'View startup logs',
      'settings_clear_logs': 'Clear logs',
      'settings_logs_cleared': 'Diagnostics log cleared',
      'settings_legal_title': 'Legal',
      'settings_legal_desc': 'Review how your data is handled and stored.',
      'settings_privacy_policy': 'Privacy Policy',

      'home_token_missing': 'Token not found for {botName}',
      'home_log_start_requested': 'Bot start requested',
      'home_log_stop_requested': 'Bot stop requested',
      'home_notification_permission_required':
          'Notification permission is required to start the bot.',
      'home_foreground_service_not_started':
          'The foreground service did not start.',
      'home_log_desktop_stop_requested': 'Desktop bot stop requested',
      'home_unknown_app': 'Unknown',
      'home_status_online': 'Online',
      'home_status_offline': 'Offline',
      'home_server_count_one': '{count} server',
      'home_server_count_other': '{count} servers',
      'home_stop': 'Stop',
      'home_start': 'Start',
      'home_manage': 'Manage',
      'home_logs_tooltip': 'Bot logs',

      'error': 'Error',
      'error_with_details': 'Error: {error}',
      'ok': 'OK',
      'close': 'Close',
      'copy': 'Copy',
      'delete': 'Delete',
      'cancel': 'Cancel',

      // Bot internal pages — app/home.dart
      'bot_home_start': 'Start Bot',
      'bot_home_stop': 'Stop Bot',
      'bot_home_view_logs': 'View bot logs',
      'bot_home_view_stats': 'View bot stats',
      'bot_home_sync': 'Sync App',
      'bot_home_sync_success': 'App synced successfully',
      'bot_home_invite': 'Invite Bot',
      'bot_home_invite_error': 'Could not open invite link',
      'bot_home_delete': 'Delete App',
      'bot_home_delete_confirm': 'Are you sure you want to delete this app?',
      'bot_home_start_error': 'Could not start: {error}',
      'bot_home_log_start': 'Bot start requested',
      'bot_home_log_stop': 'Bot stop requested',
      'bot_home_log_desktop_stop': 'Desktop bot stop requested',
      'bot_home_notif_required':
          'Notification permission is required to start the bot service.',
      'bot_home_service_not_started': 'Foreground service did not start.',

      // Bot internal pages — app/settings.dart
      'bot_settings_title': 'Application Settings',
      'bot_settings_workflow_docs': 'Workflow Documentation',
      'bot_settings_workflow_docs_desc':
          'Detailed guide for entry points, call arguments, and runtime behavior.',
      'bot_settings_app_flags': 'Application Flags',
      'bot_settings_gateway_intents': 'Gateway Intents Configuration',
      'bot_settings_gateway_intents_desc':
          'Select which intents your bot needs. Configure these in the Discord Developer Portal.',
      'bot_settings_token_title': 'Bot Token',
      'bot_settings_update_token': 'Update Bot Token',
      'bot_settings_token_hint': 'Enter your bot token here',
      'bot_settings_save_success': 'Settings saved successfully',
      'bot_settings_save_token_btn': 'Save token and intents',
      'bot_settings_save_token_only_btn': 'Save token',
      'bot_settings_save_intents_btn': 'Save intents',
      'bot_settings_save_profile_status_btn': 'Save profile and statuses',
      'bot_settings_save_token_caption':
          'Token changes are protected. Click "Edit token" first, then save.',
      'bot_settings_save_intents_caption':
          'This only updates gateway intents configuration.',
      'bot_settings_save_profile_caption':
          'This applies username/avatar instantly and saves status rotation.',
      'bot_settings_token_saved': 'Token saved successfully',
      'bot_settings_intents_saved': 'Intents saved successfully',
      'bot_settings_profile_saved': 'Profile/statuses applied successfully',
      'bot_settings_edit_token_btn': 'Edit token',
      'bot_settings_cancel_token_edit_btn': 'Cancel token edit',
      'bot_settings_token_hidden_desc':
          'Token input is hidden by default for safety.',
      'bot_settings_token_required': 'Bot token is required.',
      'bot_settings_save_token_first':
          'Please save the token first before applying profile/status changes.',
      'bot_settings_profile_title': 'Bot Profile',
      'bot_settings_username_override': 'Username override',
      'bot_settings_username_hint': 'Leave empty to keep current username',
      'bot_settings_avatar_local_path': 'Avatar local file path',
      'bot_settings_avatar_path_hint': '/absolute/path/to/avatar.png',
      'bot_settings_browse': 'Browse',
      'bot_settings_avatar_selected_file': 'Selected file: {path}',
      'bot_settings_avatar_preview_label': 'Avatar preview',
      'bot_settings_avatar_preview_error': 'Unable to preview image',
      'bot_settings_avatar_unsupported_format':
          'Unsupported avatar format: {ext}. Supported formats: {formats}.',
      'bot_settings_avatar_clear_selection': 'Clear selection',
      'bot_settings_status_rotation_title': 'Status Rotation',
      'bot_settings_status_rotation_desc':
          'Add one or more statuses. Each status needs a type, text, and min/max interval (seconds).',
      'bot_settings_add_status': 'Add status',
      'bot_settings_status_item_title': 'Status {index}',
      'bot_settings_remove_status': 'Remove status',
      'bot_settings_status_type_label': 'Type',
      'bot_settings_status_type_playing': 'Playing',
      'bot_settings_status_type_streaming': 'Streaming',
      'bot_settings_status_type_listening': 'Listening',
      'bot_settings_status_type_watching': 'Watching',
      'bot_settings_status_type_competing': 'Competing',
      'bot_settings_status_text_label': 'Status text',
      'bot_settings_status_min_interval': 'Min interval (s)',
      'bot_settings_status_max_interval': 'Max interval (s)',

      // Bot logs page
      'bot_logs_title': 'Bot Logs',
      'bot_logs_disable_debug': 'Disable debug logs',
      'bot_logs_enable_debug': 'Enable debug logs',
      'bot_logs_copied': 'Logs copied',
      'bot_logs_oldest_first': 'Show oldest first',
      'bot_logs_newest_first': 'Show newest first',
      'bot_logs_filter_count': 'Number of displayed logs',
      'bot_logs_show_n': 'Show {count} logs',
      'bot_logs_show_all': 'Show all',
      'bot_logs_empty': 'No logs yet',
      'bot_logs_show_more': 'Show more',
      'bot_logs_show_less': 'Show less',
      'bot_logs_ram': 'Bot process RAM: {memory}',
      'bot_logs_go_to_latest': 'Go to latest log',
      'bot_logs_go_to_bottom': 'Go to bottom',

      // Bot stats page
      'bot_stats_title': 'Bot Stats',
      'bot_stats_ram_process': 'Bot process RAM',
      'bot_stats_ram_estimated': 'Bot RAM only (estimated)',
      'bot_stats_cpu': 'Bot process CPU',
      'bot_stats_storage': 'Bot storage (app data)',
      'bot_stats_notes':
          'Notes: CPU available on Android/Linux. Storage = bot data files in the app.',
      'bot_stats_collecting': 'Collecting…',

      // Commands list page
      'commands_title': 'Commands',
      'commands_empty': 'No commands found',
      'commands_error': 'Error: {error}',
      'commands_create_button': 'Create command',

      // Global variables page
      'globals_title': 'Global Variables',
      'globals_empty': 'No global variables yet',
      'globals_add': 'Add Variable',
      'globals_edit': 'Edit Variable',
      'globals_key': 'Key',
      'globals_value': 'Value',

      // Workflows page
      'workflows_title': 'Workflows',
      'workflows_empty': 'No workflows yet',
      'workflows_create': 'Create Workflow',
      'workflows_edit': 'Edit Workflow',
      'workflows_name': 'Workflow Name',
      'workflows_entry_point': 'Default Entry Point',
      'workflows_entry_point_hint': 'Used if caller does not override it',
      'workflows_arguments': 'Arguments',
      'workflows_arg_name': 'Name',
      'workflows_arg_default': 'Default value',
      'workflows_arg_required_short': 'Req',
      'workflows_arg_hint':
          'Arguments become runtime variables as ((arg.name)) and ((workflow.arg.name)).',
      'workflows_continue': 'Continue',
      'workflows_add_arg': 'Add argument',
      'workflows_docs_tooltip': 'Workflow Documentation',
      'workflows_subtitle': '{count} action(s) • entry: {entry} • args: {args}',

      // Command create page
      'cmd_error_fill_fields': 'Please fill all fields',
      'cmd_variables_title': 'Command Variables',
      'cmd_show_variables': 'Show variables',
      'cmd_create_tooltip': 'Create command',
      'cmd_delete_tooltip': 'Delete command',
      'cmd_editor_mode_title': 'Editing mode',
      'cmd_editor_mode_simple': 'Simplified mode',
      'cmd_editor_mode_advanced': 'Advanced mode',
      'cmd_editor_mode_simple_desc':
          'Build a command quickly with guided options and preconfigured actions.',
      'cmd_editor_mode_advanced_desc':
          'Full editor with custom response, options, and action builder.',
      'cmd_editor_mode_switch_adv': 'Switch to advanced mode',
      'cmd_editor_mode_switch_adv_title': 'Switch to advanced mode?',
      'cmd_editor_mode_switch_adv_content':
          'This switch is one-way for this command. You won’t be able to return to simplified mode.',
      'cmd_editor_mode_switch_adv_confirm': 'Switch',
      'cmd_editor_mode_locked': 'Advanced mode is locked for this command.',
      'cmd_simple_actions_title': 'Simplified actions',
      'cmd_simple_actions_desc':
          'Select what this command should do. Options are generated automatically.',
      'cmd_simple_action_delete': 'Delete messages',
      'cmd_simple_action_delete_desc':
          'Delete messages in the current channel (optional /count).',
      'cmd_simple_action_kick': 'Kick user',
      'cmd_simple_action_kick_desc': 'Kick the selected /user from the server.',
      'cmd_simple_action_ban': 'Ban user',
      'cmd_simple_action_ban_desc': 'Ban the selected /user from the server.',
      'cmd_simple_action_mute': 'Mute user',
      'cmd_simple_action_mute_desc': 'Temporarily mute the selected /user.',
      'cmd_simple_action_add_role': 'Add role',
      'cmd_simple_action_add_role_desc':
          'Give the selected /role to the selected /user.',
      'cmd_simple_action_remove_role': 'Remove role',
      'cmd_simple_action_remove_role_desc':
          'Remove the selected /role from the selected /user.',
      'cmd_simple_action_send_message': 'Send message',
      'cmd_simple_action_send_message_desc':
          'Send an additional message in the current channel.',
      'cmd_simple_action_send_message_label': 'Action message',
      'cmd_simple_action_send_message_hint':
          'Message sent by the Send Message action',
      'cmd_simple_generated_options': 'Generated command options',
      'cmd_simple_generated_none':
          'No options generated yet. Select at least one action.',
      'cmd_simple_option_user': '/user (User)',
      'cmd_simple_option_role': '/role (Role)',
      'cmd_simple_option_count': '/count (Integer)',
      'cmd_simple_option_user_desc': 'Target user',
      'cmd_simple_option_role_desc': 'Target role',
      'cmd_simple_option_count_desc': 'Number of messages to delete',
      'cmd_simple_response_title': 'Final response',
      'cmd_simple_response_desc':
          'Message sent back to the user after actions are executed.',
      'cmd_simple_response_hint': 'Done ✅',
      'cmd_simple_response_embeds_title': 'Response embeds',
      'cmd_simple_response_embeds_desc':
          'Optional embeds sent with the final response.',
      'cmd_simple_send_message_required':
          'Please fill the action message before saving.',

      // Support & community
      'support_card_title': 'Support & Community',
      'support_card_desc':
          'A question, a bug, a suggestion? Come chat with the team and the community.',
      'support_join_discord': 'Join the Discord server',
      'support_discord_badge': 'Official support',
      'home_empty_support_hint': 'Need help getting started?',
      'home_empty_support_btn': 'Join our Discord',
    },
    'fr': {
      'app_title': 'Bot Creator',

      // Onboarding
      'onboarding_welcome_title': 'Bienvenue dans Bot Creator',
      'onboarding_welcome_desc':
          'Créez votre premier bot Discord en 3 étapes simples. Nous vous guidons à travers chaque étape.',
      'onboarding_welcome_start': 'Commencer',
      'onboarding_welcome_skip': 'Passer',

      'onboarding_create_title': 'Étape 1: Créer un bot',
      'onboarding_create_desc': 'Obtenez votre token Discord',
      'onboarding_create_steps':
          '1. Allez sur Discord Developer Portal\n2. Créez une nouvelle app\n3. Copiez le token du bot\n4. Collez-le ci-dessous',
      'onboarding_create_tip':
          '💡 Conseil: Ne partagez jamais votre token! Il donne accès complet à votre bot.',
      'onboarding_create_tutorial': 'Tutoriel: Comment obtenir un token',
      'onboarding_create_button': 'Continuer',

      'onboarding_command_title': 'Étape 2: Ajouter une commande',
      'onboarding_command_desc': 'Créez votre première commande',
      'onboarding_command_text':
          'Les commandes sont le cœur de votre bot. Elles permettent aux utilisateurs d\'interagir avec votre bot via Discord.',
      'onboarding_command_example':
          'Exemple:\n/hello → Le bot répond "Bonjour! 👋"',
      'onboarding_command_button': 'Continuer',

      'onboarding_start_title': 'Étape 3: Lancer le bot',
      'onboarding_start_desc': 'Lancez votre bot!',
      'onboarding_start_text':
          'Appuyez sur le bouton "Démarrer" sur la carte de votre bot. Testez ensuite votre commande dans Discord!',
      'onboarding_start_tip':
          '✨ Bravo! Vous avez créé votre premier bot Discord. Vous pouvez maintenant ajouter plus de commandes et le personnaliser!',
      'onboarding_start_button': 'Continuer',

      'onboarding_success_title': 'Bravo! 🎉',
      'onboarding_success_desc':
          'Votre bot Discord est maintenant prêt à l\'emploi!',
      'onboarding_success_whatsnext': 'Que faire maintenant?',
      'onboarding_success_tip1': 'Ajouter plus de commandes',
      'onboarding_success_tip2': 'Créer des workflows',
      'onboarding_success_tip3': 'Sauvegarder vos données',
      'onboarding_success_button': 'Commencer!',

      // App UI
      'app_create_new': 'Créer une nouvelle application',
      'app_create_page_title': 'Créer un bot',
      'app_create_hero_title': 'Connectez votre bot Discord',
      'app_create_hero_desc':
          'Un parcours guidé pour ouvrir les bonnes pages, copier votre token et importer le bot proprement.',
      'app_resources_title': 'Parcours guidé',
      'app_resources_desc':
          'Ces actions ouvrent les pages officielles nécessaires avant d’enregistrer votre bot ici.',
      'app_open_discord_portal': 'Ouvrir Discord Developer Portal',
      'app_open_discord_portal_desc':
          'Créez votre application et activez la section bot.',
      'app_open_token_tutorial': 'Lire le tutoriel du token',
      'app_open_token_tutorial_desc':
          'Un guide pas à pas pour générer et copier votre token de bot.',
      'app_external_link_badge': 'Lien externe',
      'app_token_section_title': 'Collez votre token de bot',
      'app_token_section_desc':
          'Une fois le token copié, collez-le ci-dessous pour ajouter votre bot à l’application.',
      'app_token_field_helper':
          'Collez le token exactement tel que fourni par Discord.',
      'app_token_security_hint':
          'Gardez ce token privé. Toute personne qui le possède peut contrôler votre bot.',
      'app_show_token': 'Afficher le token',
      'app_hide_token': 'Masquer le token',
      'app_save_bot': 'Ajouter le bot',
      'app_open_link_error': 'Impossible d’ouvrir cette page externe.',
      'app_how_to_create_token': 'Comment créer un token de bot ?',
      'app_bot_token': 'Token du bot',
      'app_enter_token': 'Entrez votre token du bot ici',
      'app_note':
          'Remarque: Vous devez créer une nouvelle application sur Discord Developer Portal et obtenir le token du bot.',
      'app_save': 'Enregistrer les modifications',
      'app_no_apps': 'Aucune application trouvée',
      'app_loading_error': 'Erreur de chargement',
      'app_create_button': 'Créer un bot',

      'home_tab': 'Accueil',
      'commands_tab': 'Commandes',
      'commands_tab_short': 'Cmd',
      'globals_tab': 'Globales',
      'globals_tab_short': 'Vars',
      'workflows_tab': 'Workflows',
      'workflows_tab_short': 'Flow',
      'settings_tab': 'Paramètres',
      'settings_theme_switch_light': 'Passer en mode clair',
      'settings_theme_switch_dark': 'Passer en mode sombre',
      'settings_appearance_title': 'Apparence et langue',
      'settings_language_title': 'Langue',
      'settings_language_desc':
          'Choisissez la langue utilisée par l’application.',
      'settings_language_system': 'Automatique (appareil)',
      'settings_language_updated': 'Langue mise à jour',
      'settings_debug_title': 'Outils de debug',
      'settings_debug_desc':
          'Réinitialise les préférences locales ou relance l’onboarding pour les tests.',
      'settings_reset_preferences': 'Réinitialiser les préférences',
      'settings_reset_preferences_desc':
          'Réinitialise le thème, la langue et la progression de l’onboarding.',
      'settings_replay_onboarding': 'Relancer l’onboarding',
      'settings_replay_onboarding_desc':
          'Réinitialise l’onboarding et le relance immédiatement.',
      'settings_preferences_reset_done': 'Préférences réinitialisées',
      'settings_backup_restore_title': 'Sauvegarde et restauration',
      'settings_backup_restore_desc':
          'Gérez la synchronisation de vos données avec Google Drive',
      'settings_snapshot_preview_title': 'Aperçu du snapshot',
      'settings_snapshot_id': 'ID : {id}',
      'settings_snapshot_label': 'Libellé : {label}',
      'settings_snapshot_created_at': 'Créé le : {date}',
      'settings_snapshot_files_size': 'Fichiers : {count} • Taille : {size}',
      'settings_snapshot_apps_count': 'Apps : {count}',
      'settings_snapshot_apps_list': 'Apps dans ce snapshot',
      'settings_snapshot_no_metadata':
          'Aucune métadonnée d’application disponible.',
      'settings_snapshot_delete_loading': 'Suppression du snapshot…',
      'settings_snapshot_deleted': 'Snapshot supprimé',
      'settings_snapshot_restore_loading': 'Restauration du snapshot…',
      'settings_restore_snapshot': 'Restaurer ce snapshot',
      'settings_diagnostics_dialog_title': 'Diagnostics de démarrage',
      'settings_diagnostics_copied':
          'Diagnostics copiés dans le presse-papiers',
      'settings_drive_title': 'Connexion Google Drive',
      'settings_drive_desc':
          'Connectez votre compte Google Drive pour synchroniser vos données',
      'settings_drive_connect_loading': 'Connexion à Google Drive…',
      'settings_drive_connected': 'Connecté à Google Drive',
      'settings_drive_connect': 'Connecter Google Drive',
      'settings_drive_status_connected': 'Connecté',
      'settings_drive_disconnect_loading': 'Déconnexion en cours…',
      'settings_drive_disconnected': 'Déconnecté de Google Drive',
      'settings_drive_disconnect': 'Déconnecter',
      'settings_data_operations_title': 'Opérations de données',
      'settings_export': 'Exporter',
      'settings_import': 'Importer',
      'settings_export_app_data': 'Exporter les données de l’app',
      'settings_import_app_data': 'Importer les données de l’app',
      'settings_export_loading': 'Export en cours…',
      'settings_import_loading': 'Import en cours…',
      'settings_recovery_title': 'Recovery Pro',
      'settings_enable_auto_backup': 'Activer l’auto-sauvegarde',
      'settings_enable_auto_backup_desc':
          'Crée automatiquement des snapshots versionnés lorsque nécessaire.',
      'settings_auto_backup_interval': 'Intervalle d’auto-sauvegarde',
      'settings_auto_backup_every_6h': 'Toutes les 6 h',
      'settings_auto_backup_every_12h': 'Toutes les 12 h',
      'settings_auto_backup_every_24h': 'Toutes les 24 h',
      'settings_auto_backup_every_72h': 'Toutes les 72 h',
      'settings_last_auto_backup_never': 'Dernière auto-sauvegarde : jamais',
      'settings_last_auto_backup_at': 'Dernière auto-sauvegarde : {date}',
      'settings_snapshot_create_loading': 'Création du snapshot…',
      'settings_manual_snapshot_label': 'Snapshot manuel',
      'settings_snapshot_created_message': 'Snapshot créé : {id}',
      'settings_backup_now': 'Sauvegarder maintenant',
      'settings_run_auto_backup_now': 'Lancer l’auto-sauvegarde',
      'settings_auto_backup_check_loading': 'Vérification auto-sauvegarde…',
      'settings_snapshots_title': 'Snapshots',
      'settings_snapshots_refresh': 'Actualiser les snapshots',
      'settings_snapshots_refresh_loading': 'Actualisation des snapshots…',
      'settings_snapshots_empty': 'Aucun snapshot trouvé pour le moment.',
      'settings_snapshot_list_entry': '{date} • {count} fichiers • {size}',
      'settings_diagnostics_section_title': 'Diagnostics',
      'settings_view_startup_logs': 'Voir les logs de démarrage',
      'settings_clear_logs': 'Effacer les logs',
      'settings_logs_cleared': 'Logs de diagnostic effacés',
      'settings_legal_title': 'Légal',
      'settings_legal_desc':
          'Consultez la manière dont vos données sont traitées et stockées.',
      'settings_privacy_policy': 'Politique de confidentialité',

      'home_token_missing': 'Token introuvable pour {botName}',
      'home_log_start_requested': 'Démarrage du bot demandé',
      'home_log_stop_requested': 'Arrêt du bot demandé',
      'home_notification_permission_required':
          'La permission de notification est requise pour lancer le bot.',
      'home_foreground_service_not_started':
          'Le service foreground n’a pas démarré.',
      'home_log_desktop_stop_requested': 'Arrêt du bot desktop demandé',
      'home_unknown_app': 'Inconnu',
      'home_status_online': 'En ligne',
      'home_status_offline': 'Hors ligne',
      'home_server_count_one': '{count} serveur',
      'home_server_count_other': '{count} serveurs',
      'home_stop': 'Arrêter',
      'home_start': 'Lancer',
      'home_manage': 'Gérer',
      'home_logs_tooltip': 'Logs du bot',

      'error': 'Erreur',
      'error_with_details': 'Erreur : {error}',
      'ok': 'OK',
      'close': 'Fermer',
      'copy': 'Copier',
      'delete': 'Supprimer',
      'cancel': 'Annuler',

      // Pages internes au bot — app/home.dart
      'bot_home_start': 'Lancer le bot',
      'bot_home_stop': 'Arrêter le bot',
      'bot_home_view_logs': 'Voir les logs du bot',
      'bot_home_view_stats': 'Voir les stats du bot',
      'bot_home_sync': 'Synchroniser l’app',
      'bot_home_sync_success': 'Application synchronisée avec succès',
      'bot_home_invite': 'Inviter le bot',
      'bot_home_invite_error': 'Impossible d’ouvrir le lien d’invitation',
      'bot_home_delete': 'Supprimer l’application',
      'bot_home_delete_confirm':
          'Êtes-vous sûr de vouloir supprimer cette application ?',
      'bot_home_start_error': 'Impossible de démarrer : {error}',
      'bot_home_log_start': 'Démarrage du bot demandé',
      'bot_home_log_stop': 'Arrêt du bot demandé',
      'bot_home_log_desktop_stop': 'Arrêt du bot desktop demandé',
      'bot_home_notif_required':
          'La permission de notification est requise pour lancer le service du bot.',
      'bot_home_service_not_started': 'Le service foreground n’a pas démarré.',

      // Pages internes au bot — app/settings.dart
      'bot_settings_title': 'Paramètres de l’application',
      'bot_settings_workflow_docs': 'Documentation des workflows',
      'bot_settings_workflow_docs_desc':
          'Guide détaillé sur les points d’entrée, arguments d’appel et comportement à l’exécution.',
      'bot_settings_app_flags': 'Indicateurs de l’application',
      'bot_settings_gateway_intents': 'Configuration des Gateway Intents',
      'bot_settings_gateway_intents_desc':
          'Sélectionnez les intents dont votre bot a besoin. Configurez-les sur le Discord Developer Portal.',
      'bot_settings_token_title': 'Token du bot',
      'bot_settings_update_token': 'Mettre à jour le token du bot',
      'bot_settings_token_hint': 'Entrez votre token de bot ici',
      'bot_settings_save_success': 'Paramètres enregistrés avec succès',
      'bot_settings_save_token_btn': 'Sauvegarder token et intents',
      'bot_settings_save_token_only_btn': 'Sauvegarder le token',
      'bot_settings_save_intents_btn': 'Sauvegarder les intents',
      'bot_settings_save_profile_status_btn': 'Sauvegarder profil et statuts',
      'bot_settings_save_token_caption':
          'Le token est protege. Cliquez d\'abord sur "Modifier le token", puis sauvegardez.',
      'bot_settings_save_intents_caption':
          'Cette action met a jour uniquement la configuration des intents.',
      'bot_settings_save_profile_caption':
          'Cette action applique le nom/avatar immediatement et enregistre la rotation des statuts.',
      'bot_settings_token_saved': 'Token sauvegarde avec succes',
      'bot_settings_intents_saved': 'Intents sauvegardes avec succes',
      'bot_settings_profile_saved': 'Profil/statuts appliqués avec succès',
      'bot_settings_edit_token_btn': 'Modifier le token',
      'bot_settings_cancel_token_edit_btn': 'Annuler la modification du token',
      'bot_settings_token_hidden_desc':
          'Le champ du token est masque par defaut pour plus de securite.',
      'bot_settings_token_required': 'Le token du bot est requis.',
      'bot_settings_save_token_first':
          'Veuillez d\'abord sauvegarder le token avant d\'appliquer les changements de profil/statuts.',
      'bot_settings_profile_title': 'Profil du bot',
      'bot_settings_username_override': 'Nom d\'utilisateur personnalisé',
      'bot_settings_username_hint':
          'Laisser vide pour conserver le nom d\'utilisateur actuel',
      'bot_settings_avatar_local_path': 'Chemin local de l\'avatar',
      'bot_settings_avatar_path_hint': '/chemin/absolu/vers/avatar.png',
      'bot_settings_browse': 'Parcourir',
      'bot_settings_avatar_selected_file': 'Fichier selectionne : {path}',
      'bot_settings_avatar_preview_label': "Apercu de l'avatar",
      'bot_settings_avatar_preview_error':
          'Impossible d\'afficher l\'aperçu de l\'image',
      'bot_settings_avatar_unsupported_format':
          'Format d\'avatar non supporte : {ext}. Formats supportes : {formats}.',
      'bot_settings_avatar_clear_selection': 'Effacer la selection',
      'bot_settings_status_rotation_title': 'Rotation des statuts',
      'bot_settings_status_rotation_desc':
          'Ajoutez un ou plusieurs statuts. Chaque statut nécessite un type, un texte et un intervalle min/max (secondes).',
      'bot_settings_add_status': 'Ajouter un statut',
      'bot_settings_status_item_title': 'Statut {index}',
      'bot_settings_remove_status': 'Supprimer le statut',
      'bot_settings_status_type_label': 'Type',
      'bot_settings_status_type_playing': 'Joue a',
      'bot_settings_status_type_streaming': 'Diffuse',
      'bot_settings_status_type_listening': 'Ecoute',
      'bot_settings_status_type_watching': 'Regarde',
      'bot_settings_status_type_competing': 'Participe',
      'bot_settings_status_text_label': 'Texte du statut',
      'bot_settings_status_min_interval': 'Intervalle min (s)',
      'bot_settings_status_max_interval': 'Intervalle max (s)',

      // Page logs du bot
      'bot_logs_title': 'Logs du bot',
      'bot_logs_disable_debug': 'Désactiver les logs debug',
      'bot_logs_enable_debug': 'Activer les logs debug',
      'bot_logs_copied': 'Logs copiés',
      'bot_logs_oldest_first': 'Afficher les plus anciens en premier',
      'bot_logs_newest_first': 'Afficher les plus récents en premier',
      'bot_logs_filter_count': 'Nombre de logs affichés',
      'bot_logs_show_n': 'Afficher {count} logs',
      'bot_logs_show_all': 'Afficher tout',
      'bot_logs_empty': 'Aucun log pour le moment',
      'bot_logs_show_more': 'Afficher plus',
      'bot_logs_show_less': 'Afficher moins',
      'bot_logs_ram': 'RAM du processus bot : {memory}',
      'bot_logs_go_to_latest': 'Aller au dernier log',
      'bot_logs_go_to_bottom': 'Aller en bas',

      // Page stats du bot
      'bot_stats_title': 'Statistiques du bot',
      'bot_stats_ram_process': 'RAM du processus bot',
      'bot_stats_ram_estimated': 'RAM bot uniquement (estimée)',
      'bot_stats_cpu': 'CPU du processus bot',
      'bot_stats_storage': 'Stockage du bot (données app)',
      'bot_stats_notes':
          'Notes : CPU disponible sur Android/Linux. Stockage = fichiers de données du bot dans l’application.',
      'bot_stats_collecting': 'Collecte…',

      // Page liste des commandes
      'commands_title': 'Commandes',
      'commands_empty': 'Aucune commande trouvée',
      'commands_error': 'Erreur : {error}',
      'commands_create_button': 'Créer une commande',

      // Page variables globales
      'globals_title': 'Variables globales',
      'globals_empty': 'Aucune variable globale pour le moment',
      'globals_add': 'Ajouter une variable',
      'globals_edit': 'Modifier une variable',
      'globals_key': 'Clé',
      'globals_value': 'Valeur',

      // Page workflows
      'workflows_title': 'Workflows',
      'workflows_empty': 'Aucun workflow pour le moment',
      'workflows_create': 'Créer un workflow',
      'workflows_edit': 'Modifier le workflow',
      'workflows_name': 'Nom du workflow',
      'workflows_entry_point': 'Point d’entrée par défaut',
      'workflows_entry_point_hint': 'Utilisé si l’appelant ne le remplace pas',
      'workflows_arguments': 'Arguments',
      'workflows_arg_name': 'Nom',
      'workflows_arg_default': 'Valeur par défaut',
      'workflows_arg_required_short': 'Req',
      'workflows_arg_hint':
          'Les arguments deviennent des variables runtime sous la forme ((arg.name)) et ((workflow.arg.name)).',
      'workflows_continue': 'Continuer',
      'workflows_add_arg': 'Ajouter un argument',
      'workflows_docs_tooltip': 'Documentation des workflows',
      'workflows_subtitle':
          '{count} action(s) • entrée : {entry} • args : {args}',

      // Page création de commande
      'cmd_error_fill_fields': 'Veuillez remplir tous les champs',
      'cmd_variables_title': 'Variables de la commande',
      'cmd_show_variables': 'Afficher les variables',
      'cmd_create_tooltip': 'Créer la commande',
      'cmd_delete_tooltip': 'Supprimer la commande',
      'cmd_editor_mode_title': 'Mode d’édition',
      'cmd_editor_mode_simple': 'Mode simplifié',
      'cmd_editor_mode_advanced': 'Mode avancé',
      'cmd_editor_mode_simple_desc':
          'Créez une commande rapidement avec des options guidées et des actions préconfigurées.',
      'cmd_editor_mode_advanced_desc':
          'Éditeur complet avec réponse personnalisée, options et builder d’actions.',
      'cmd_editor_mode_switch_adv': 'Passer en mode avancé',
      'cmd_editor_mode_switch_adv_title': 'Passer en mode avancé ?',
      'cmd_editor_mode_switch_adv_content':
          'Ce changement est définitif pour cette commande. Vous ne pourrez plus revenir au mode simplifié.',
      'cmd_editor_mode_switch_adv_confirm': 'Passer',
      'cmd_editor_mode_locked':
          'Le mode avancé est verrouillé pour cette commande.',
      'cmd_simple_actions_title': 'Actions simplifiées',
      'cmd_simple_actions_desc':
          'Sélectionnez ce que la commande doit faire. Les options sont générées automatiquement.',
      'cmd_simple_action_delete': 'Supprimer des messages',
      'cmd_simple_action_delete_desc':
          'Supprime des messages dans le salon courant (option /count).',
      'cmd_simple_action_kick': 'Expulser un utilisateur',
      'cmd_simple_action_kick_desc': 'Expulse le /user sélectionné du serveur.',
      'cmd_simple_action_ban': 'Bannir un utilisateur',
      'cmd_simple_action_ban_desc': 'Bannit le /user sélectionné du serveur.',
      'cmd_simple_action_mute': 'Rendre muet un utilisateur',
      'cmd_simple_action_mute_desc':
          'Rend temporairement muet le /user sélectionné.',
      'cmd_simple_action_add_role': 'Ajouter un rôle',
      'cmd_simple_action_add_role_desc':
          'Attribue le /role sélectionné au /user sélectionné.',
      'cmd_simple_action_remove_role': 'Retirer un rôle',
      'cmd_simple_action_remove_role_desc':
          'Retire le /role sélectionné du /user sélectionné.',
      'cmd_simple_action_send_message': 'Envoyer un message',
      'cmd_simple_action_send_message_desc':
          'Envoie un message supplémentaire dans le salon courant.',
      'cmd_simple_action_send_message_label': 'Message de l’action',
      'cmd_simple_action_send_message_hint':
          'Message envoyé par l’action Send Message',
      'cmd_simple_generated_options': 'Options de commande générées',
      'cmd_simple_generated_none':
          'Aucune option générée pour le moment. Sélectionnez au moins une action.',
      'cmd_simple_option_user': '/user (Utilisateur)',
      'cmd_simple_option_role': '/role (Rôle)',
      'cmd_simple_option_count': '/count (Entier)',
      'cmd_simple_option_user_desc': 'Utilisateur ciblé',
      'cmd_simple_option_role_desc': 'Rôle ciblé',
      'cmd_simple_option_count_desc': 'Nombre de messages à supprimer',
      'cmd_simple_response_title': 'Réponse finale',
      'cmd_simple_response_desc':
          'Message renvoyé à l’utilisateur après l’exécution des actions.',
      'cmd_simple_response_hint': 'Terminé ✅',
      'cmd_simple_response_embeds_title': 'Embeds de réponse',
      'cmd_simple_response_embeds_desc':
          'Embeds optionnels envoyés avec la réponse finale.',
      'cmd_simple_send_message_required':
          'Veuillez renseigner le message de l’action avant de sauvegarder.',

      // Support & communauté
      'support_card_title': 'Support & Communauté',
      'support_card_desc':
          'Une question, un bug, une suggestion ? Venez discuter avec l’équipe et la communauté.',
      'support_join_discord': 'Rejoindre le serveur Discord',
      'support_discord_badge': 'Support officiel',
      'home_empty_support_hint': 'Besoin d’aide pour commencer ?',
      'home_empty_support_btn': 'Rejoindre notre Discord',
    },
  };

  static String _get(String key, {AppLocale locale = AppLocale.en}) {
    return _translations[locale.code]?[key] ?? _translations['en']?[key] ?? key;
  }

  /// Get a translated string
  static String t(String key, {AppLocale? locale}) {
    return _get(key, locale: locale ?? _currentLocale);
  }

  static String tr(
    String key, {
    AppLocale? locale,
    Map<String, String> params = const {},
  }) {
    var value = t(key, locale: locale);
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }

  /// Current locale (defaults to system locale or English)
  static AppLocale _currentLocale = AppLocale.en;

  static AppLocale get currentLocale => _currentLocale;

  static void setCurrentLocale(AppLocale locale) {
    _currentLocale = locale;
  }

  /// List all available locales
  static List<AppLocale> get availableLocales => AppLocale.values;

  /// Detect system locale
  static AppLocale detectSystemLocale(Locale? systemLocale) {
    if (systemLocale == null) return AppLocale.en;

    final langCode = systemLocale.languageCode.toLowerCase();
    switch (langCode) {
      case 'fr':
        return AppLocale.fr;
      case 'en':
      default:
        return AppLocale.en;
    }
  }
}

/// Provider for managing app locale with ChangeNotifier
class LocaleProvider extends ChangeNotifier {
  static const String _key = 'app_locale';

  AppLocalePreference _preference = AppLocalePreference.system;
  AppLocale _locale = AppLocale.en;

  AppLocalePreference get preference => _preference;

  AppLocale get locale => _locale;

  LocaleProvider() {
    _locale = AppStrings.detectSystemLocale(
      ui.PlatformDispatcher.instance.locale,
    );
    AppStrings.setCurrentLocale(_locale);
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final savedPreference = AppLocalePreference.values.firstWhere(
      (value) => value.code == saved,
      orElse: () => AppLocalePreference.system,
    );

    await _applyPreference(savedPreference, persist: false, notify: true);
  }

  AppLocale _resolveLocale(AppLocalePreference preference) {
    switch (preference) {
      case AppLocalePreference.fr:
        return AppLocale.fr;
      case AppLocalePreference.en:
        return AppLocale.en;
      case AppLocalePreference.system:
        return AppStrings.detectSystemLocale(
          ui.PlatformDispatcher.instance.locale,
        );
    }
  }

  Future<void> _applyPreference(
    AppLocalePreference preference, {
    required bool persist,
    required bool notify,
  }) async {
    _preference = preference;
    _locale = _resolveLocale(preference);
    AppStrings.setCurrentLocale(_locale);

    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      if (preference == AppLocalePreference.system) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, preference.code);
      }
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> setPreference(AppLocalePreference preference) async {
    await _applyPreference(preference, persist: true, notify: true);
  }

  Future<void> resetToSystem() async {
    await _applyPreference(
      AppLocalePreference.system,
      persist: true,
      notify: true,
    );
  }
}
