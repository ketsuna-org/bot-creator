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
        Card(
          child: Container(
            height: 100,
            color: Colors.blue,
            child: Center(child: Text("Item $i")),
          ),
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
          crossAxisCount: 2,
        ),
        children: _listItems(20),
      ),
    );
  }
}
