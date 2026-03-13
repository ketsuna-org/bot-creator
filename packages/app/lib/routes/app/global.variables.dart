import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:flutter/material.dart';

class GlobalVariablesPage extends StatefulWidget {
  const GlobalVariablesPage({super.key, required this.botId});

  final String botId;

  @override
  State<GlobalVariablesPage> createState() => _GlobalVariablesPageState();
}

class _GlobalVariablesPageState extends State<GlobalVariablesPage> {
  Map<String, String> _variables = <String, String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await appManager.getGlobalVariables(widget.botId);
    if (!mounted) {
      return;
    }
    setState(() {
      _variables = Map<String, String>.from(values);
      _loading = false;
    });
  }

  Future<void> _editVariable({String? key}) async {
    final keyController = TextEditingController(text: key ?? '');
    final valueController = TextEditingController(
      text: key != null ? (_variables[key] ?? '') : '',
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            key == null
                ? AppStrings.t('globals_add')
                : AppStrings.t('globals_edit'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: InputDecoration(
                  labelText: AppStrings.t('globals_key'),
                  border: const OutlineInputBorder(),
                ),
                enabled: key == null,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueController,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: AppStrings.t('globals_value'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.t('app_save')),
            ),
          ],
        );
      },
    );

    if (save != true) {
      return;
    }

    final nextKey = keyController.text.trim();
    if (nextKey.isEmpty) {
      return;
    }

    await appManager.setGlobalVariable(
      widget.botId,
      nextKey,
      valueController.text,
    );
    await _load();
  }

  Future<void> _deleteVariable(String key) async {
    await appManager.removeGlobalVariable(widget.botId, key);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('globals_title'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editVariable(),
        child: const Icon(Icons.add),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _variables.isEmpty
              ? Center(child: Text(AppStrings.t('globals_empty')))
              : ListView.separated(
                itemCount: _variables.length,
                separatorBuilder:
                    (BuildContext context, int index) =>
                        const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = _variables.entries.elementAt(index);
                  return ListTile(
                    title: Text(entry.key),
                    subtitle: Text(
                      entry.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () => _editVariable(key: entry.key),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _deleteVariable(entry.key),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
