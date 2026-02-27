import 'package:nyxx/nyxx.dart';
import 'package:bot_creator/types/component.dart';

class CustomSectionBuilder extends ComponentBuilder<SectionComponent> {
  final List<TextDisplayComponentBuilder> sectionComponents;
  final ComponentBuilder? sectionAccessory;

  CustomSectionBuilder({required this.sectionComponents, this.sectionAccessory})
    : super(type: ComponentType.section);

  @override
  Map<String, Object?> build() => {
    ...super.build(),
    'components': [
      for (final component in sectionComponents) component.build(),
    ],
    if (sectionAccessory != null) 'accessory': sectionAccessory!.build(),
  };
}

ComponentBuilder buildComponentNode(
  ComponentNode node,
  String Function(String) resolve,
) {
  if (node is ActionRowNode) {
    return ActionRowBuilder(
      components:
          node.components.map((c) => buildComponentNode(c, resolve)).toList(),
    );
  } else if (node is ButtonNode) {
    if (node.style == BcButtonStyle.link) {
      final label = resolve(node.label);
      final url = Uri.tryParse(resolve(node.url));
      return ButtonBuilder.link(
        label: label.isNotEmpty ? label : null,
        url: url ?? Uri.parse('https://example.com'),
        isDisabled: node.disabled ? true : null,
      );
    }
    final label = resolve(node.label);
    final nyxxStyle = switch (node.style) {
      BcButtonStyle.secondary => ButtonStyle.secondary,
      BcButtonStyle.success => ButtonStyle.success,
      BcButtonStyle.danger => ButtonStyle.danger,
      _ => ButtonStyle.primary,
    };
    return ButtonBuilder(
      style: nyxxStyle,
      label: label.isNotEmpty ? label : null,
      customId: resolve(node.customId),
      isDisabled: node.disabled ? true : null,
    );
  } else if (node is SelectMenuNode) {
    final customId = resolve(node.customId);
    final placeholderRaw = resolve(node.placeholder);
    final placeholder = placeholderRaw.isNotEmpty ? placeholderRaw : null;

    switch (node.type) {
      case ComponentV2Type.userSelect:
        return SelectMenuBuilder.userSelect(
          customId: customId,
          placeholder: placeholder,
          minValues: node.minValues,
          maxValues: node.maxValues,
          isDisabled: node.disabled ? true : null,
        );
      case ComponentV2Type.roleSelect:
        return SelectMenuBuilder.roleSelect(
          customId: customId,
          placeholder: placeholder,
          minValues: node.minValues,
          maxValues: node.maxValues,
          isDisabled: node.disabled ? true : null,
        );
      case ComponentV2Type.mentionableSelect:
        return SelectMenuBuilder.mentionableSelect(
          customId: customId,
          placeholder: placeholder,
          minValues: node.minValues,
          maxValues: node.maxValues,
          isDisabled: node.disabled ? true : null,
        );
      case ComponentV2Type.channelSelect:
        return SelectMenuBuilder.channelSelect(
          customId: customId,
          placeholder: placeholder,
          minValues: node.minValues,
          maxValues: node.maxValues,
          isDisabled: node.disabled ? true : null,
        );
      case ComponentV2Type.stringSelect:
      default:
        final options =
            node.options.map((opt) {
              final desc = resolve(opt.description);
              return SelectMenuOptionBuilder(
                label: resolve(opt.label),
                value: resolve(opt.value),
                description: desc.isNotEmpty ? desc : null,
              );
            }).toList();
        return SelectMenuBuilder.stringSelect(
          customId: customId,
          options:
              options.isEmpty
                  ? [SelectMenuOptionBuilder(label: 'Empty', value: 'empty')]
                  : options,
          placeholder: placeholder,
          minValues: node.minValues,
          maxValues: node.maxValues,
          isDisabled: node.disabled ? true : null,
        );
    }
  } else if (node is SectionNode) {
    final components =
        node.components
            .map((c) => buildComponentNode(c, resolve))
            .whereType<TextDisplayComponentBuilder>()
            .toList();
    final accessory =
        node.accessory != null
            ? buildComponentNode(node.accessory!, resolve)
            : null;
    return CustomSectionBuilder(
      sectionComponents: components,
      sectionAccessory: accessory,
    );
  } else if (node is TextDisplayNode) {
    return TextDisplayComponentBuilder(content: resolve(node.content));
  } else if (node is ThumbnailNode) {
    return ThumbnailComponentBuilder(
      media: UnfurledMediaItemBuilder(url: Uri.parse(resolve(node.media.url))),
      description:
          node.description.isNotEmpty ? resolve(node.description) : null,
      isSpoiler: node.isSpoiler ? true : null,
    );
  } else if (node is MediaGalleryNode) {
    return MediaGalleryComponentBuilder(
      items:
          node.items
              .map(
                (i) => MediaGalleryItemBuilder(
                  media: UnfurledMediaItemBuilder(
                    url: Uri.parse(resolve(i.media.url)),
                  ),
                  description:
                      i.description.isNotEmpty ? resolve(i.description) : null,
                  isSpoiler: i.isSpoiler ? true : null,
                ),
              )
              .toList(),
    );
  } else if (node is SeparatorNode) {
    return SeparatorComponentBuilder(
      isDivider: node.isDivider ? true : null,
      spacing:
          node.spacing == 2
              ? SeparatorSpacingSize.large
              : SeparatorSpacingSize.small,
    );
  } else if (node is FileNode) {
    return FileComponentBuilder(
      file: UnfurledMediaItemBuilder(url: Uri.parse(resolve(node.file.url))),
      isSpoiler: node.isSpoiler ? true : null,
    );
  } else if (node is ContainerNode) {
    DiscordColor? accentColor;
    final colorStr = resolve(node.accentColor).replaceAll('#', '');
    if (colorStr.length == 6) {
      final colorInt = int.tryParse(colorStr, radix: 16);
      if (colorInt != null) accentColor = DiscordColor(colorInt);
    }
    return ContainerComponentBuilder(
      components:
          node.components.map((c) => buildComponentNode(c, resolve)).toList(),
      accentColor: accentColor,
      isSpoiler: node.isSpoiler ? true : null,
    );
  } else if (node is LabelNode) {
    return LabelComponentBuilder(
      label: resolve(node.label),
      description:
          node.description.isNotEmpty ? resolve(node.description) : null,
      component:
          node.component != null
              ? buildComponentNode(node.component!, resolve)
              : TextDisplayComponentBuilder(content: ''),
    );
  } else if (node is FileUploadNode) {
    return FileUploadComponentBuilder(
      customId: resolve(node.customId),
      minValues: node.minValues,
      maxValues: node.maxValues,
      isRequired: node.isRequired ? true : null,
    );
  } else if (node is RadioGroupNode) {
    return RadioGroupComponentBuilder(
      customId: resolve(node.customId),
      options:
          node.options
              .map(
                (o) => RadioGroupOptionBuilder(
                  value: resolve(o.value),
                  label: resolve(o.label),
                  description:
                      o.description.isNotEmpty ? resolve(o.description) : null,
                  defaultValue: o.isDefault ? true : null,
                ),
              )
              .toList(),
      isRequired: node.isRequired ? true : null,
    );
  } else if (node is CheckboxGroupNode) {
    return CheckboxGroupComponentBuilder(
      customId: resolve(node.customId),
      options:
          node.options
              .map(
                (o) => CheckboxGroupOptionBuilder(
                  value: resolve(o.value),
                  label: resolve(o.label),
                  description:
                      o.description.isNotEmpty ? resolve(o.description) : null,
                  defaultValue: o.isDefault ? true : null,
                ),
              )
              .toList(),
      minValues: node.minValues,
      maxValues: node.maxValues,
      isRequired: node.isRequired ? true : null,
    );
  } else if (node is CheckboxNode) {
    return CheckboxComponentBuilder(
      customId: resolve(node.customId),
      defaultValue: node.isDefault ? true : null,
    );
  }

  // Fallback
  return TextDisplayComponentBuilder(content: 'Unknown component');
}

