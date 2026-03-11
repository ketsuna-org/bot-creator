enum VariableSuggestionKind { numeric, nonNumeric, unknown }

class VariableSuggestion {
  final String name;
  final VariableSuggestionKind kind;

  const VariableSuggestion({required this.name, required this.kind});

  bool get isNumeric => kind == VariableSuggestionKind.numeric;
  bool get isUnknown => kind == VariableSuggestionKind.unknown;
}
