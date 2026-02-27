import 'dart:convert';

import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/darcula.dart';
import 'package:flutter/material.dart';
import '../../../types/action.dart' show BotCreatorActionType;
import '../../../types/component.dart';
import '../../../widgets/component_v2_builder/component_v2_editor.dart';
import '../../../widgets/component_v2_builder/modal_builder.dart';
import 'action_types.dart';
import 'action_type_extension.dart';
import 'package:http/http.dart' as http;

class ActionCard extends StatelessWidget {
  final ActionItem action;
  final String actionKey;
  final List<VariableSuggestion> variableSuggestions;
  final int Function(String paramKey) fieldRefreshVersionOf;
  final Function(String key, dynamic value) onSuggestionSelected;
  final VoidCallback onRemove;
  final Function(String key, dynamic value) onParameterChanged;

  const ActionCard({
    super.key,
    required this.action,
    required this.onRemove,
    required this.onParameterChanged,
    required this.onSuggestionSelected,
    required this.fieldRefreshVersionOf,
    required this.actionKey,
    required this.variableSuggestions,
  });

  Key _parameterInputKey(String paramKey) {
    final version = fieldRefreshVersionOf(paramKey);
    return ValueKey('param-input-${action.id}-$paramKey-v$version');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(action.type.icon, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    action.type.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('action-key-${action.id}'),
              initialValue: actionKey,
              decoration: const InputDecoration(
                labelText: 'Action Key',
                border: OutlineInputBorder(),
              ),
              onChanged: (newValue) => onParameterChanged('key', newValue),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enabled'),
                    value: action.enabled,
                    onChanged:
                        (value) => onParameterChanged('__enabled__', value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: action.onErrorMode,
                    decoration: const InputDecoration(
                      labelText: 'On Error',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'stop', child: Text('Stop')),
                      DropdownMenuItem(
                        value: 'continue',
                        child: Text('Continue'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onParameterChanged('__onErrorMode__', value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...action.type.parameterDefinitions.map((paramDef) {
              final currentValue = action.parameters[paramDef.key];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildParameterField(context, paramDef, currentValue),
              );
            }),
            if (action.type == BotCreatorActionType.httpRequest)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showTestRequestModal(context),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send Test Request & Auto-Detect Routes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                      foregroundColor: Colors.blueAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Parses a JSON response and returns a flat list of JSON Path dot notations
  List<String> _extractPaths(dynamic data, [String currentPath = '\$']) {
    List<String> paths = [];
    if (data is Map) {
      for (final key in data.keys) {
        final newPath = '$currentPath.$key';
        paths.add(newPath);
        paths.addAll(_extractPaths(data[key], newPath));
      }
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        final newPath = '$currentPath[$i]';
        paths.add(newPath);
        paths.addAll(_extractPaths(data[i], newPath));
      }
    }
    return paths;
  }

  void _showTestRequestModal(BuildContext context) {
    bool isLoading = true;
    int? statusCode;
    String? responseBody;
    String? errorMessage;
    List<String>? newPaths;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1e1e1e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (isLoading) {
              // Fire the request on first build frame using Futures
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  final urlStr = action.parameters['url']?.toString() ?? '';
                  if (urlStr.isEmpty) throw 'Please provide a valid URL.';

                  // Fallback for placeholders: the request might just fail, but we'll try to execute it as-is
                  final uri = Uri.parse(urlStr);
                  final method =
                      (action.parameters['method']?.toString() ?? 'GET')
                          .toUpperCase();

                  final rawHeadersMap = action.parameters['headers'];
                  final Map<String, String> requestHeaders = {};
                  if (rawHeadersMap is Map) {
                    for (final entry in rawHeadersMap.entries) {
                      requestHeaders[entry.key.toString()] =
                          entry.value?.toString() ?? '';
                    }
                  }

                  http.Response response;
                  if (method == 'POST') {
                    final dynamic bodyData =
                        action.parameters['bodyMode'] == 'json'
                            ? jsonEncode(action.parameters['bodyJson'])
                            : action.parameters['bodyText'];
                    if (action.parameters['bodyMode'] == 'json' &&
                        !requestHeaders.containsKey('Content-Type')) {
                      requestHeaders['Content-Type'] = 'application/json';
                    }
                    response = await http.post(
                      uri,
                      headers: requestHeaders,
                      body: bodyData,
                    );
                  } else if (method == 'PUT') {
                    final dynamic bodyData =
                        action.parameters['bodyMode'] == 'json'
                            ? jsonEncode(action.parameters['bodyJson'])
                            : action.parameters['bodyText'];
                    if (action.parameters['bodyMode'] == 'json' &&
                        !requestHeaders.containsKey('Content-Type')) {
                      requestHeaders['Content-Type'] = 'application/json';
                    }
                    response = await http.put(
                      uri,
                      headers: requestHeaders,
                      body: bodyData,
                    );
                  } else if (method == 'PATCH') {
                    final dynamic bodyData =
                        action.parameters['bodyMode'] == 'json'
                            ? jsonEncode(action.parameters['bodyJson'])
                            : action.parameters['bodyText'];
                    if (action.parameters['bodyMode'] == 'json' &&
                        !requestHeaders.containsKey('Content-Type')) {
                      requestHeaders['Content-Type'] = 'application/json';
                    }
                    response = await http.patch(
                      uri,
                      headers: requestHeaders,
                      body: bodyData,
                    );
                  } else if (method == 'DELETE') {
                    response = await http.delete(uri, headers: requestHeaders);
                  } else {
                    response = await http.get(uri, headers: requestHeaders);
                  }

                  statusCode = response.statusCode;
                  responseBody = response.body;

                  try {
                    final decodedJson = jsonDecode(responseBody!);
                    newPaths = _extractPaths(decodedJson);
                    // Update parameter so the extractJsonPath combobox actually uses the new paths
                    if (newPaths != null && newPaths!.isNotEmpty) {
                      onParameterChanged('_cachedJsonPaths', newPaths!);
                    }
                  } catch (_) {
                    // Not valid JSON to parse paths from, ignore.
                  }

                  setModalState(() => isLoading = false);
                } catch (e) {
                  setModalState(() {
                    isLoading = false;
                    errorMessage = e.toString();
                  });
                }
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, controller) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Test Request Results',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.grey),
                      if (isLoading)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (errorMessage != null)
                        Expanded(
                          child: SingleChildScrollView(
                            controller: controller,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.5),
                                ),
                              ),
                              child: SelectableText(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    statusCode != null &&
                                            statusCode! >= 200 &&
                                            statusCode! < 300
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      statusCode != null &&
                                              statusCode! >= 200 &&
                                              statusCode! < 300
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ),
                              child: Text(
                                'Status: $statusCode',
                                style: TextStyle(
                                  color:
                                      statusCode != null &&
                                              statusCode! >= 200 &&
                                              statusCode! < 300
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (newPaths != null && newPaths!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: Text(
                                  '${newPaths!.length} paths parsed',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Response Body (Raw):',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xff2b2b2b),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: SingleChildScrollView(
                              controller: controller,
                              child: HighlightView(
                                responseBody ?? '',
                                language: 'json',
                                theme: darculaTheme,
                                textStyle: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildParameterField(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    switch (paramDef.type) {
      case ParameterType.boolean:
        return Row(
          children: [
            Expanded(
              child: Text(
                _formatParameterName(paramDef.key),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Switch(
              value: currentValue ?? paramDef.defaultValue,
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
          ],
        );

      case ParameterType.number:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _formatParameterName(paramDef.key),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (paramDef.required)
                  const Text(
                    ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: paramDef.hint,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixText:
                    paramDef.minValue != null && paramDef.maxValue != null
                        ? '${paramDef.minValue}-${paramDef.maxValue}'
                        : null,
              ),
              onChanged: (newValue) {
                final trimmed = newValue.trim();
                if (trimmed.isEmpty) {
                  onParameterChanged(paramDef.key, '');
                  return;
                }

                final intValue = int.tryParse(trimmed);
                if (intValue != null) {
                  // Vérifier les limites
                  if (paramDef.minValue != null &&
                      intValue < paramDef.minValue!) {
                    return;
                  }
                  if (paramDef.maxValue != null &&
                      intValue > paramDef.maxValue!) {
                    return;
                  }
                  onParameterChanged(paramDef.key, intValue);
                  return;
                }

                onParameterChanged(paramDef.key, trimmed);
              },
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
              isNumericField: true,
            ),
          ],
        );

      case ParameterType.list:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatParameterName(paramDef.key),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed:
                      () => _showListEditor(context, paramDef, currentValue),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentValue is List && currentValue.isNotEmpty)
                    ...currentValue.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${entry.key + 1}. ${entry.value}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    })
                  else
                    Text(
                      'No items - tap edit to add',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

      case ParameterType.multiSelect:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue:
                  currentValue?.toString() ?? paramDef.defaultValue.toString(),
              decoration: InputDecoration(
                hintText: paramDef.hint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items:
                  paramDef.options?.map((option) {
                    return DropdownMenuItem(value: option, child: Text(option));
                  }).toList(),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.duration:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              decoration: InputDecoration(
                hintText: paramDef.hint ?? 'e.g., 5m, 1h, 30s',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixText: 's/m/h/d',
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.url:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: paramDef.hint ?? 'https://example.com',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.link, size: 20),
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.userId:
      case ParameterType.channelId:
      case ParameterType.messageId:
      case ParameterType.roleId:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              decoration: InputDecoration(
                hintText: paramDef.hint ?? 'Enter ${paramDef.type.name}',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(_getIconForIdType(paramDef.type), size: 20),
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
          ],
        );

      case ParameterType.emoji:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: _parameterInputKey(paramDef.key),
                    initialValue:
                        (currentValue ?? paramDef.defaultValue).toString(),
                    decoration: InputDecoration(
                      hintText: paramDef.hint ?? 'Enter emoji or :name:',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.emoji_emotions, size: 20),
                    ),
                    onChanged:
                        (newValue) =>
                            onParameterChanged(paramDef.key, newValue),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    currentValue?.toString() ?? '😀',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.color:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: _parameterInputKey(paramDef.key),
                    initialValue:
                        (currentValue ?? paramDef.defaultValue).toString(),
                    decoration: InputDecoration(
                      hintText: paramDef.hint ?? '#FFFFFF or rgb(255,255,255)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.color_lens, size: 20),
                    ),
                    onChanged:
                        (newValue) =>
                            onParameterChanged(paramDef.key, newValue),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap:
                      () => _showColorPicker(context, paramDef, currentValue),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _parseColor(currentValue?.toString() ?? '#000000'),
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.map:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatParameterName(paramDef.key),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed:
                      () => _showMapEditor(context, paramDef, currentValue),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildMapPreview(paramDef.key, currentValue),
            ),
          ],
        );

      case ParameterType.componentV2:
        final compDef =
            currentValue is Map<String, dynamic>
                ? ComponentV2Definition.fromJson(currentValue)
                : currentValue is Map
                ? ComponentV2Definition.fromJson(
                  Map<String, dynamic>.from(
                    currentValue.map((k, v) => MapEntry(k.toString(), v)),
                  ),
                )
                : ComponentV2Definition();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ComponentV2EditorWidget(
              definition: compDef,
              onChanged: (updated) {
                onParameterChanged(paramDef.key, updated.toJson());
              },
            ),
          ],
        );

      case ParameterType.modalDefinition:
        final modalDef =
            currentValue is Map<String, dynamic>
                ? ModalDefinition.fromJson(currentValue)
                : currentValue is Map
                ? ModalDefinition.fromJson(
                  Map<String, dynamic>.from(
                    currentValue.map((k, v) => MapEntry(k.toString(), v)),
                  ),
                )
                : ModalDefinition();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ModalBuilderWidget(
              modal: modalDef,
              onChanged: (updated) {
                onParameterChanged(paramDef.key, updated.toJson());
              },
            ),
          ],
        );

