import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/app.commands.dart';
import 'package:bot_creator/routes/app/app.home.dart';
import 'package:bot_creator/routes/app/app.settings.dart';
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

  _init() async {
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
    if (client != null) AppSettingsPage(client: client!),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
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
