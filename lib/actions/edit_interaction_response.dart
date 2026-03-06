import 'package:nyxx/nyxx.dart';
import 'package:bot_creator/types/component.dart';
import 'package:bot_creator/actions/send_component_v2.dart';

/// Edit the original/deferred interaction response.
/// Can update content, and/or components.
Future<Map<String, dynamic>> editInteractionMessageAction(
  Interaction<dynamic> interaction, {
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    if (interaction is! MessageResponse) {
      return {'error': 'Interaction does not support message responses'};
    }

    final msgInteraction = interaction;
    final content = resolve((payload['content'] ?? '').toString());
    final clearComponents = payload['clearComponents'] == true;

    // Build components if defined
    List<ComponentBuilder>? actionRows;
    final componentsDef = payload['components'];
    if (clearComponents) {
      actionRows = [];
    } else if (componentsDef is Map && componentsDef.isNotEmpty) {
      final definition = ComponentV2Definition.fromJson(
        Map<String, dynamic>.from(
          componentsDef.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
      actionRows = buildComponentNodes(
        definition: definition,
        resolve: resolve,
      );
    }

    final builder = MessageUpdateBuilder(
      content: content.isNotEmpty ? content : null,
      components: actionRows,
    );

    final message = await msgInteraction.updateOriginalResponse(builder);
    return {'messageId': message.id.toString()};
  } catch (e) {
    return {'error': e.toString()};
  }
}
