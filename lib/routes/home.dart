import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Widget> _listItems(int amount) {
    List<Widget> items = [];
    for (int i = 0; i < amount; i++) {
      items.add(
        Column(
          children: [
            Container(
              width: 100,
              height: 100,
              color: Colors.blue,
              child: Center(
                child: Text(
                  "Item $i",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text("Description"),
          ],
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GridView(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.sizeOf(context).width ~/ 150,
        ),
        children: _listItems(MediaQuery.sizeOf(context).width ~/ 150 * 10),
      ),
    );
  }
}
