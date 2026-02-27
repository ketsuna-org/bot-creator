import 'package:nyxx/nyxx.dart';
import '../types/component.dart';
import 'send_component_v2.dart';

Future<Map<String, String>> sendMessageToChannel(
  NyxxGateway client,
  Snowflake channelId, {
  required String content,
  Map<String, dynamic>? payload,
  String Function(String)? resolve,
}) async {
  try {
    final channel = await client.channels.get(channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel', 'messageId': ''};
    }

    List<ComponentBuilder>? components;
    bool isRichV2 = false;
    if (payload != null &&
        payload.containsKey('componentV2') &&
        payload['componentV2'] is Map) {
      try {
        final def = ComponentV2Definition.fromJson(
          Map<String, dynamic>.from(payload['componentV2']),
        );
        isRichV2 = def.isRichV2;
        components = buildComponentNodes(
          definition: def,
          resolve: resolve ?? (s) => s,
        );
      } catch (_) {}
    }

    final message = await channel.sendMessage(
      MessageBuilder(
        content: isRichV2 ? null : (content.isNotEmpty ? content : null),
        components: components,
        flags: isRichV2 ? MessageFlags(32768) : null,
      ),
    );
    return {'messageId': message.id.toString()};
  } catch (e) {
    return {'error': 'Failed to send message: $e', 'messageId': ''};
  }
}
