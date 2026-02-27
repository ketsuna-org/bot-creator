import 'package:nyxx/nyxx.dart';
import 'package:bot_creator/types/component.dart';
import 'package:bot_creator/actions/send_component_v2.dart';
import 'dart:convert';

void main() {
  final def = ComponentV2Definition(
    components: [
      ContainerNode(components: [TextDisplayNode(content: 'Salut !!!')]),
    ],
  );

  final builders = buildComponentNodes(definition: def, resolve: (s) => s);
  final map = builders.map((e) => e.build()).toList();

  print(jsonEncode(map));
}
