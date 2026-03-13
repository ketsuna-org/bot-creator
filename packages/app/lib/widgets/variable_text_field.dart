import 'package:flutter/material.dart';
import '../types/variable_suggestion.dart';

class VariableTextField extends StatefulWidget {
  final String? initialValue;
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final int maxLines;
  final int? maxLength;
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
    this.maxLength,
    required this.suggestions,
    required this.onChanged,
    this.isNumericField = false,
    this.required = false,
    this.helperText,
    this.validator,
    this.options,
  });

  @override
  State<VariableTextField> createState() => _VariableTextFieldState();
}

class _VariableTextFieldState extends State<VariableTextField> {
  TextEditingController? _internalController;
  late final FocusNode _focusNode;
  String _lastDispatchedValue = '';

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _initController();
  }

  void _initController() {
    if (widget.controller == null) {
      _internalController = TextEditingController(
        text: widget.initialValue ?? '',
      );
    }
    _lastDispatchedValue = _effectiveController.text;
    _effectiveController.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant VariableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController)?.removeListener(
        _handleControllerChange,
      );

      if (oldWidget.controller == null && widget.controller != null) {
        _internalController?.dispose();
        _internalController = null;
      }

      if (widget.controller == null) {
        _internalController ??= TextEditingController(
          text: oldWidget.controller?.text ?? widget.initialValue ?? '',
        );
      }

      _lastDispatchedValue = _effectiveController.text;
      _effectiveController.addListener(_handleControllerChange);
    }

    if (widget.controller == null &&
        widget.initialValue != null &&
        !_focusNode.hasFocus &&
        widget.initialValue != _effectiveController.text) {
      final value = widget.initialValue!;
      _effectiveController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      _lastDispatchedValue = value;
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_handleControllerChange);
    _internalController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    final current = _effectiveController.text;
    if (current != _lastDispatchedValue) {
      _lastDispatchedValue = current;
      widget.onChanged(current);
    }

    if (mounted) {
      setState(() {});
    }
  }

  int _safeCursor(String text, int rawOffset) {
    if (rawOffset < 0 || rawOffset > text.length) {
      return text.length;
    }
    return rawOffset;
  }

  @override
  Widget build(BuildContext context) {
    final currentText = _effectiveController.text;
    final cursor = _safeCursor(
      currentText,
      _effectiveController.selection.baseOffset,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            if (widget.required)
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
          controller: _effectiveController,
          focusNode: _focusNode,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helperText,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          onTap: () {
            setState(() {});
          },
          validator: widget.validator,
        ),
        ..._buildSuggestions(currentText, cursor),
      ],
    );
  }

  List<Widget> _buildSuggestions(String currentValue, int cursor) {
    final query = _extractPlaceholderQuery(currentValue, cursor);
    if (query == null) return [];

    final safeCursor = _safeCursor(currentValue, cursor);
    final start = currentValue.lastIndexOf('((', safeCursor);
    final inFallbackMode =
        start != -1 &&
        start + 2 <= safeCursor &&
        currentValue.substring(start + 2, safeCursor).contains('|');

    final normalizedQuery = query.trim().toLowerCase();
    final filteredByKind =
        widget.isNumericField
            ? widget.suggestions.where(
              (item) => item.isNumeric || item.isUnknown,
            )
            : widget.suggestions;

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
        widget.isNumericField
            ? 'Dynamic numeric suggestions'
            : 'Dynamic variable suggestions',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      if (inFallbackMode)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Fallback mode enabled (using |)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            filtered.map((item) {
              return ActionChip(
                label: Text(
                  '((${item.name}))',
                  style: const TextStyle(fontSize: 12),
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () {
                  _insertVariable(item.name);
                },
              );
            }).toList(),
      ),
    ];
  }

  String? _extractPlaceholderQuery(String input, int cursor) {
    final safeCursor = _safeCursor(input, cursor);
    final start = input.lastIndexOf('((', safeCursor);
    if (start == -1) return null;

    final closing = input.indexOf('))', start + 2);
    if (closing != -1 && closing < safeCursor) {
      return null;
    }

    final afterStart = input.substring(start + 2, safeCursor);
    final parts = afterStart.split('|');
    return parts.last.trimLeft();
  }

  void _insertVariable(String variableName) {
    final input = _effectiveController.text;
    final cursor = _safeCursor(
      input,
      _effectiveController.selection.baseOffset,
    );
    final start = input.lastIndexOf('((', cursor);

    if (start == -1) {
      final replacement = '(($variableName))';
      final nextText = input.replaceRange(cursor, cursor, replacement);
      final nextCursor = cursor + replacement.length;
      _effectiveController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextCursor),
      );
      return;
    }

    final closing = input.indexOf('))', start + 2);
    if (closing != -1 && closing < cursor) {
      final replacement = '(($variableName))';
      final nextText = input.replaceRange(cursor, cursor, replacement);
      final nextCursor = cursor + replacement.length;
      _effectiveController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextCursor),
      );
      return;
    }

    final rawInner = input.substring(start + 2, cursor);
    final parts = rawInner.split('|');
    final prefixParts =
        parts.length > 1 ? parts.sublist(0, parts.length - 1) : <String>[];
    final previous =
        prefixParts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final inner = [...previous, variableName].join(' | ');
    final replacement = '(($inner))';

    final replaceEnd =
        (closing != -1 && closing >= cursor) ? closing + 2 : cursor;
    final nextText = input.replaceRange(start, replaceEnd, replacement);
    final nextCursor = start + replacement.length;

    _effectiveController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
  }
}
