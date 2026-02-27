import 'package:nyxx/nyxx.dart';
import 'package:bot_creator/types/component.dart' as bc;

/// Respond to an interaction with a Modal dialog.
/// NOTE: Modals can only be sent as the FIRST response (not after defer).
Future<Map<String, dynamic>> respondWithModalAction(
  ApplicationCommandInteraction interaction, {
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    final modalJson = payload['modal'];
    if (modalJson == null) {
      return {'error': 'modal definition is required'};
    }

    final definition = bc.ModalDefinition.fromJson(
      Map<String, dynamic>.from(
        (modalJson as Map).map((k, v) => MapEntry(k.toString(), v)),
      ),
    );

    if (definition.title.isEmpty) {
      return {'error': 'Modal title is required'};
    }
    if (definition.customId.isEmpty) {
      return {'error': 'Modal customId is required'};
    }
    if (definition.inputs.isEmpty) {
      return {'error': 'Modal must have at least one text input'};
    }

    final modalBuilder = ModalBuilder(
      title: resolve(definition.title),
      customId: resolve(definition.customId),
      components:
          definition.inputs.map((input) {
            return ActionRowBuilder(
              components: [
                TextInputBuilder(
                  customId: resolve(input.customId),
                  // ignore: deprecated_member_use
                  label: resolve(input.label),
                  style:
                      input.style == bc.BcTextInputStyle.paragraph
                          ? TextInputStyle.paragraph
                          : TextInputStyle.short,
                  placeholder:
                      input.placeholder.isNotEmpty
                          ? resolve(input.placeholder)
                          : null,
                  value:
                      input.defaultValue.isNotEmpty
                          ? resolve(input.defaultValue)
                          : null,
                  isRequired: input.required,
                  minLength: input.minLength,
                  maxLength: input.maxLength,
                ),
              ],
            );
          }).toList(),
    );

    await interaction.respondModal(modalBuilder);
    return {'status': 'modal_sent', 'customId': definition.customId};
  } catch (e) {
    return {'error': e.toString()};
  }
}
