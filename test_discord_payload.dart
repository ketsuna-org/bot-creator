import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // Try sending a message with a container component to a webhook
  // to see the exact error message from Discord.
  // Note: we can't fully execute this without a valid webhook URL, but we can verify the structure locally.

  final payload = {
    "content": "test",
    "components": [
      {
        "type": 1,
        "components": [
          {
            "type": 17,
            "components": [
              {"type": 10, "content": "test"},
            ],
          },
        ],
      },
    ],
  };

  print(jsonEncode(payload));
}
