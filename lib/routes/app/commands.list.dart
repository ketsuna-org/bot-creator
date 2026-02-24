import 'package:bot_creator/routes/app/command.create.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

class AppCommandsPage extends StatefulWidget {
  final NyxxRest client;
  const AppCommandsPage({super.key, required this.client});

  @override
  State<AppCommandsPage> createState() => _AppCommandsPageState();
}

class _AppCommandsPageState extends State<AppCommandsPage>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    // Log the opening of the commands page
    AppAnalytics.logScreenView(
      screenName: "AppCommandsPage",
      screenClass: "AppCommandsPage",
      parameters: {"app_id": widget.client.application.id.toString()},
    );
  }

  @override
  Widget build(BuildContext context) {
    NyxxRest client = widget.client;

    Future<List<ApplicationCommand>> getCommands() async {
      final commands = await client.commands.list();
      return commands;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
        title: const Text("Commands"),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentMaxWidth = constraints.maxWidth >= 900 ? 760.0 : 640.0;
          return FutureBuilder(
            future: getCommands(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    strokeAlign: 0.5,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              final commands = snapshot.data ?? const <ApplicationCommand>[];
              if (commands.isEmpty) {
                return const Center(child: Text("No commands found"));
              }

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    itemCount: commands.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final command = commands[index];
                      return Card(
                        child: ListTile(
                          trailing: const Icon(
                            Icons.arrow_forward_ios_outlined,
                          ),
                          title: Text(
                            command.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            command.description,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => CommandCreatePage(
                                      client: client,
                                      id: command.id,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommandCreatePage(client: client),
            ),
          );
        },
        label: const Text("Create command"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
