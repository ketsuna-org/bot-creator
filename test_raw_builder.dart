import 'package:nyxx/nyxx.dart';

class RawComponentBuilder extends ComponentBuilder {
  final Map<String, Object?> payload;
  RawComponentBuilder(this.payload);

  @override
  Map<String, Object?> build() => payload;
}

void main() {
  final msg = MessageBuilder(
    components: [
      RawComponentBuilder({
        "type": 1,
        "components": [
          {"type": 2, "style": 1, "label": "test"},
        ],
      }),
    ],
  );
  print(msg.build());
}
