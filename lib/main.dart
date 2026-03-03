import 'dart:async';
import 'dart:io';

import 'package:bot_creator/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:nyxx/nyxx.dart';
import "routes/home.dart";
import "routes/settings.dart";
import 'package:provider/provider.dart';
import 'routes/create.dart';
import 'utils/app_diagnostics.dart';
import 'utils/database.dart';
import 'utils/analytics.dart';

@pragma('vm:entry-point')
late AppManager appManager;
List<String> currentLogList = [];
@pragma('vm:entry-point')
List<NyxxGateway> gateways = [];
FirebaseApp? firebaseApp;

bool get _isFirebaseSupported {
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

bool get _isCrashlyticsSupported {
  if (kIsWeb) {
    return false;
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

Future<void> main() async {
  // On desktop platforms - especially Windows - the built-in certificate
  // bundle used by BoringSSL does not necessarily include all of the root
  // authorities that the operating system trusts.  This can lead to
  // `HandshakeException` errors such as the one shown in the screenshot:
  //
  //   CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate
  //
  // During development we don't want invalid certs to completely break the
  // app, so we install a global `HttpOverrides` that will allow an
  // insecure connection on Windows.  In release builds you should either
  // remove this override or supply the proper certificate to
  // `SecurityContext` instead of bypassing verification.
  HttpOverrides.global = _MyHttpOverrides();

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppDiagnostics.initialize();
      AppDiagnostics.installGlobalErrorHandlers();
      try {
        FlutterForegroundTask.initCommunicationPort();
        await AppDiagnostics.logInfo(
          'Foreground task communication initialized',
        );
      } catch (error, stack) {
        await AppDiagnostics.logError(
          'Foreground task communication initialization failed',
          error,
          stack,
          fatal: false,
        );
      }

      await _bootstrapAndRunApp();
    },
    (error, stack) async {
      await AppDiagnostics.logError(
        'Uncaught zone error during bootstrap/runtime',
        error,
        stack,
        fatal: true,
      );
    },
  );
}

/// An [HttpOverrides] implementation that accepts all certificates on
/// Windows.  We scope the change to Windows to avoid hiding real network
/// problems on other platforms where the system certificate store is
/// trusted.
class _MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    if (Platform.isWindows) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    }
    return client;
  }
}

Future<void> _bootstrapAndRunApp() async {
  var firebaseReady = false;

  if (_isFirebaseSupported) {
    try {
      await AppDiagnostics.logInfo(
        'Initializing Firebase',
        data: {'platform': defaultTargetPlatform.name},
      );
      firebaseApp = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout:
            () =>
                throw TimeoutException(
                  'Firebase initialization timed out after 10 seconds',
                ),
      );
      if (!firebaseApp!.isAutomaticDataCollectionEnabled) {
        await firebaseApp!.setAutomaticDataCollectionEnabled(true);
      }
      firebaseReady = true;
      await AppDiagnostics.logInfo('Firebase initialized');
    } catch (error, stack) {
      await AppDiagnostics.logError(
        'Firebase initialization failed',
        error,
        stack,
        fatal: false,
      );
    }
  }

  await AppDiagnostics.configureCrashlytics(
    crashlyticsSupported: _isCrashlyticsSupported,
    firebaseReady: firebaseReady,
  );

  try {
    await AppAnalytics.setCollectionEnabled(true);
  } catch (error, stack) {
    await AppDiagnostics.logError(
      'Analytics collection setup failed',
      error,
      stack,
      fatal: false,
    );
  }

  try {
    appManager = AppManager();
    runApp(
      ChangeNotifierProvider(create: (_) => ThemeProvider(), child: MyApp()),
    );
  } catch (error, stack) {
    await AppDiagnostics.logError(
      'Fatal startup error before runApp',
      error,
      stack,
      fatal: true,
    );
    runApp(StartupFailureApp(error: error.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    AppAnalytics.logAppOpen();
    return MaterialApp(
      title: 'Bot Creator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const MyMainPage(title: 'Bot Creator'),
    );
  }
}

class MyMainPage extends StatefulWidget {
  const MyMainPage({super.key, required this.title});
  final String title;

  @override
  State<MyMainPage> createState() => _MyMainPageState();
}

class _MyMainPageState extends State<MyMainPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingPage()),
              );
            },
          ),
        ],
      ),
      body: const HomePage(),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AppCreatePage()),
          );
        },
        backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class StartupFailureApp extends StatefulWidget {
  const StartupFailureApp({super.key, required this.error});

  final String error;

  @override
  State<StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<StartupFailureApp> {
  String _diagnostics = 'Loading diagnostics...';
  bool _copying = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    final text = await AppDiagnostics.readLog(maxLines: 200);
    if (!mounted) {
      return;
    }
    setState(() {
      _diagnostics = text;
    });
  }

  Future<void> _copyDiagnostics() async {
    setState(() {
      _copying = true;
    });
    try {
      await AppDiagnostics.copyLogToClipboard(maxLines: 300);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagnostics copied to clipboard')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _copying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bot Creator',
      home: Scaffold(
        appBar: AppBar(title: const Text('Startup Error')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bot Creator failed to start on this device.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(widget.error),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _copying ? null : _copyDiagnostics,
                    child: const Text('Copy diagnostics'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _loadDiagnostics,
                    child: const Text('Refresh diagnostics'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(_diagnostics),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
