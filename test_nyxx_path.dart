import 'dart:isolate';

void main() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:nyxx/src/builders/message/component.dart'),
  );
  if (uri != null) {
    print("PATH=" + uri.toFilePath());
  } else {
    print("NOT FOUND message/component.dart");
  }
}
