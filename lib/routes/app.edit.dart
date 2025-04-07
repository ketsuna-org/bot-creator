import 'package:flutter/material.dart';

class AppEditPage extends StatefulWidget {
  final String appName;
  const AppEditPage({super.key, this.appName = "App Name"});

  @override
  State<AppEditPage> createState() => _AppEditPageState();
}

class _AppEditPageState extends State<AppEditPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit ${widget.appName}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              // Handle save action
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Edit ${widget.appName}"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Handle button press
              },
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
