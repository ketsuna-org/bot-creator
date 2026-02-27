import 'dart:isolate';
void main() async {
  final uri = await Isolate.resolvePackageUri(Uri.parse('package:nyxx/src/models/message/component.dart'));
  print(uri?.toFilePath());
}
