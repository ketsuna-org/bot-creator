# Bot Creator

`Bot Creator` is a Flutter app to create, configure, run, and monitor Discord bots locally.

It provides a visual builder for slash commands, interaction responses, reusable workflows, and action pipelines, plus local persistence and Google Drive backup/restore.

## What this app actually does

- Manages multiple Discord bot apps (store token + metadata per bot)
- Connects to Discord REST and Gateway using `nyxx`
- Creates and edits slash commands
- Builds rich command responses:
  - text responses
  - embeds
  - component-based responses (buttons/selects)
  - modal responses
  - conditional response logic
- Executes action chains on interactions (message/channel/moderation/webhook/etc.)
- Supports global variables and reusable workflows
- Runs bots:
  - on Android/iOS via foreground service
  - on desktop (Windows/Linux/macOS) in-process
- Shows runtime logs and basic bot resource stats (RAM/CPU/storage)
- Exports/imports local app data to Google Drive AppData folder

## Tech stack

- Flutter + Dart
- `nyxx` (Discord API)
- Local JSON-based persistence in app documents directory
- Google Drive API (`googleapis`, `google_sign_in`, OAuth flow)
- Firebase (Core, Analytics, Crashlytics, Performance where supported)

## Project name and old references

This repository/project is named `bot_creator` and the product name in the UI is **Bot Creator**.

You may still see legacy identifiers like `cardia_kexa` in package IDs or internal strings (Android package namespace, desktop app id, logger names). They are historical leftovers, not the app name.

## Supported platforms

- Android
- iOS
- Windows
- Linux
- macOS (code paths exist; verify local build config before release)

## Getting started

### Prerequisites

- Flutter SDK (matching the repo’s Flutter/Dart constraints)
- A Discord bot token (from Discord Developer Portal)
- Optional: Firebase setup files for analytics/crash reporting
- Optional: Google OAuth credentials for Drive backup/restore

### Run locally

```bash
flutter pub get
flutter run
```

## Typical usage flow

1. Add a bot token in **Create a new App**
2. Open the bot workspace
3. Configure command(s) and response/workflow behavior
4. Start the bot runtime (mobile service or desktop runtime)
5. Test interactions in Discord
6. Monitor logs/stats inside the app
7. Export data to Google Drive if needed

## Data storage model

Bot Creator stores data locally under the app documents directory, including:

- bot/app metadata
- command configs
- workflows
- global variables
- logs and runtime-related app data

Backup/restore syncs this app data structure to Google Drive `appDataFolder`.

## Google Drive backup/restore

The app supports two auth modes:

- **Mobile (Android/iOS):** native Google Sign-In flow
- **Desktop:** browser-based OAuth with localhost callback

Desktop supports `--dart-define` overrides for OAuth values (for example client id/secret) when needed by your environment.

## Security notes

- Bot tokens are sensitive secrets; treat exported data carefully.
- Avoid committing local credentials or generated auth files.
- Review platform-specific OAuth/Firebase config before distribution.

## Current limitations

- No dedicated backend service; logic is local-first
- Local persistence is JSON-file based (not relational DB)
- Some UI/log messages are currently French/English mixed
- Legacy internal naming may still appear in non-user-facing code paths

## Development notes

- Main entrypoint: `lib/main.dart`
- App/workspace navigation: `lib/routes/`
- Discord runtime + command handling: `lib/utils/bot.dart`
- Action system: `lib/actions/` and `lib/types/action.dart`
- Persistence: `lib/utils/database.dart`
- Drive sync: `lib/utils/drive.dart`

## License

No license file is currently included in this repository.

