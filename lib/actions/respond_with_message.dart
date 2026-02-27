import 'package:nyxx/nyxx.dart';

Future<Map<String, dynamic>> respondWithMessageAction(
  Interaction interaction, {
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    if (interaction is! MessageResponse &&
        interaction is! ModalSubmitInteraction) {
      return {'error': 'Interaction does not support message responses'};
    }

    final content = resolve((payload['content'] ?? '').toString()).trim();
    if (content.isEmpty) {
      return {'error': 'content is required for respondWithMessage'};
    }

    final isEphemeral = payload['ephemeral'] == true;
    final dynInteraction = interaction as dynamic;

    bool isAcknowledged = false;
    try {
      isAcknowledged = dynInteraction.isAcknowledged == true;
    } catch (_) {
      isAcknowledged = false;
    }

    if (isAcknowledged) {
      final message = await dynInteraction.updateOriginalResponse(
        MessageUpdateBuilder(
          content: content,
        ),
      );
      return {'messageId': message.id.toString()};
    }

    await dynInteraction.respond(
      MessageBuilder(
        content: content,
        flags: isEphemeral ? MessageFlags.ephemeral : null,
      ),
    );
    return {'status': 'responded'};
  } catch (e) {
    return {'error': e.toString()};
  }
}
