import 'package:nyxx/nyxx.dart';

const String discordUrl = "https://discord.com/api/v10";

Future<User> getDiscordUser(String botToken) async {
  try {
    final client = await Nyxx.connectRest(botToken);
    return await client.user.fetch();
  } catch (e) {
    throw Exception("Failed to fetch user: $e");
  }
}