/// Convert a [ComponentV2Definition] into component builders for nyxx.
List<ComponentBuilder> buildComponentNodes({
  required ComponentV2Definition definition,
  required String Function(String) resolve,
}) {
  final result = <ComponentBuilder>[];
  final currentRowComponents = <ComponentBuilder>[];

  void flushActionRow() {
    if (currentRowComponents.isNotEmpty) {
      result.add(ActionRowBuilder(components: List.from(currentRowComponents)));
      currentRowComponents.clear();
    }
  }

  for (final node in definition.components) {
    if (node is ActionRowNode) {
      flushActionRow();
      result.add(buildComponentNode(node, resolve));
    } else if (node is ButtonNode || node is CheckboxNode) {
      currentRowComponents.add(buildComponentNode(node, resolve));
      if (currentRowComponents.length >= 5) {
        flushActionRow();
      }
    } else if (node is SelectMenuNode ||
        node is RadioGroupNode ||
        node is CheckboxGroupNode ||
        node is FileUploadNode) {
      flushActionRow();
      result.add(
        ActionRowBuilder(components: [buildComponentNode(node, resolve)]),
      );
    } else {
      // Layout components (Container, TextDisplay, Section, MediaGallery, etc.)
      // can be directly added to the root level in V2.
      flushActionRow();
      result.add(buildComponentNode(node, resolve));
    }
  }
  flushActionRow();

  return result;
}

