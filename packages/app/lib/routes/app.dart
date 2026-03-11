import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/commands.list.dart';
import 'package:bot_creator/routes/app/global.variables.dart';
import 'package:bot_creator/routes/app/home.dart';
import 'package:bot_creator/routes/app/settings.dart';
import 'package:bot_creator/routes/app/workflows.page.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

class AppEditPage extends StatefulWidget {
  final String appName;
  final int id;
  const AppEditPage({super.key, required this.appName, required this.id});

  @override
  State<AppEditPage> createState() => _AppEditPageState();
}

class _AppEditPageState extends State<AppEditPage>
    with TickerProviderStateMixin {
  NyxxRest? client; // Changez en nullable
  int _selectedIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<List<ApplicationCommand>> getCommands() async {
    if (client == null) {
      throw Exception("Client is not initialized");
    }
    final commands = await client!.commands.list();
    return commands;
  }

  Future<void> _init() async {
    await AppAnalytics.logScreenView(
      screenName: "AppEditPage",
      screenClass: "AppEditPage",
      parameters: {"app_name": widget.appName, "app_id": widget.id.toString()},
    );
    final app = await appManager.getApp(widget.id.toString());
    final token = app["token"];
    if (token != null) {
      client = await Nyxx.connectRest(token);
      setState(() {
        _isLoading = false;
        client = client;
      });
    }
  }

  List<Widget> get pageList => [
    if (client != null) AppHomePage(client: client!),
    if (client != null) AppCommandsPage(client: client!),
    if (client != null) GlobalVariablesPage(botId: client!.user.id.toString()),
    if (client != null) WorkflowsPage(botId: client!.user.id.toString()),
    if (client != null) AppSettingsPage(client: client!),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: "Commands",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.key), label: "Globals"),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_tree),
            label: "Workflows",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : pageList[_selectedIndex],
    );
  }
}
