import 'package:flutter/material.dart';
import '../types/variable_suggestion.dart';

class VariableTextField extends StatelessWidget {
  final String? initialValue;
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final int maxLines;
  final List<VariableSuggestion> suggestions;
  final ValueChanged<String> onChanged;
  final bool isNumericField;
  final bool required;
  final String? helperText;
  final String? Function(String?)? validator;
  final List<String>? options; // For autocomplete if needed

  const VariableTextField({
    super.key,
    this.initialValue,
    this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    required this.suggestions,
    required this.onChanged,
    this.isNumericField = false,
    this.required = false,
    this.helperText,
    this.validator,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          onChanged: onChanged,
          validator: validator,
        ),
        ..._buildSuggestions(controller?.text ?? initialValue ?? ''),
      ],
    );
  }

  List<Widget> _buildSuggestions(String currentValue) {
    final query = _extractPlaceholderQuery(currentValue);
    if (query == null) return [];

    final normalizedQuery = query.trim().toLowerCase();
    final filteredByKind =
        isNumericField
            ? suggestions.where((item) => item.isNumeric || item.isUnknown)
            : suggestions;

    final filtered =
        filteredByKind
            .where(
              (item) =>
                  normalizedQuery.isEmpty ||
                  item.name.toLowerCase().contains(normalizedQuery),
            )
            .take(8)
            .toList();

    if (filtered.isEmpty) return [];

    return [
      const SizedBox(height: 8),
      Text(
        isNumericField
            ? 'Dynamic numeric suggestions'
            : 'Dynamic variable suggestions',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            filtered.map((item) {
              return ActionChip(
                label: Text(
                  '((#${item.name}))'.replaceFirst('#', ''),
                  style: const TextStyle(fontSize: 12),
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () {
                  final newValue = _insertVariable(currentValue, item.name);
                  onChanged(newValue);
                },
              );
            }).toList(),
      ),
    ];
  }

  String? _extractPlaceholderQuery(String input) {
    final start = input.lastIndexOf('((');
    if (start == -1) return null;

    final afterStart = input.substring(start + 2);
    if (afterStart.contains('))')) return null;

    // Support optional filters like ((modal.input | default))
    final parts = afterStart.split('|');
    return parts.last.trimLeft();
  }

  String _insertVariable(String input, String variableName) {
    final start = input.lastIndexOf('((');
    if (start == -1) return '(($variableName))';

    final beforeStart = input.substring(0, start);
    final afterStart = input.substring(start + 2);
    if (afterStart.contains('))')) return input;

    return '$beforeStart(($variableName))';
  }
}
