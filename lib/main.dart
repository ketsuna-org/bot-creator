import "package:cardia_kexa/database.dart";
import 'package:flutter/material.dart';
import "routes/home.dart";
import "routes/profile.dart";
import 'package:provider/provider.dart';

import "routes/search.dart";

late DatabaseProvider db;
Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  db = DatabaseProvider();

  runApp(
    ChangeNotifierProvider(create: (_) => ThemeProvider(), child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cardia Kexa',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const MyMainPage(title: 'Cardia Kexa'),
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
  int _indexSelected = 0;
  static const List<Widget> _widgetOptions = <Widget>[
    HomePage(),
    SearchPage(),
    ProfilePage(),
  ];
  void _onItemTapped(int index) {
    setState(() {
      _indexSelected = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    TargetPlatform platform =
        Theme.of(context).platform; // Get the current platform
    BottomNavigationBar bottomAppBar = BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      onTap: _onItemTapped,
      currentIndex: _indexSelected,
    );

    // should we return either a Drawer or a BottomNavigationBar?

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
        title: Text(widget.title),
      ),
      body: Center(child: _widgetOptions.elementAt(_indexSelected)),
      bottomNavigationBar:
          platform == TargetPlatform.android || platform == TargetPlatform.iOS
              ? bottomAppBar
              : null,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      floatingActionButton:
          _indexSelected == 0
              ? FloatingActionButton(
                onPressed: () {
                  AlertDialog dialog = AlertDialog(
                    title: const Text("Add new item"),
                    content: const Text("Do you want to add a new item?"),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          db.deleteApp(name: "New App"); // Example action
                          Navigator.of(context).pop(); // Close the dialog
                        },
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () async {
                          // Add your action here
                          await db.addApp("New App");
                          Navigator.of(context).pop(); // Close the dialog
                        },
                        child: const Text("Add"),
                      ),
                    ],
                  );

                  showDialog(
                    context: context,
                    builder: (BuildContext context) => dialog,
                  );
                },
                backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
                child: const Icon(Icons.add),
              )
              : null,
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
