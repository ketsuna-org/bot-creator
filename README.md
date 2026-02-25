# Cardia Kexa

Cardia Kexa is a Flutter Application with a focus on everything. We create what we want, when we want.

This App doesn't rely on a particular backend or API. It is a collection of various features and functionalities that we find interesting and useful.
It is a playground for us to experiment with different technologies and frameworks, and to showcase our skills as developers.
We are constantly adding new features and improving existing ones, so stay tuned for updates!

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Google Drive Setup](#google-drive-setup)
- [Confidentiality](#confidentiality)

## Features

- **Flutter**: The app is built using Flutter, a popular open-source UI software development toolkit created by Google. It allows for fast development and beautiful UIs.

- **Dart**: The programming language used for building the app. Dart is easy to learn and provides a modern programming experience.

- **SQLite**: The app uses SQLite for local data storage. SQLite is a lightweight, serverless database engine that is perfect for mobile applications.

## Installation

To install the app, follow these steps:

- Clone the repository:
```bash
git clone git@github.com:ketsuna-org/cardia_kexa.git
```

- Navigate to the project directory:
```bash
cd cardia_kexa
```

- Install the dependencies:
```bash
flutter pub get
```

- Run the app:
```bash
flutter run
```

## Google Drive Setup

Google Drive sync now supports Android, iOS, Windows and Linux, but each platform needs OAuth setup.

### 1) Google Cloud Console

- Enable **Google Drive API**.
- Configure **OAuth consent screen**.
- Add test users if your app is still in Testing mode.

Create OAuth clients:

- **Android client** (package name + SHA fingerprints).
- **iOS client** (bundle id must match `PRODUCT_BUNDLE_IDENTIFIER`).
- **Desktop client** (for Windows/Linux/Mac).

### 2) iOS mandatory config

You must add `ios/Runner/GoogleService-Info.plist` (from Firebase/Google setup) to the Runner target.

Then add URL scheme in `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
	<dict>
		<key>CFBundleTypeRole</key>
		<string>Editor</string>
		<key>CFBundleURLSchemes</key>
		<array>
			<string>REVERSED_CLIENT_ID</string>
		</array>
	</dict>
</array>
```

Replace `REVERSED_CLIENT_ID` with the value from your `GoogleService-Info.plist`.

### 3) Desktop mandatory config (Windows/Linux/Mac)

Run Flutter with your desktop OAuth client ID:

```bash
flutter run -d windows --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com
```

Linux example:

```bash
flutter run -d linux --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com
```

Optional (mobile explicit client IDs):

```bash
--dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
--dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_SERVER_CLIENT_ID.apps.googleusercontent.com
```

### 4) Behavior by platform

- Android/iOS: uses Google Sign-In native flow.
- Windows/Linux/Mac: opens browser OAuth flow and returns to app using localhost callback.

### 5) Android troubleshooting (Google Sign-In fails)

If Android login fails with `ApiException: 10`, `DEVELOPER_ERROR`, or `sign_in_failed`:

1. Verify Android package name in Firebase app exactly matches:
	- `android/app/build.gradle.kts` -> `applicationId`
	- `android/app/google-services.json` -> `client[].client_info.android_client_info.package_name`
2. Add both SHA fingerprints to Firebase Android app settings:
	- Debug SHA-1/SHA-256 (for `flutter run`)
	- Release SHA-1/SHA-256 (for release APK/AAB)
3. Download a fresh `google-services.json` and replace `android/app/google-services.json`.
4. Rebuild from clean state:

```bash
flutter clean
flutter pub get
flutter run -d android
```

Useful command for debug keystore SHA values:

```bash
keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore -storepass android -keypass android
```

## Confidentiality

This project does not collect or store any personal data. All data is stored locally on the device using SQLite, and no data is sent to any external servers or APIs.
The app does not require any special permissions.

We need to connect to Google Drive API to store User data, but this is not implemented yet. The app is designed to be used online and offline, but the online features are not fully implemented yet.
The app use Nyxx to connect to Discord API.

We rely on Google drive to store Bot Tokens, Commands data and other sensitive informations, what's actually used is only your Google Drive account, and the app will ask you to connect to your Google Drive account when you first run the "backup" feature.

## Contributing

This project is not open for contributions, as it is a personal project. However, if you have any suggestions or feedback, feel free to reach out to me.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
## Contact

No contact information is provided, as this is a personal project. However, if you have any questions or feedback, feel free to reach out to me through the GitHub repository.

## Acknowledgements

- Thanks to the Flutter and Dart communities for their amazing work and support.
- Thanks to the SQLite community for providing a lightweight and powerful database engine.
- Thanks to the open-source community for their contributions and inspiration.

## Disclaimer

This project is not affiliated with or endorsed by any of the technologies or frameworks mentioned in this README. All trademarks and copyrights are the property of their respective owners.
This project is for educational and personal use only. Use it at your own risk.
