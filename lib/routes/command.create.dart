import 'package:cardia_kexa/main.dart';
import 'package:cardia_kexa/utils/bot.dart';
import 'package:cardia_kexa/widgets/option_widget.dart';
import 'package:cbl/cbl.dart';
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
  List<CommandOptionBuilder> _options = [];
  String _response = "";
  bool _isLoading = true;
  List<ApplicationIntegrationType> _integrationTypes = [
    ApplicationIntegrationType.guildInstall,
  ];
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
      // check if we also have the command in the database
      final commandData = await appManager.getCommand(widget.id.toString());
      if (commandData != null) {
        // let's set the command data to the fields
        final data = commandData
            .value<Dictionary>("data")
            ?.value<Dictionary>("data");
        if (data != null) {
          setState(() {
            _response = data.string("response") ?? "";
          });
        }
      }
      if (command != null) {
        if (commandData == null) {
          // command does not exist in the database so let's add it
          await appManager.addCommand(command.id.toString(), {
            "name": command.name,
            "description": command.description,
            "id": command.id.toString(),
            "applicationId": command.applicationId.toString(),
            "createdAt": DateTime.now().toIso8601String(),
          });
        }
        setState(() {
          _commandName = command.name;
          _commandDescription = command.description;
          if (command.options != null) {
            _options =
                command.options!.map((e) {
                  final option = CommandOptionBuilder(
                    type: e.type,
                    name: e.name,
                    description: e.description,
                    isRequired: e.isRequired,
                  );
                  if (e.choices?.isNotEmpty ?? false) {
                    option.choices =
                        e.choices?.map((choice) {
                          return CommandOptionChoiceBuilder(
                            name: choice.name,
                            value: choice.value,
                          );
                        }).toList();
                  }
                  return option;
                }).toList();
          } else {
            _options = [];
          }
          _integrationTypes =
              command.integrationTypes.map((e) {
                if (e == ApplicationIntegrationType.guildInstall) {
                  return ApplicationIntegrationType.guildInstall;
                } else if (e == ApplicationIntegrationType.userInstall) {
                  return ApplicationIntegrationType.userInstall;
                } else {
                  return ApplicationIntegrationType.guildInstall;
                }
              }).toList();
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
        final commandBuilder = ApplicationCommandBuilder(
          name: _commandName,
          description: _commandDescription,
          type: ApplicationCommandType.chatInput,
        );

        commandBuilder.integrationTypes = _integrationTypes;
        if (_options.isNotEmpty) {
          commandBuilder.options = _options;
        }
        await createCommand(
          client,
          commandBuilder,
          data: {"response": _response},
        );
      } else {
        // Update the existing command
        final commandBuilder = ApplicationCommandUpdateBuilder(
          name: _commandName,
          description: _commandDescription,
        );
        commandBuilder.integrationTypes = _integrationTypes;
        if (_options.isNotEmpty) {
          commandBuilder.options = _options;
        } else {
          commandBuilder.options = [];
        }

        await updateCommand(
          client,
          widget.id,
          commandBuilder: commandBuilder,
          data: {"response": _response},
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
          if (!widget.id.isZero)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await widget.client?.commands.delete(widget.id);
                await appManager.removeCommand(widget.id.toString());
                Navigator.pop(context);
                // Handle delete action
                // You can implement the logic to delete the command here
              },
            ),
        ],
      ),
      body: Center(
        child: Scrollable(
          physics: const BouncingScrollPhysics(),
          scrollBehavior: const ScrollBehavior(),
          viewportBuilder:
              (context, position) => SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      widget.id.isZero
                          ? "Create a new Command"
                          : "Update Command",
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
                              maxLength: 32,
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
                              maxLength: 100,
                              maxLines: 3,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return "Please enter a command description";
                                }
                                if (value.length > 100) {
                                  return "Command description must be at most 100 characters long";
                                }
                                return null; // No error
                              },
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
                            const Text(
                              "Where this command can be used",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Checkbox(
                                  value: _integrationTypes.contains(
                                    ApplicationIntegrationType.guildInstall,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _integrationTypes.add(
                                          ApplicationIntegrationType
                                              .guildInstall,
                                        );
                                      } else {
                                        _integrationTypes.remove(
                                          ApplicationIntegrationType
                                              .guildInstall,
                                        );
                                      }
                                    });
                                  },
                                ),
                                const Text("Guild Install"),
                                const SizedBox(width: 20),
                                Checkbox(
                                  value: _integrationTypes.contains(
                                    ApplicationIntegrationType.userInstall,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _integrationTypes.add(
                                          ApplicationIntegrationType
                                              .userInstall,
                                        );
                                      } else {
                                        _integrationTypes.remove(
                                          ApplicationIntegrationType
                                              .userInstall,
                                        );
                                      }
                                    });
                                  },
                                ),
                                const Text("User Install"),
                                const SizedBox(width: 20),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Command Options",
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 10),
                            OptionWidget(
                              initialOptions: _options,
                              onChange: (options) {
                                setState(() {
                                  _options = options;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  0, // Replace with the actual number of options
                              itemBuilder: (context, index) {
                                return const Text(
                                  "Option",
                                ); // Replace with the actual option widget
                              },
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              autocorrect: false,
                              maxLength: 1000,
                              maxLines: 5,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              initialValue: _response,
                              decoration: InputDecoration(
                                labelText: "Command Response",
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _response = value;
                                });
                                // Handle command response input
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
                                    content: const Text(
                                      "Please fill all fields",
                                    ),
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
        ),
      ),
    );
  }
}
