import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AppAnalytics {
  static bool get _isSupported {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return false;
      default:
        return false;
    }
  }

  static Future<void> setCollectionEnabled(bool enabled) async {
    if (!_isSupported) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    } catch (_) {}
  }

  static Future<void> logAppOpen() async {
    if (!_isSupported) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logAppOpen();
    } catch (_) {}
  }

  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {
    if (!_isSupported) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
        parameters: parameters,
      );
    } catch (_) {}
  }

  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!_isSupported) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {}
  }
}
