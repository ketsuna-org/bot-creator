import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

class BasicInfoCard extends StatelessWidget {
  final String commandName;
  final String commandDescription;
  final List<ApplicationIntegrationType> integrationTypes;
  final List<InteractionContextType> contexts;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<List<ApplicationIntegrationType>>
  onIntegrationTypesChanged;
  final ValueChanged<List<InteractionContextType>> onContextsChanged;
  final String? Function(String?) nameValidator;

  const BasicInfoCard({
    super.key,
    required this.commandName,
    required this.commandDescription,
    required this.integrationTypes,
    required this.contexts,
    required this.onNameChanged,
    required this.onDescriptionChanged,
    required this.onIntegrationTypesChanged,
    required this.onContextsChanged,
    required this.nameValidator,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Command Info",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              "Basic metadata and availability",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, innerConstraints) {
                final isWide = innerConstraints.maxWidth >= 760;
                final nameField = TextFormField(
                  autocorrect: false,
                  validator: nameValidator,
                  initialValue: commandName,
                  maxLength: 32,
                  decoration: const InputDecoration(
                    labelText: "Name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: onNameChanged,
                );

                final descriptionField = TextFormField(
                  autocorrect: false,
                  maxLength: 100,
                  maxLines: 3,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter a command description";
                    }
                    if (value.length > 100) {
                      return "Command description must be at most 100 characters long";
                    }
                    return null;
                  },
                  initialValue: commandDescription,
                  decoration: const InputDecoration(
                    labelText: "Description",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: onDescriptionChanged,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: nameField),
                          const SizedBox(width: 12),
                          Expanded(child: descriptionField),
                        ],
                      )
                    else ...[
                      nameField,
                      const SizedBox(height: 12),
                      descriptionField,
                    ],
                    const SizedBox(height: 8),
                    Text(
                      "Where this command can be used",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: integrationTypes.contains(
                                ApplicationIntegrationType.guildInstall,
                              ),
                              onChanged: (value) {
                                final newTypes =
                                    List<ApplicationIntegrationType>.from(
                                      integrationTypes,
                                    );
                                if (value == true) {
                                  newTypes.add(
                                    ApplicationIntegrationType.guildInstall,
                                  );
                                } else {
                                  newTypes.remove(
                                    ApplicationIntegrationType.guildInstall,
                                  );
                                }
                                onIntegrationTypesChanged(newTypes);
                              },
                            ),
                            const Text("Guild Install"),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: integrationTypes.contains(
                                ApplicationIntegrationType.userInstall,
                              ),
                              onChanged: (value) {
                                final newTypes =
                                    List<ApplicationIntegrationType>.from(
                                      integrationTypes,
                                    );
                                if (value == true) {
                                  newTypes.add(
                                    ApplicationIntegrationType.userInstall,
                                  );
                                } else {
                                  newTypes.remove(
                                    ApplicationIntegrationType.userInstall,
                                  );
                                }
                                onIntegrationTypesChanged(newTypes);
                              },
                            ),
                            const Text("User Install"),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Scope of the command (Contexts)",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: contexts.contains(
                                InteractionContextType.guild,
                              ),
                              onChanged: (value) {
                                final newContexts =
                                    List<InteractionContextType>.from(contexts);
                                if (value == true) {
                                  newContexts.add(InteractionContextType.guild);
                                } else {
                                  newContexts.remove(
                                    InteractionContextType.guild,
                                  );
                                }
                                onContextsChanged(newContexts);
                              },
                            ),
                            const Text("Guild"),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: contexts.contains(
                                InteractionContextType.botDm,
                              ),
                              onChanged: (value) {
                                final newContexts =
                                    List<InteractionContextType>.from(contexts);
                                if (value == true) {
                                  newContexts.add(InteractionContextType.botDm);
                                } else {
                                  newContexts.remove(
                                    InteractionContextType.botDm,
                                  );
                                }
                                onContextsChanged(newContexts);
                              },
                            ),
                            const Text("Bot DM"),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: contexts.contains(
                                InteractionContextType.privateChannel,
                              ),
                              onChanged: (value) {
                                final newContexts =
                                    List<InteractionContextType>.from(contexts);
                                if (value == true) {
                                  newContexts.add(
                                    InteractionContextType.privateChannel,
                                  );
                                } else {
                                  newContexts.remove(
                                    InteractionContextType.privateChannel,
                                  );
                                }
                                onContextsChanged(newContexts);
                              },
                            ),
                            const Text("Group DM / Other"),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