/// Build a [MessageBuilder] from a [ComponentV2Definition].
MessageBuilder buildComponentMessage({
  required ComponentV2Definition definition,
  required String Function(String) resolve,
}) {
  final nodes = buildComponentNodes(definition: definition, resolve: resolve);

  // 1 << 15 (32768) is the IS_COMPONENTS_V2 flag
  final flagsOpt = (definition.ephemeral ? 64 : 0) | 32768;

  return MessageBuilder(
    content: null, // content is banned for V2
    components: nodes,
    flags: MessageFlags(flagsOpt),
  );
}

/// Send a ComponentV2 message to a channel.
Future<Map<String, dynamic>> sendComponentV2Action(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  Snowflake? fallbackChannelId,
  String Function(String)? resolve,
}) async {
  resolve ??= (s) => s;
  try {
    final componentsDef = payload['components'];
    final definition =
        componentsDef is Map
            ? ComponentV2Definition.fromJson(
              Map<String, dynamic>.from(componentsDef),
            )
            : ComponentV2Definition();

    final channelIdRaw = resolve((payload['channelId'] ?? '').toString());
    Snowflake? channelId;
    if (channelIdRaw.isNotEmpty) {
      final parsed = int.tryParse(channelIdRaw);
      if (parsed != null) channelId = Snowflake(parsed);
    }
    channelId ??= fallbackChannelId;

    if (channelId == null) {
      return {'error': 'No channelId available for sendComponentV2'};
    }

    final channel = await client.channels.fetch(channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel'};
    }

    final builder = buildComponentMessage(
      definition: definition,
      resolve: resolve,
    );
    final message = await channel.sendMessage(builder);

    return {'messageId': message.id.toString()};
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Respond to an interaction with a ComponentV2 message.
/// If already acknowledged (deferred), updates the response.
Future<Map<String, dynamic>> respondWithComponentV2Action(
  Interaction interaction, {
  required Map<String, dynamic> payload,
  String Function(String)? resolve,
}) async {
  resolve ??= (s) => s;
  try {
    final componentsDef = payload['components'];
    final definition =
        componentsDef is Map
            ? ComponentV2Definition.fromJson(
              Map<String, dynamic>.from(componentsDef),
            )
            : ComponentV2Definition();

    // build the component nodes
    final nodes = buildComponentNodes(definition: definition, resolve: resolve);

    // 1 << 15 (32768) is the IS_COMPONENTS_V2 flag
    final flagsOpt = (definition.ephemeral ? 64 : 0) | 32768;

    if (interaction is MessageResponse ||
        interaction is ModalSubmitInteraction) {
      final dynInt = interaction as dynamic;
      bool isAcknowledged = false;
      try {
        isAcknowledged = dynInt.isAcknowledged == true;
      } catch (_) {
        isAcknowledged = false;
      }

      try {
        if (isAcknowledged) {
          final builder = MessageUpdateBuilder(
            content: null,
            components: nodes,
          );
          final message = await dynInt.updateOriginalResponse(builder);
          return {'messageId': message.id.toString()};
        } else {
          final builder = MessageBuilder(
            content: null,
            components: nodes,
            flags: MessageFlags(flagsOpt),
          );
          await dynInt.respond(builder);
          return {'status': 'responded'};
        }
      } catch (e) {
        return {'error': 'Failed to send interaction response: $e'};
      }
    }

    return {'error': 'Interaction does not support message responses'};
  } catch (e) {
    return {'error': e.toString()};
  }
}
