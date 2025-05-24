import 'package:bot_creator/main.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:bot_creator/routes/app.dart';
import 'dart:developer' as developer;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    super.initState();
    // Log the opening of the home page
    FirebaseAnalytics.instance.logScreenView(
      screenName: "HomePage",
      screenClass: "HomePage",
    );
    FirebaseAnalytics.instance.logEvent(name: "home_page_opened");
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: StreamBuilder(
        stream: appManager.getAppStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            developer.log(
              "Error loading data: ${snapshot.error}",
              name: "HomePage",
            );
            return const Center(child: Text("Erreur de chargement"));
          }

          final apps = snapshot.data;
          if (apps == null || apps.isEmpty) {
            return const Center(child: Text("Aucune application trouvée"));
          }

          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              final name = app["name"]?.toString() ?? "Inconnu";
              final id = int.tryParse(app["id"].toString()) ?? 0;
              final avatar = app["avatar"]?.toString();

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      avatar != null
                          ? CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(avatar),
                          )
                          : const Icon(Icons.account_circle, size: 80),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => AppEditPage(appName: name, id: id),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text("Modifier"),
                          style: ElevatedButton.styleFrom(
                            shape: const StadiumBorder(),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
