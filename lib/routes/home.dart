import 'package:cardia_kexa/main.dart';
import 'package:flutter/material.dart';
import 'package:cardia_kexa/routes/app.edit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: StreamBuilder<List<Map<String, Object?>>>(
        stream: appManager.getAppsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text("Error loading data"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No data found"));
          } else {
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Icon(Icons.apps_rounded, color: Colors.blue, size: 64),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.data![index]["name"].toString(),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => AppEditPage(
                                    appName:
                                        snapshot.data![index]["name"]
                                            .toString(),
                                    id:
                                        int.tryParse(
                                          snapshot.data![index]["id"]
                                              .toString(),
                                        ) ??
                                        0,
                                  ),
                            ),
                          );
                        },
                        child: const Text("Open"),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
