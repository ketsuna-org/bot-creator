import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

class OptionWidget extends StatefulWidget {
  final Function(List<CommandOptionBuilder>) onChange; // Callback for changes

  final List<CommandOptionBuilder>? initialOptions;
  const OptionWidget({super.key, required this.onChange, this.initialOptions});

  @override
  _OptionWidgetState createState() => _OptionWidgetState();
}

class _OptionWidgetState extends State<OptionWidget> {
  final List<CommandOptionBuilder> options = [];

  final List<dynamic> optionTypes = [
    {'name': 'String', 'value': CommandOptionType.string},
    {'name': 'Integer', 'value': CommandOptionType.integer},
    {'name': 'Boolean', 'value': CommandOptionType.boolean},
    {'name': 'User', 'value': CommandOptionType.user},
    {'name': 'Channel', 'value': CommandOptionType.channel},
    {'name': 'Role', 'value': CommandOptionType.role},
    {'name': 'Mentionable', 'value': CommandOptionType.mentionable},
    {'name': 'Number', 'value': CommandOptionType.number},
    {'name': 'Attachment', 'value': CommandOptionType.attachment},
  ];

  final currentOption = CommandOptionBuilder(
    name: 'option',
    description: 'Description for current option',
    type: CommandOptionType.string,
    isRequired: false,
  );

  addOption() {
    // let's check if currentOption has everything we need
    if (currentOption.name.isEmpty || currentOption.description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    // Check if the option already exists
    for (var option in options) {
      if (option.name == currentOption.name) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Option with this name already exists')),
        );
        return;
      }
    }

    // Add the new option to the list
    setState(() {
      options.add(
        CommandOptionBuilder(
          name: 'option${options.length + 1}',
          description: 'Description for option ${options.length + 1}',
          type: CommandOptionType.string,
          isRequired: false,
        ),
      );
      _updateWidget(); // Trigger the callback
    });
  }

  void _updateWidget() {
    // Notify the parent widget of changes
    widget.onChange(options);
  }

  String? _validatorName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a name for the option';
    }

    // we also need to check if the name is already used
    int count = 0;
    for (var option in options) {
      if (option.name == value) {
        count++;
      }
    }
    if (count > 1) {
      return 'This name is already used';
    }

    // check if it goes well with this regex : ^[-_'\p{L}\p{N}\p{sc=Deva}\p{sc=Thai}]{1,32}$
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

    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialOptions != null) {
      widget.initialOptions?.forEach((option) {
        options.add(option);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListView.builder(
            controller: ScrollController(),
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8.0),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              return Column(
                children: [
                  const Divider(color: Colors.grey, height: 2),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Option ${index + 1}',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            options.removeAt(index);
                            _updateWidget(); // Trigger the callback
                          });
                        },
                      ),
                    ],
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Option Name',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: options[index].name,
                    validator: _validatorName,
                    maxLength: 32,
                    onChanged: (value) {
                      setState(() {
                        options[index].name = value;
                        _updateWidget(); // Trigger the callback
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Option Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 100,
                    maxLines: 2,
                    minLines: 1,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a description for the option';
                      }
                      return null;
                    },
                    initialValue: options[index].description,
                    onChanged: (value) {
                      setState(() {
                        options[index].description = value;
                        _updateWidget(); // Trigger the callback
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Option Type'),
                      const Spacer(),
                      DropdownButton<dynamic>(
                        value: options[index].type,

                        onChanged: (newValue) {
                          setState(() {
                            options[index].type = newValue;
                            _updateWidget(); // Trigger the callback
                          });
                        },
                        items:
                            optionTypes.map((type) {
                              return DropdownMenuItem(
                                value: type['value'],
                                child: Text(type['name']),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    title: const Text('Is Required'),
                    value: options[index].isRequired ?? false,
                    onChanged: (bool? value) {
                      setState(() {
                        options[index].isRequired = value ?? false;
                        _updateWidget(); // Trigger the callback
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  if (options[index].choices?.isNotEmpty ?? false)
                    ListView.builder(
                      controller: ScrollController(),
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8.0),
                      shrinkWrap: true,
                      itemCount: options[index].choices?.length,
                      itemBuilder: (context, choiceIndex) {
                        return Column(
                          children: [
                            const Divider(color: Colors.grey, height: 2),
                            Row(
                              children: [
                                Text(
                                  'Choice ${choiceIndex + 1}',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setState(() {
                                      options[index].choices!.removeAt(
                                        choiceIndex,
                                      );
                                      _updateWidget(); // Trigger the callback
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Choice Name',
                                border: OutlineInputBorder(),
                              ),
                              initialValue:
                                  options[index].choices![choiceIndex].name,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a name for the choice';
                                }
                                return null;
                              },
                              maxLength: 100,
                              onChanged: (value) {
                                setState(() {
                                  options[index].choices![choiceIndex].name =
                                      value;
                                  _updateWidget(); // Trigger the callback
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).nextFocus();
                              },
                              decoration: const InputDecoration(
                                labelText: 'Choice Value',
                                border: OutlineInputBorder(),
                              ),
                              maxLength: 100,
                              maxLines: 2,
                              minLines: 1,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a value for the choice';
                                }
                                return null;
                              },
                              initialValue:
                                  options[index].choices![choiceIndex].value,
                              onChanged: (value) {
                                setState(() {
                                  options[index].choices![choiceIndex].value =
                                      value;
                                  _updateWidget(); // Trigger the callback
                                });
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (options[index].choices == null) {
                          options[index].choices = [];
                        }
                        options[index].choices?.add(
                          CommandOptionChoiceBuilder(
                            name:
                                'Choice ${options[index].choices!.length + 1}',
                            value:
                                'Value ${options[index].choices!.length + 1}',
                          ),
                        );
                        _updateWidget(); // Trigger the callback
                      });
                    },
                    child: const Text('Add Choice'),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          if (options.length < 25)
            ElevatedButton(
              onPressed: addOption,
              child: const Text('Add Option'),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
