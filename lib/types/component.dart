// Component V2 and Modal type definitions for BotCreator

enum BcButtonStyle { primary, secondary, success, danger, link }

enum BcTextInputStyle { short, paragraph }

enum BcSelectMenuType { string, user, role, mentionable, channel }

enum ComponentV2Type {
  actionRow,
  button,
  stringSelect,
  userSelect,
  roleSelect,
  mentionableSelect,
  channelSelect,
  section,
  textDisplay,
  thumbnail,
  mediaGallery,
  file,
  separator,
  container,
  label,
  fileUpload,
  radioGroup,
  checkboxGroup,
  checkbox,
}

abstract class ComponentNode {
  ComponentV2Type get type;
  Map<String, dynamic> toJson();

  static String generateId([String prefix = 'id']) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomSuffix =
        (1000 + (DateTime.now().microsecondsSinceEpoch % 9000)).toString();
    return '${prefix}_$timestamp$randomSuffix';
  }

  static ComponentNode fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = ComponentV2Type.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => ComponentV2Type.actionRow, // default fallback
    );

    switch (type) {
      case ComponentV2Type.actionRow:
        return ActionRowNode.fromJson(json);
      case ComponentV2Type.button:
        return ButtonNode.fromJson(json);
      case ComponentV2Type.stringSelect:
      case ComponentV2Type.userSelect:
      case ComponentV2Type.roleSelect:
      case ComponentV2Type.mentionableSelect:
      case ComponentV2Type.channelSelect:
        return SelectMenuNode.fromJson(json);
      case ComponentV2Type.section:
        return SectionNode.fromJson(json);
      case ComponentV2Type.textDisplay:
        return TextDisplayNode.fromJson(json);
      case ComponentV2Type.thumbnail:
        return ThumbnailNode.fromJson(json);
      case ComponentV2Type.mediaGallery:
        return MediaGalleryNode.fromJson(json);
      case ComponentV2Type.file:
        return FileNode.fromJson(json);
      case ComponentV2Type.separator:
        return SeparatorNode.fromJson(json);
      case ComponentV2Type.container:
        return ContainerNode.fromJson(json);
      case ComponentV2Type.label:
        return LabelNode.fromJson(json);
      case ComponentV2Type.fileUpload:
        return FileUploadNode.fromJson(json);
      case ComponentV2Type.radioGroup:
        return RadioGroupNode.fromJson(json);
      case ComponentV2Type.checkboxGroup:
        return CheckboxGroupNode.fromJson(json);
      case ComponentV2Type.checkbox:
        return CheckboxNode.fromJson(json);
    }
  }
}

class ActionRowNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.actionRow;

  List<ComponentNode> components;

  ActionRowNode({this.components = const []});

  factory ActionRowNode.fromJson(Map<String, dynamic> json) {
    return ActionRowNode(
      components:
          (json['components'] as List? ?? [])
              .whereType<Map>()
              .map((c) => ComponentNode.fromJson(Map<String, dynamic>.from(c)))
              .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'components': components.map((c) => c.toJson()).toList(),
  };
}

class ButtonNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.button;

  String label;
  BcButtonStyle style;
  String customId;
  String url;
  String emoji;
  bool disabled;

  ButtonNode({
    this.label = 'Button',
    this.style = BcButtonStyle.primary,
    String? customId,
    this.url = '',
    this.emoji = '',
    this.disabled = false,
  }) : customId = customId ?? ComponentNode.generateId('btn');

  factory ButtonNode.fromJson(Map<String, dynamic> json) {
    return ButtonNode(
      label: (json['label'] ?? '').toString(),
      style: BcButtonStyle.values.firstWhere(
        (s) => s.name == json['style'],
        orElse: () => BcButtonStyle.primary,
      ),
      customId: (json['customId'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
      disabled: json['disabled'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'label': label,
    'style': style.name,
    'customId': customId,
    'url': url,
    'emoji': emoji,
    'disabled': disabled,
  };
}

class SelectMenuOption {
  String label;
  String value;
  String description;
  String emoji;

  SelectMenuOption({
    this.label = '',
    this.value = '',
    this.description = '',
    this.emoji = '',
  });

  factory SelectMenuOption.fromJson(Map<String, dynamic> json) {
    return SelectMenuOption(
      label: (json['label'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'description': description,
    'emoji': emoji,
  };
}

class SelectMenuNode extends ComponentNode {
  @override
  final ComponentV2Type type;

  String customId;
  String placeholder;
  List<SelectMenuOption> options;
  int minValues;
  int maxValues;
  bool disabled;

  SelectMenuNode({
    this.type = ComponentV2Type.stringSelect,
    String? customId,
    this.placeholder = 'Select an option...',
    this.options = const [],
    this.minValues = 1,
    this.maxValues = 1,
    this.disabled = false,
  }) : customId = customId ?? ComponentNode.generateId('select');

  factory SelectMenuNode.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final resolvedType = ComponentV2Type.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => ComponentV2Type.stringSelect,
    );
    return SelectMenuNode(
      type: resolvedType,
      customId: (json['customId'] ?? '').toString(),
      placeholder: (json['placeholder'] ?? 'Select an option...').toString(),
      options:
          (json['options'] as List? ?? [])
              .whereType<Map>()
              .map(
                (o) => SelectMenuOption.fromJson(Map<String, dynamic>.from(o)),
              )
              .toList(),
      minValues: json['minValues'] as int? ?? 1,
      maxValues: json['maxValues'] as int? ?? 1,
      disabled: json['disabled'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'customId': customId,
    'placeholder': placeholder,
    'options': options.map((o) => o.toJson()).toList(),
    'minValues': minValues,
    'maxValues': maxValues,
    'disabled': disabled,
  };
}

class SectionNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.section;

  List<TextDisplayNode> components;
  ComponentNode? accessory;

  SectionNode({this.components = const [], this.accessory});

  factory SectionNode.fromJson(Map<String, dynamic> json) {
    ComponentNode? parseAccessory(dynamic accJson) {
      if (accJson is Map) {
        return ComponentNode.fromJson(Map<String, dynamic>.from(accJson));
      }
      return null;
    }

    return SectionNode(
      components:
          (json['components'] as List? ?? [])
              .whereType<Map>()
              .map(
                (c) => TextDisplayNode.fromJson(Map<String, dynamic>.from(c)),
              )
              .toList(),
      accessory: parseAccessory(json['accessory']),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'components': components.map((c) => c.toJson()).toList(),
    if (accessory != null) 'accessory': accessory!.toJson(),
  };
}

class TextDisplayNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.textDisplay;

  String content;

  TextDisplayNode({this.content = ''});

  factory TextDisplayNode.fromJson(Map<String, dynamic> json) {
    return TextDisplayNode(content: (json['content'] ?? '').toString());
  }

  @override
  Map<String, dynamic> toJson() => {'type': type.name, 'content': content};
}

class UnfurledMediaItemNode {
  String url;
  UnfurledMediaItemNode({this.url = ''});

  factory UnfurledMediaItemNode.fromJson(Map<String, dynamic> json) {
    return UnfurledMediaItemNode(url: (json['url'] ?? '').toString());
  }

  Map<String, dynamic> toJson() => {'url': url};
}

class ThumbnailNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.thumbnail;

  UnfurledMediaItemNode media;
  String description;
  bool isSpoiler;

  ThumbnailNode({
    UnfurledMediaItemNode? media,
    this.description = '',
    this.isSpoiler = false,
  }) : media = media ?? UnfurledMediaItemNode();

  factory ThumbnailNode.fromJson(Map<String, dynamic> json) {
    return ThumbnailNode(
      media:
          json['media'] is Map
              ? UnfurledMediaItemNode.fromJson(
                Map<String, dynamic>.from(json['media']),
              )
              : UnfurledMediaItemNode(),
      description: (json['description'] ?? '').toString(),
      isSpoiler: json['isSpoiler'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'media': media.toJson(),
    'description': description,
    'isSpoiler': isSpoiler,
  };
}

class MediaGalleryItemNode {
  UnfurledMediaItemNode media;
  String description;
  bool isSpoiler;

  MediaGalleryItemNode({
    UnfurledMediaItemNode? media,
    this.description = '',
    this.isSpoiler = false,
  }) : media = media ?? UnfurledMediaItemNode();

  factory MediaGalleryItemNode.fromJson(Map<String, dynamic> json) {
    return MediaGalleryItemNode(
      media:
          json['media'] is Map
              ? UnfurledMediaItemNode.fromJson(
                Map<String, dynamic>.from(json['media']),
              )
              : UnfurledMediaItemNode(),
      description: (json['description'] ?? '').toString(),
      isSpoiler: json['isSpoiler'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'media': media.toJson(),
    'description': description,
    'isSpoiler': isSpoiler,
  };
}

class MediaGalleryNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.mediaGallery;

  List<MediaGalleryItemNode> items;

  MediaGalleryNode({this.items = const []});

  factory MediaGalleryNode.fromJson(Map<String, dynamic> json) {
    return MediaGalleryNode(
      items:
          (json['items'] as List? ?? [])
              .whereType<Map>()
              .map(
                (i) =>
                    MediaGalleryItemNode.fromJson(Map<String, dynamic>.from(i)),
              )
              .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class SeparatorNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.separator;

  bool isDivider;
  int spacing; // 1 = small, 2 = large

  SeparatorNode({this.isDivider = true, this.spacing = 1});

  factory SeparatorNode.fromJson(Map<String, dynamic> json) {
    return SeparatorNode(
      isDivider: json['isDivider'] == true,
      spacing: json['spacing'] as int? ?? 1,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'isDivider': isDivider,
    'spacing': spacing,
  };
}

class FileNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.file;

  UnfurledMediaItemNode file;
  bool isSpoiler;

  FileNode({UnfurledMediaItemNode? file, this.isSpoiler = false})
    : file = file ?? UnfurledMediaItemNode();

  factory FileNode.fromJson(Map<String, dynamic> json) {
    return FileNode(
      file:
          json['file'] is Map
              ? UnfurledMediaItemNode.fromJson(
                Map<String, dynamic>.from(json['file']),
              )
              : UnfurledMediaItemNode(),
      isSpoiler: json['isSpoiler'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'file': file.toJson(),
    'isSpoiler': isSpoiler,
  };
}

class ContainerNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.container;

  List<ComponentNode> components;
  String accentColor; // hex string e.g. "#FF0000"
  bool isSpoiler;

  ContainerNode({
    this.components = const [],
    this.accentColor = '',
    this.isSpoiler = false,
  });

  factory ContainerNode.fromJson(Map<String, dynamic> json) {
    return ContainerNode(
      components:
          (json['components'] as List? ?? [])
              .whereType<Map>()
              .map((c) => ComponentNode.fromJson(Map<String, dynamic>.from(c)))
              .toList(),
      accentColor: (json['accentColor'] ?? '').toString(),
      isSpoiler: json['isSpoiler'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'components': components.map((c) => c.toJson()).toList(),
    'accentColor': accentColor,
    'isSpoiler': isSpoiler,
  };
}

class LabelNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.label;

  String label;
  String description;
  ComponentNode? component;

  LabelNode({this.label = '', this.description = '', this.component});

  factory LabelNode.fromJson(Map<String, dynamic> json) {
    return LabelNode(
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      component:
          json['component'] is Map
              ? ComponentNode.fromJson(
                Map<String, dynamic>.from(json['component']),
              )
              : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'label': label,
    'description': description,
    if (component != null) 'component': component!.toJson(),
  };
}

class FileUploadNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.fileUpload;

  String customId;
  int minValues;
  int maxValues;
  bool isRequired;

  FileUploadNode({
    String? customId,
    this.minValues = 1,
    this.maxValues = 1,
    this.isRequired = false,
  }) : customId = customId ?? ComponentNode.generateId('upload');

  factory FileUploadNode.fromJson(Map<String, dynamic> json) {
    return FileUploadNode(
      customId: (json['customId'] ?? '').toString(),
      minValues: json['minValues'] as int? ?? 1,
      maxValues: json['maxValues'] as int? ?? 1,
      isRequired: json['isRequired'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'customId': customId,
    'minValues': minValues,
    'maxValues': maxValues,
    'isRequired': isRequired,
  };
}

class RadioGroupOptionNode {
  String value;
  String label;
  String description;
  bool isDefault;

  RadioGroupOptionNode({
    this.value = '',
    this.label = '',
    this.description = '',
    this.isDefault = false,
  });

  factory RadioGroupOptionNode.fromJson(Map<String, dynamic> json) {
    return RadioGroupOptionNode(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'label': label,
    'description': description,
    'isDefault': isDefault,
  };
}

class RadioGroupNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.radioGroup;

  String customId;
  List<RadioGroupOptionNode> options;
  bool isRequired;

  RadioGroupNode({
    String? customId,
    this.options = const [],
    this.isRequired = false,
  }) : customId = customId ?? ComponentNode.generateId('radio');

  factory RadioGroupNode.fromJson(Map<String, dynamic> json) {
    return RadioGroupNode(
      customId: (json['customId'] ?? '').toString(),
      options:
          (json['options'] as List? ?? [])
              .whereType<Map>()
              .map(
                (o) =>
                    RadioGroupOptionNode.fromJson(Map<String, dynamic>.from(o)),
              )
              .toList(),
      isRequired: json['isRequired'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'customId': customId,
    'options': options.map((o) => o.toJson()).toList(),
    'isRequired': isRequired,
  };
}

class CheckboxGroupOptionNode {
  String value;
  String label;
  String description;
  bool isDefault;

  CheckboxGroupOptionNode({
    this.value = '',
    this.label = '',
    this.description = '',
    this.isDefault = false,
  });

  factory CheckboxGroupOptionNode.fromJson(Map<String, dynamic> json) {
    return CheckboxGroupOptionNode(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'label': label,
    'description': description,
    'isDefault': isDefault,
  };
}

class CheckboxGroupNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.checkboxGroup;

  String customId;
  List<CheckboxGroupOptionNode> options;
  int minValues;
  int maxValues;
  bool isRequired;

  CheckboxGroupNode({
    String? customId,
    this.options = const [],
    this.minValues = 1,
    this.maxValues = 1,
    this.isRequired = false,
  }) : customId = customId ?? ComponentNode.generateId('check_group');

  factory CheckboxGroupNode.fromJson(Map<String, dynamic> json) {
    return CheckboxGroupNode(
      customId: (json['customId'] ?? '').toString(),
      options:
          (json['options'] as List? ?? [])
              .whereType<Map>()
              .map(
                (o) => CheckboxGroupOptionNode.fromJson(
                  Map<String, dynamic>.from(o),
                ),
              )
              .toList(),
      minValues: json['minValues'] as int? ?? 1,
      maxValues: json['maxValues'] as int? ?? 1,
      isRequired: json['isRequired'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'customId': customId,
    'options': options.map((o) => o.toJson()).toList(),
    'minValues': minValues,
    'maxValues': maxValues,
    'isRequired': isRequired,
  };
}

class CheckboxNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.checkbox;

  String customId;
  bool isDefault;

  CheckboxNode({String? customId, this.isDefault = false})
    : customId = customId ?? ComponentNode.generateId('check');

  factory CheckboxNode.fromJson(Map<String, dynamic> json) {
    return CheckboxNode(
      customId: (json['customId'] ?? '').toString(),
      isDefault: json['isDefault'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'customId': customId,
    'isDefault': isDefault,
  };
}

class ComponentV2Definition {
  String content;
  List<ComponentNode> components;
  bool ephemeral;

  ComponentV2Definition({
    this.content = '',
    this.components = const [],
    this.ephemeral = false,
  });

  /// Returns true if this definition contains components that REQUIRE the IS_COMPONENTS_V2 flag.
  /// Standard ActionRows with Buttons/Selects are considered V1 (legacy).
  bool get isRichV2 {
    for (final node in components) {
      if (node is! ActionRowNode) return true;
      for (final child in node.components) {
        if (child is! ButtonNode && child is! SelectMenuNode) return true;
      }
    }
    return false;
  }

  factory ComponentV2Definition.fromJson(Map<String, dynamic> json) {
    List<ComponentNode> extractedComponents = [];

    // Parse the new v2 standard format
    if (json.containsKey('components')) {
      extractedComponents =
          (json['components'] as List? ?? [])
              .whereType<Map>()
              .map((c) => ComponentNode.fromJson(Map<String, dynamic>.from(c)))
              .toList();
    }
    // Fallback parser for the legacy rows format
    else if (json.containsKey('rows')) {
      final rows = (json['rows'] as List? ?? []).whereType<Map>();
      for (final r in rows) {
        final buttons =
            (r['buttons'] as List? ?? [])
                .whereType<Map>()
                .map((b) => ButtonNode.fromJson(Map<String, dynamic>.from(b)))
                .toList();
        final selectMenuStr = r['selectMenu'] as Map?;
        SelectMenuNode? selectMenu;
        if (selectMenuStr != null) {
          selectMenu = SelectMenuNode.fromJson(
            Map<String, dynamic>.from(selectMenuStr),
          );
        }

        final actionRow = ActionRowNode(components: [...buttons]);
        if (selectMenu != null) actionRow.components.add(selectMenu);

        if (actionRow.components.isNotEmpty) {
          extractedComponents.add(actionRow);
        }
      }
    }

    return ComponentV2Definition(
      content: (json['content'] ?? '').toString(),
      components: extractedComponents,
      ephemeral: json['ephemeral'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'content': content,
    'components': components.map((c) => c.toJson()).toList(),
    'ephemeral': ephemeral,
  };
}

class ModalTextInputDefinition {
  String customId;
  String label;
  BcTextInputStyle style;
  String placeholder;
  String defaultValue;
  bool required;
  int? minLength;
  int? maxLength;

  ModalTextInputDefinition({
    String? customId,
    this.label = '',
    this.style = BcTextInputStyle.short,
    this.placeholder = '',
    this.defaultValue = '',
    this.required = false,
    this.minLength,
    this.maxLength,
  }) : customId = customId ?? ComponentNode.generateId('input');

  factory ModalTextInputDefinition.fromJson(Map<String, dynamic> json) {
    return ModalTextInputDefinition(
      customId: (json['customId'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      style: BcTextInputStyle.values.firstWhere(
        (s) => s.name == json['style'],
        orElse: () => BcTextInputStyle.short,
      ),
      placeholder: (json['placeholder'] ?? '').toString(),
      defaultValue: (json['defaultValue'] ?? '').toString(),
      required: json['required'] == true,
      minLength: json['minLength'] as int?,
      maxLength: json['maxLength'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'customId': customId,
    'label': label,
    'style': style.name,
    'placeholder': placeholder,
    'defaultValue': defaultValue,
    'required': required,
    if (minLength != null) 'minLength': minLength,
    if (maxLength != null) 'maxLength': maxLength,
  };
}

class ModalDefinition {
  String title;
  String customId;
  List<ModalTextInputDefinition> inputs;
  String? onSubmitWorkflow;

  ModalDefinition({
    this.title = '',
    String? customId,
    this.inputs = const [],
    this.onSubmitWorkflow,
  }) : customId = customId ?? ComponentNode.generateId('modal');

  factory ModalDefinition.fromJson(Map<String, dynamic> json) {
    return ModalDefinition(
      title: (json['title'] ?? '').toString(),
      customId: (json['customId'] ?? '').toString(),
      onSubmitWorkflow: json['onSubmitWorkflow']?.toString(),
      inputs:
          (json['inputs'] as List? ?? [])
              .whereType<Map>()
              .map(
                (i) => ModalTextInputDefinition.fromJson(
                  Map<String, dynamic>.from(i),
                ),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'customId': customId,
    'inputs': inputs.map((i) => i.toJson()).toList(),
    if (onSubmitWorkflow != null) 'onSubmitWorkflow': onSubmitWorkflow,
  };
}