      default: // ParameterType.string and ParameterType.url and others
        if (paramDef.key == 'extractJsonPath' &&
            action.type == BotCreatorActionType.httpRequest) {
          final cachedPaths =
              action.parameters['_cachedJsonPaths'] as List<dynamic>? ?? [];
          final stringPaths = cachedPaths.map((e) => e.toString()).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatParameterName(paramDef.key),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return stringPaths;
                  }
                  return stringPaths.where((String option) {
                    return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                onSelected: (String selection) {
                  onParameterChanged(paramDef.key, selection);
                },
                fieldViewBuilder: (
                  context,
                  controller,
                  focusNode,
                  onEditingComplete,
                ) {
                  if (controller.text != (currentValue?.toString() ?? '') &&
                      controller.text.isEmpty) {
                    controller.text = currentValue?.toString() ?? '';
                  }
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onEditingComplete: () {
                      onParameterChanged(paramDef.key, controller.text);
                      onEditingComplete();
                    },
                    onChanged: (val) {
                      onParameterChanged(paramDef.key, val);
                    },
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: paramDef.hint,
                      suffixIcon:
                          stringPaths.isNotEmpty
                              ? const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.blueAccent,
                              )
                              : null,
                    ),
                  );
                },
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _formatParameterName(paramDef.key),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (paramDef.required)
                  const Text(
                    ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              maxLines: paramDef.key.toLowerCase().contains('content') ? 3 : 1,
              decoration: InputDecoration(
                hintText: paramDef.hint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );
    }
  }

  List<Widget> _buildVariableSuggestionsForParam({
    required String paramKey,
    required dynamic value,
    bool isNumericField = false,
  }) {
    final rawValue = value?.toString() ?? '';
    final query = _extractPlaceholderQuery(rawValue);
    if (query == null) {
      return const [];
    }

    final normalizedQuery = query.trim().toLowerCase();
    final filteredByKind =
        isNumericField
            ? variableSuggestions.where(
              (item) => item.isNumeric || item.isUnknown,
            )
            : variableSuggestions;

    final suggestions =
        filteredByKind
            .where(
              (item) =>
                  normalizedQuery.isEmpty ||
                  item.name.toLowerCase().contains(normalizedQuery),
            )
            .take(8)
            .toList();

    if (suggestions.isEmpty) {
      return const [];
    }

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
            suggestions
                .map(
                  (item) => ActionChip(
                    label: Text('((${item.name}))'),
                    onPressed: () {
                      final nextValue = _insertVariableInOpenPlaceholder(
                        rawValue,
                        item.name,
                      );
                      onSuggestionSelected(paramKey, nextValue);
                    },
                  ),
                )
                .toList(),
      ),
    ];
  }

  String? _extractPlaceholderQuery(String input) {
    final start = input.lastIndexOf('((');
    if (start == -1) {
      return null;
    }

    final afterStart = input.substring(start + 2);
    if (afterStart.contains('))')) {
      return null;
    }

    final parts = afterStart.split('|');
    return parts.last.trimLeft();
  }

  String _insertVariableInOpenPlaceholder(String input, String variableName) {
    final start = input.lastIndexOf('((');
    if (start == -1) {
      return '(($variableName))';
    }

    final beforeStart = input.substring(0, start);
    final afterStart = input.substring(start + 2);

    if (afterStart.contains('))')) {
      return input;
    }

    final parts = afterStart.split('|');
    final prefixParts =
        parts.length > 1 ? parts.sublist(0, parts.length - 1) : <String>[];
    final previous = prefixParts
        .map((entry) => entry.trim())
        .where((e) => e.isNotEmpty);
    final merged = [...previous, variableName];
    final inner = merged.join(' | ');

    return '$beforeStart(($inner))';
  }

  // Méthodes utilitaires
  void _showListEditor(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    final maxHeight = MediaQuery.of(context).size.height * 0.55;
    final List<String> items = List<String>.from(currentValue ?? []);
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Edit ${_formatParameterName(paramDef.key)}'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: maxHeight,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  hintText: 'Add new item',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (value) {
                                  if (value.trim().isNotEmpty) {
                                    setDialogState(() {
                                      items.add(value.trim());
                                      controller.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                if (controller.text.trim().isNotEmpty) {
                                  setDialogState(() {
                                    items.add(controller.text.trim());
                                    controller.clear();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(items[index]),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      () => setDialogState(
                                        () => items.removeAt(index),
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        onParameterChanged(paramDef.key, items);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showColorPicker(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Choose ${_formatParameterName(paramDef.key)}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        '#FF0000',
                        '#00FF00',
                        '#0000FF',
                        '#FFFF00',
                        '#FF00FF',
                        '#00FFFF',
                        '#000000',
                        '#FFFFFF',
                        '#808080',
                        '#FFA500',
                        '#800080',
                        '#008000',
                      ].map((colorHex) {
                        return GestureDetector(
                          onTap: () {
                            onParameterChanged(paramDef.key, colorHex);
                            Navigator.pop(dialogContext);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _parseColor(colorHex),
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showMapEditor(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    if (paramDef.key == 'headers') {
      _showHeadersEditor(context, paramDef, currentValue);
      return;
    }
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    final rawMap =
        (currentValue is Map)
            ? Map<String, dynamic>.from(currentValue.cast<String, dynamic>())
            : <String, dynamic>{};

    // We start in edit mode but with validation checking
    showDialog(
      context: context,
      builder: (dialogContext) {
        final TextEditingController jsonController = TextEditingController(
          text: const JsonEncoder.withIndent('  ').convert(rawMap),
        );
        String? errorMessage;
        bool isPreviewMode = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void validateJson(String text) {
              if (text.trim().isEmpty) {
                setDialogState(() => errorMessage = null);
                return;
              }
              try {
                final decoded = jsonDecode(text);
                if (decoded is! Map) {
                  setDialogState(
                    () => errorMessage = 'Root must be a JSON object {...}',
                  );
                } else {
                  setDialogState(() => errorMessage = null);
                }
              } catch (e) {
                setDialogState(() => errorMessage = e.toString());
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text('Edit ${_formatParameterName(paramDef.key)}'),
                  ),
                  IconButton(
                    icon: Icon(isPreviewMode ? Icons.code : Icons.visibility),
                    tooltip:
                        isPreviewMode
                            ? 'Edit Raw JSON'
                            : 'Preview Highlighted JSON',
                    onPressed: () {
                      if (!isPreviewMode) {
                        // Before switching to preview, format the JSON to ensure it's pretty
                        try {
                          final decoded = jsonDecode(
                            jsonController.text.trim(),
                          );
                          if (decoded is Map) {
                            jsonController.text = const JsonEncoder.withIndent(
                              '  ',
                            ).convert(decoded);
                          }
                        } catch (_) {}
                      }
                      setDialogState(() => isPreviewMode = !isPreviewMode);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_align_left),
                    tooltip: 'Format JSON',
                    onPressed: () {
                      try {
                        final decoded = jsonDecode(jsonController.text.trim());
                        if (decoded is Map) {
                          setDialogState(() {
                            jsonController.text = const JsonEncoder.withIndent(
                              '  ',
                            ).convert(decoded);
                            errorMessage = null;
                          });
                        }
                      } catch (e) {
                        setDialogState(
                          () => errorMessage = 'Cannot format: Invalid JSON',
                        );
                      }
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isPreviewMode)
                      Text(
                        'JSON object editor (supports nested objects/arrays)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          isPreviewMode
                              ? Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: SingleChildScrollView(
                                  child: HighlightView(
                                    jsonController.text.trim().isEmpty
                                        ? '{}'
                                        : jsonController.text,
                                    language: 'json',
                                    theme: darculaTheme,
                                    padding: const EdgeInsets.all(12),
                                    textStyle: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                              : TextField(
                                controller: jsonController,
                                maxLines: null,
                                expands: true,
                                keyboardType: TextInputType.multiline,
                                onChanged: validateJson,
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                  errorText: errorMessage,
                                ),
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      errorMessage != null
                          ? null
                          : () {
                            try {
                              final text = jsonController.text.trim();
                              if (text.isEmpty) {
                                onParameterChanged(
                                  paramDef.key,
                                  <String, dynamic>{},
                                );
                                Navigator.pop(dialogContext);
                                return;
                              }
                              final decoded = jsonDecode(text);
                              if (decoded is! Map) {
                                setDialogState(
                                  () =>
                                      errorMessage =
                                          'Root must be a JSON object',
                                );
                                return;
                              }

                              onParameterChanged(
                                paramDef.key,
                                Map<String, dynamic>.from(decoded),
                              );
                              Navigator.pop(dialogContext);
                            } catch (error) {
                              setDialogState(
                                () => errorMessage = error.toString(),
                              );
                            }
                          },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMapPreview(String key, dynamic currentValue) {
    if (currentValue is Map && currentValue.isNotEmpty) {
      if (key == 'headers') {
        final entries = currentValue.entries.toList();
        final preview = entries
            .take(6)
            .map((entry) {
              final headerKey = entry.key.toString();
              final headerValue = entry.value?.toString() ?? '';
              return '$headerKey: $headerValue';
            })
            .join('\n');
        final extraCount = entries.length - 6;
        return SelectableText(
          extraCount > 0 ? '$preview\n… ($extraCount more)' : preview,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        );
      }

      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xff2b2b2b), // darcula background
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(8),
        child: HighlightView(
          const JsonEncoder.withIndent('  ').convert(currentValue),
          language: 'json',
          theme: darculaTheme,
          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      );
    }

    return Text(
      key == 'headers'
          ? 'No headers - tap edit to add'
          : 'No properties - tap edit to configure',
      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
    );
  }

  void _showHeadersEditor(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    final Map<String, dynamic> rawMap =
        (currentValue is Map)
            ? Map<String, dynamic>.from(currentValue.cast<String, dynamic>())
            : <String, dynamic>{};

    final List<Map<String, TextEditingController>> headers =
        rawMap.entries
            .map(
              (entry) => {
                'keyController': TextEditingController(text: entry.key),
                'valueController': TextEditingController(
                  text: entry.value?.toString() ?? '',
                ),
              },
            )
            .toList();

    if (headers.isEmpty) {
      headers.add({
        'keyController': TextEditingController(),
        'valueController': TextEditingController(),
      });
    }

    final pasteController = TextEditingController();

    const commonHeaders = [
      'Authorization',
      'Content-Type',
      'Accept',
      'User-Agent',
      'Cache-Control',
      'Host',
      'Connection',
      'Origin',
      'Referer',
      'X-Requested-With',
      'Access-Control-Allow-Origin',
    ];

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Edit ${_formatParameterName(paramDef.key)}'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: maxHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HTTP Headers (Key/Value pairs)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: headers.length,
                            itemBuilder: (context, index) {
                              final keyController =
                                  headers[index]['keyController']!;
                              final valueController =
                                  headers[index]['valueController']!;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Autocomplete<String>(
                                        optionsBuilder: (
                                          TextEditingValue textEditingValue,
                                        ) {
                                          if (textEditingValue.text == '') {
                                            return commonHeaders;
                                          }
                                          return commonHeaders.where((
                                            String option,
                                          ) {
                                            return option
                                                .toLowerCase()
                                                .contains(
                                                  textEditingValue.text
                                                      .toLowerCase(),
                                                );
                                          });
                                        },
                                        onSelected: (String selection) {
                                          keyController.text = selection;
                                        },
                                        fieldViewBuilder: (
                                          context,
                                          controller,
                                          focusNode,
                                          onEditingComplete,
                                        ) {
                                          // Sync initial value since Autocomplete creates its own controller initially empty
                                          if (controller.text !=
                                                  keyController.text &&
                                              controller.text.isEmpty) {
                                            controller.text =
                                                keyController.text;
                                          }
                                          controller.addListener(() {
                                            keyController.text =
                                                controller.text;
                                          });

                                          return TextField(
                                            controller: controller,
                                            focusNode: focusNode,
                                            onEditingComplete:
                                                onEditingComplete,
                                            decoration: const InputDecoration(
                                              hintText: 'Key',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 6,
                                      child: TextField(
                                        controller: valueController,
                                        decoration: const InputDecoration(
                                          hintText: 'Value',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        maxLines: null,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          if (headers.length > 1) {
                                            headers.removeAt(index);
                                          } else {
                                            keyController.clear();
                                            valueController.clear();
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  headers.add({
                                    'keyController': TextEditingController(),
                                    'valueController': TextEditingController(),
                                  });
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add header'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  for (final entry in headers) {
                                    entry['keyController']!.clear();
                                    entry['valueController']!.clear();
                                  }
                                  // Keep at least one empty row
                                  if (headers.length > 1) {
                                    headers.removeRange(1, headers.length);
                                  }
                                });
                              },
                              child: const Text('Clear all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        Text(
                          'Bulk import (Paste headers like Key: Value)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: pasteController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Authorization: Bearer ...\nAccept: application/json',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final raw = pasteController.text.trim();
                                if (raw.isEmpty) {
                                  return;
                                }
                                final lines = raw.split(RegExp(r'\r?\n'));
                                setDialogState(() {
                                  // Remove empty rows if any
                                  headers.removeWhere(
                                    (entry) =>
                                        entry['keyController']!.text
                                            .trim()
                                            .isEmpty &&
                                        entry['valueController']!.text
                                            .trim()
                                            .isEmpty,
                                  );

                                  for (final line in lines) {
                                    final separatorIndex = line.indexOf(':');
                                    if (separatorIndex <= 0) {
                                      continue;
                                    }
                                    final key =
                                        line
                                            .substring(0, separatorIndex)
                                            .trim();
                                    final value =
                                        line
                                            .substring(separatorIndex + 1)
                                            .trim();
                                    if (key.isEmpty) {
                                      continue;
                                    }
                                    headers.add({
                                      'keyController': TextEditingController(
                                        text: key,
                                      ),
                                      'valueController': TextEditingController(
                                        text: value,
                                      ),
                                    });
                                  }
                                  pasteController.clear();

                                  // Add empty row if everything is clear
                                  if (headers.isEmpty) {
                                    headers.add({
                                      'keyController': TextEditingController(),
                                      'valueController':
                                          TextEditingController(),
                                    });
                                  }
                                });
                              },
                              child: const Text('Import'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final Map<String, dynamic> result = {};
                        for (final entry in headers) {
                          final key = entry['keyController']!.text.trim();
                          final value = entry['valueController']!.text.trim();
                          if (key.isNotEmpty) {
                            result[key] = value;
                          }
                        }
                        onParameterChanged(paramDef.key, result);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  IconData _getIconForIdType(ParameterType type) {
    switch (type) {
      case ParameterType.userId:
        return Icons.person;
      case ParameterType.channelId:
        return Icons.tag;
      case ParameterType.messageId:
        return Icons.message;
      case ParameterType.roleId:
        return Icons.admin_panel_settings;
      default:
        return Icons.tag;
    }
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(
          int.parse(colorString.substring(1), radix: 16) + 0xFF000000,
        );
      }
      return Colors.black;
    } catch (e) {
      return Colors.black;
    }
  }

  String _formatParameterName(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
