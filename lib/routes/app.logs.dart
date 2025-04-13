import 'package:cardia_kexa/main.dart';
import 'package:flutter/material.dart';

class LogsPage extends StatefulWidget {
  final String? id;
  const LogsPage({super.key, this.id});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logs")),
      body: StreamBuilder(
        stream: appManager.getLogsStream(widget.id.toString()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          } else if (snapshot.hasData && snapshot.data!.isEmpty) {
            return const Text("No logs found");
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return ListView.builder(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              reverse: false,
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(snapshot.data![index]["log"] as String),
                  subtitle: Text(
                    snapshot.data![index]["createdAt"].toString().substring(
                      0,
                      19,
                    ),
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            return Text("Error: ${snapshot.error}");
          }
          return const Text("No logs found");
        },
      ),
    );
  }
}
