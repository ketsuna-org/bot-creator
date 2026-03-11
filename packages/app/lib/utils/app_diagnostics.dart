import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppDiagnostics {
  static bool _initialized = false;
  static bool _crashlyticsEnabled = false;
  static bool _firebaseReady = false;
  static File? _logFile;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    try {
      final docs = await getApplicationDocumentsDirectory();
      final diagnosticsDir = Directory('${docs.path}/diagnostics');
      if (!await diagnosticsDir.exists()) {
        await diagnosticsDir.create(recursive: true);
      }
      _logFile = File('${diagnosticsDir.path}/startup_diagnostics.log');
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
      await logInfo(
        'Diagnostics initialized',
        data: {
          'platform': defaultTargetPlatform.name,
          'mode':
              kReleaseMode
                  ? 'release'
                  : kProfileMode
                  ? 'profile'
                  : 'debug',
        },
      );
    } catch (error, stack) {
      debugPrint('Failed to initialize diagnostics storage: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  static Future<void> configureCrashlytics({
    required bool crashlyticsSupported,
    required bool firebaseReady,
  }) async {
    _crashlyticsEnabled = crashlyticsSupported && firebaseReady;
    _firebaseReady = firebaseReady;
    await logInfo(
      'Crashlytics configuration',
      data: {
        'supported': crashlyticsSupported,
        'firebaseReady': firebaseReady,
        'enabled': _crashlyticsEnabled,
      },
    );

    if (!_crashlyticsEnabled) {
      return;
    }

    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      await FirebaseCrashlytics.instance.setCustomKey(
        'app_platform',
        defaultTargetPlatform.name,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'app_mode',
        kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug',
      );
    } catch (error, stack) {
      await logError(
        'Failed to configure Crashlytics collection',
        error,
        stack,
        fatal: false,
      );
    }
  }

  static void installGlobalErrorHandlers() {
    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // Keep default debug error surface (red screen + console) so startup
      // issues are visible instead of silently rendering a blank frame.
      FlutterError.presentError(details);
      previousFlutterOnError?.call(details);
      unawaited(recordFlutterError(details, fatal: true));
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(logError('Uncaught platform error', error, stack, fatal: true));
      return true;
    };
  }

  static Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    required bool fatal,
  }) async {
    await logError(
      'Flutter framework error',
      details.exception,
      details.stack ?? StackTrace.current,
      fatal: fatal,
      reason: details.context?.toDescription(),
      information: details.informationCollector
          ?.call()
          .map((item) => item.toString())
          .join(' | '),
    );
  }

  static Future<void> logInfo(
    String message, {
    Map<String, Object?>? data,
  }) async {
    final payload =
        StringBuffer()
          ..write('[${DateTime.now().toIso8601String()}] INFO: $message');
    if (data != null && data.isNotEmpty) {
      payload.write(' | ${_toInlineData(data)}');
    }
    await _appendLine(payload.toString());
  }

  static Future<void> logError(
    String message,
    Object error,
    StackTrace stack, {
    required bool fatal,
    String? reason,
    String? information,
  }) async {
    final payload =
        StringBuffer()
          ..write('[${DateTime.now().toIso8601String()}] ')
          ..write(fatal ? 'FATAL' : 'ERROR')
          ..write(': $message')
          ..write(' | error=$error');
    if (reason != null && reason.isNotEmpty) {
      payload.write(' | reason=$reason');
    }
    if (information != null && information.isNotEmpty) {
      payload.write(' | info=$information');
    }
    payload.write(' | stack=$stack');
    await _appendLine(payload.toString());

    if (!_crashlyticsEnabled || !_firebaseReady) {
      return;
    }

    try {
      final crashInformation =
          information == null
              ? const <Object>[]
              : <Object>[DiagnosticsNode.message(information)];
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason ?? message,
        information: crashInformation,
        fatal: fatal,
      );
    } catch (recordError, recordStack) {
      await _appendLine(
        '[${DateTime.now().toIso8601String()}] ERROR: Failed to send Crashlytics event | '
        'error=$recordError | stack=$recordStack',
      );
    }
  }

  static Future<String> readLog({int maxLines = 250}) async {
    if (_logFile == null || !await _logFile!.exists()) {
      return 'No diagnostics log found yet.';
    }
    final lines = await _logFile!.readAsLines();
    if (lines.length <= maxLines) {
      return lines.join('\n');
    }
    return lines.sublist(lines.length - maxLines).join('\n');
  }

  static Future<void> clearLog() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return;
    }
    await _logFile!.writeAsString('');
    await logInfo('Diagnostics log cleared');
  }

  static Future<void> copyLogToClipboard({int maxLines = 250}) async {
    final text = await readLog(maxLines: maxLines);
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> _appendLine(String line) async {
    debugPrint(line);
    if (_logFile == null) {
      return;
    }
    try {
      await _logFile!.writeAsString('$line\n', mode: FileMode.append);
    } catch (_) {}
  }

  static String _toInlineData(Map<String, Object?> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join(', ');
  }
}
