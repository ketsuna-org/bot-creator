import 'dart:convert';

import 'package:cardia_kexa/models/discord.dart';
import 'package:http/http.dart' as http;

const String discordUrl = "https://discord.com/api/v10";

Future<DiscordUser> getDiscordUser(String botToken) async {
  var data = await http.get(
    Uri.parse("$discordUrl/users/@me"),
    headers: {"Authorization": "Bot $botToken"},
  );

  if (data.statusCode == 200) {
    // Parse the response and save it to the database
    final discordUser = DiscordUser.fromJson(jsonDecode(data.body));
    return discordUser;
  } else if (data.statusCode == 401) {
    // Handle unauthorized error
    throw Exception("Unauthorized");
  } else {
    throw Exception("Failed to fetch user data");
  }
}
