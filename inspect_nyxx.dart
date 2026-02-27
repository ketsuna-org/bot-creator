import 'package:nyxx/nyxx.dart';
import 'dart:mirrors';

void main() {
  var classMirror = reflectClass(ComponentType);
  for (var decl in classMirror.declarations.values) {
    if (decl is VariableMirror && decl.isStatic) {
      var value = classMirror.getField(decl.simpleName).reflectee;
      if (value is ComponentType) {
        print("\${decl.simpleName}: \${value.value}");
      } else {
        print("\${decl.simpleName}: \${value}");
      }
    }
  }
}
