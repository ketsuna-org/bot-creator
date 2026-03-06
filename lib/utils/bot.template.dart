part of 'bot.dart';

@pragma('vm:entry-point')
String updateString(String initial, Map<String, String> updates) {
  return resolveTemplatePlaceholders(initial, updates);
}
