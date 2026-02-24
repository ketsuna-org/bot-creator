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
        title: Text("Commands"),
        centerTitle: true,
      ),
      body: Scrollable(
        controller: ScrollController(),
        viewportBuilder:
            (context, position) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    FutureBuilder(
                      future: getCommands(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator(
                            strokeAlign: 0.5,
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Text("Error: ${snapshot.error}");
                        } else {
                          final commands = snapshot.data;

                          if (commands!.isEmpty) {
                            return const Text("No commands found");
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: commands.length,
                            scrollDirection: Axis.vertical,
                            controller: ScrollController(),
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              return ListTile(
                                trailing: const Icon(
                                  Icons.arrow_forward_ios_outlined,
                                ),
                                title: Text(
                                  commands[index].name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  commands[index].description,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                onTap: () {
                                  // Handle command tap
                                  final command = commands[index];
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
                              );
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommandCreatePage(client: client),
                ),
              ),
            },
        label: Text("Create Command"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
