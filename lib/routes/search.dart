import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String searchedValue = "";

  void _onChanged(String value) {
    setState(() {
      searchedValue = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SearchBar(hintText: "Search", onChanged: _onChanged),
          const SizedBox(height: 20),
          Text(
            "Searched value: $searchedValue",
            style: const TextStyle(fontSize: 20),
          ),
        ],
      ),
    );
  }
}
