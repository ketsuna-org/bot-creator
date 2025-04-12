import 'package:cardia_kexa/main.dart';
import 'package:cardia_kexa/utils/bot.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

class CommandCreatePage extends StatefulWidget {
  final NyxxRest? client;
  final Snowflake id;
  const CommandCreatePage({super.key, this.client, this.id = Snowflake.zero});

  @override
  State<CommandCreatePage> createState() => _CommandCreatePageState();
}

class _CommandCreatePageState extends State<CommandCreatePage> {
  String _commandName = "";
  String _commandDescription = "";
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _init();
    // Initialize any necessary data or state
  }

  _init() async {
    // first let's check if the command is already created or not
    if (!widget.id.isZero) {
      final command = await widget.client?.commands.fetch(widget.id);
      if (command != null) {
        // let's add the command to the database
        await appManager.addCommand(command.id.toString(), {
          "name": command.name,
          "description": command.description,
          "id": command.id.toString(),
          "applicationId": command.applicationId.toString(),
          "createdAt": DateTime.now().toIso8601String(),
        });
        setState(() {
          _commandName = command.name;
          _commandDescription = command.description;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  _updateOrCreate() async {
    // check if any field is empty
    if (_commandName.isEmpty || _commandDescription.isEmpty) {
      final dialog = AlertDialog(
        title: const Text("Error"),
        content: const Text("Please fill all fields"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("OK"),
          ),
        ],
      );
      showDialog(context: context, builder: (context) => dialog);
      return;
    }

    final client = widget.client;
    if (client == null) {
      // Handle error: client is null
      return;
    }
    try {
      if (widget.id.isZero) {
        // Create a new command
        await createCommand(client, _commandName, _commandDescription);
      } else {
        // Update the existing command
        await updateCommand(
          client,
          widget.id,
          name: _commandName,
          description: _commandDescription,
        );
      }
      Navigator.pop(context);
    } catch (e) {
      // Handle error
      final errorText = e.toString();
      final dialog = AlertDialog(
        title: const Text("Error"),
        content: Text(errorText),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("OK"),
          ),
        ],
      );
      showDialog(context: context, builder: (context) => dialog);
    }
  }

  String? _validateName(String? value) {
    if (value!.isEmpty) {
      return "Please enter a command name";
    }
    if (value.length < 3) {
      return "Command name must be at least 3 characters long";
    }
    if (value.length > 32) {
      return "Command name must be at most 32 characters long";
    }
    if (value.contains(" ")) {
      return "Command name cannot contain spaces";
    }
    if (value.contains(RegExp(r'[^a-zA-Z0-9_]'))) {
      return "Command name can only contain letters, numbers, and underscores";
    }
    if (value.startsWith("_")) {
      return "Command name cannot start with an underscore";
    }
    if (value.startsWith("!")) {
      return "Command name cannot start with an exclamation mark";
    }
    if (value.startsWith("/")) {
      return "Command name cannot start with a slash";
    }
    if (value.startsWith("#")) {
      return "Command name cannot start with a hash";
    }
    if (value.startsWith("@")) {
      return "Command name cannot start with an at sign";
    }
    if (value.startsWith("&")) {
      return "Command name cannot start with an ampersand";
    }
    if (value.startsWith("%")) {
      return "Command name cannot start with a percent sign";
    }
    return null; // No error
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(
              widget.id.isZero ? Icons.cancel : Icons.save,
            ), // Change icon based on command existence
            onPressed: () {
              if (widget.id.isZero) {
                Navigator.pop(context);
                // Handle cancel action
                // You can implement the logic to cancel the command creation here
              } else {
                _updateOrCreate();
                // Handle save action
                // You can implement the logic to save the command here
              }
              // Handle save action
              // You can implement the logic to save the command here
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              widget.id.isZero ? "Create a new Command" : "Update Command",
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      autocorrect: false,
                      validator: _validateName,
                      initialValue: _commandName,
                      decoration: InputDecoration(
                        labelText: "Command Name",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _commandName = value;
                        });
                        // Handle command name input
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      autocorrect: false,
                      initialValue: _commandDescription,
                      decoration: InputDecoration(
                        labelText: "Command Description",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _commandDescription = value;
                        });
                        // Handle command description input
                      },
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          _updateOrCreate();
                          // Form is valid, proceed with command creation
                        } else {
                          // Form is invalid, show error message
                          final dialog = AlertDialog(
                            title: const Text("Error"),
                            content: const Text("Please fill all fields"),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text("OK"),
                              ),
                            ],
                          );
                          showDialog(
                            context: context,
                            builder: (context) => dialog,
                          );
                        }
                        // Handle command creation logic
                      },
                      child:
                          widget.id.isZero
                              ? const Text("Create Command")
                              : const Text("Update Command"),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
