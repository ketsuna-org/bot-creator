import 'package:nyxx/nyxx.dart';

void main() {
  print(ActionRowBuilder);
  print(ButtonBuilder);
  print(StringSelectMenuBuilder);
  print(TextInputBuilder);

  // Try to reference new ones:
  try {
    print(SectionBuilder);
  } catch (e) {}
  try {
    print(ContainerBuilder);
  } catch (e) {}
  try {
    print(LabelBuilder);
  } catch (e) {}
  try {
    print(TextDisplayBuilder);
  } catch (e) {}
}
