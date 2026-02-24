import 'package:flutter/material.dart';

class ResponseEmbedsEditor extends StatefulWidget {
  final List<Map<String, dynamic>> embeds;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final int maxEmbeds;

  const ResponseEmbedsEditor({
    super.key,
    required this.embeds,
    required this.onChanged,
    this.maxEmbeds = 10,
  });

  @override
  State<ResponseEmbedsEditor> createState() => _ResponseEmbedsEditorState();
}

class _ResponseEmbedsEditorState extends State<ResponseEmbedsEditor> {
  List<Map<String, dynamic>> _embeds = [];

  @override
  void initState() {
    super.initState();
    _embeds = widget.embeds.map(_normalizeEmbed).toList();
  }

  @override
  void didUpdateWidget(covariant ResponseEmbedsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.embeds != widget.embeds) {
      _embeds = widget.embeds.map(_normalizeEmbed).toList();
    }
  }

  Map<String, dynamic> _normalizeEmbed(Map<String, dynamic> embed) {
    return {
      'title': (embed['title'] ?? '').toString(),
      'type': (embed['type'] ?? 'rich').toString(),
      'description': (embed['description'] ?? '').toString(),
      'url': (embed['url'] ?? '').toString(),
      'timestamp': (embed['timestamp'] ?? '').toString(),
      'color': (embed['color'] ?? '').toString(),
      'footer': {
        'text': (embed['footer']?['text'] ?? '').toString(),
        'icon_url': (embed['footer']?['icon_url'] ?? '').toString(),
      },
      'image': {'url': (embed['image']?['url'] ?? '').toString()},
      'thumbnail': {'url': (embed['thumbnail']?['url'] ?? '').toString()},
      'author': {
        'name': (embed['author']?['name'] ?? '').toString(),
        'url': (embed['author']?['url'] ?? '').toString(),
        'icon_url': (embed['author']?['icon_url'] ?? '').toString(),
      },
      'fields':
          (embed['fields'] is List)
              ? List<Map<String, dynamic>>.from(
                (embed['fields'] as List).whereType<Map>().map(
                  (field) => {
                    'name': (field['name'] ?? '').toString(),
                    'value': (field['value'] ?? '').toString(),
                    'inline': field['inline'] == true,
                  },
                ),
              ).take(25).toList()
              : <Map<String, dynamic>>[],
    };
  }

  void _emit() {
    widget.onChanged(List<Map<String, dynamic>>.from(_embeds));
  }

  void _addEmbed() {
    if (_embeds.length >= widget.maxEmbeds) return;
    setState(() {
      _embeds.add(_normalizeEmbed(const {}));
    });
    _emit();
  }

  void _removeEmbed(int index) {
    setState(() {
      _embeds.removeAt(index);
    });
    _emit();
  }

  void _setEmbedValue(int index, String key, dynamic value) {
    setState(() {
      _embeds[index][key] = value;
    });
    _emit();
  }

  void _setNestedValue(int index, String key, String nestedKey, dynamic value) {
    setState(() {
      final nested = Map<String, dynamic>.from(_embeds[index][key] ?? {});
      nested[nestedKey] = value;
      _embeds[index][key] = nested;
    });
    _emit();
  }

  void _addField(int index) {
    final fields = List<Map<String, dynamic>>.from(
      _embeds[index]['fields'] ?? [],
    );
    if (fields.length >= 25) return;

    setState(() {
      fields.add({'name': '', 'value': '', 'inline': false});
      _embeds[index]['fields'] = fields;
    });
    _emit();
  }

  void _removeField(int embedIndex, int fieldIndex) {
    final fields = List<Map<String, dynamic>>.from(
      _embeds[embedIndex]['fields'] ?? [],
    );
    setState(() {
      fields.removeAt(fieldIndex);
      _embeds[embedIndex]['fields'] = fields;
    });
    _emit();
  }

  void _setFieldValue(
    int embedIndex,
    int fieldIndex,
    String key,
    dynamic value,
  ) {
    final fields = List<Map<String, dynamic>>.from(
      _embeds[embedIndex]['fields'] ?? [],
    );
    setState(() {
      fields[fieldIndex][key] = value;
      _embeds[embedIndex]['fields'] = fields;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Response Embeds (${_embeds.length}/${widget.maxEmbeds})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            IconButton(
              onPressed: _embeds.length >= widget.maxEmbeds ? null : _addEmbed,
              icon: const Icon(Icons.add, size: 20),
              tooltip: 'Add embed',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_embeds.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              'No embeds. You can add up to 10 embeds.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._embeds.asMap().entries.map((entry) {
            final index = entry.key;
            final embed = entry.value;
            final footer = Map<String, dynamic>.from(embed['footer'] ?? {});
            final image = Map<String, dynamic>.from(embed['image'] ?? {});
            final thumbnail = Map<String, dynamic>.from(
              embed['thumbnail'] ?? {},
            );
            final author = Map<String, dynamic>.from(embed['author'] ?? {});
            final fields = List<Map<String, dynamic>>.from(
              embed['fields'] ?? [],
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Embed #${index + 1}'),
                        IconButton(
                          onPressed: () => _removeEmbed(index),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: embed['title']?.toString() ?? '',
                      maxLength: 256,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      onChanged:
                          (value) => _setEmbedValue(index, 'title', value),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: embed['description']?.toString() ?? '',
                      maxLength: 2000,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      onChanged:
                          (value) =>
                              _setEmbedValue(index, 'description', value),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: embed['url']?.toString() ?? '',
                      decoration: const InputDecoration(
                        labelText: 'URL',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _setEmbedValue(index, 'url', value),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 280,
                          child: TextFormField(
                            initialValue: embed['timestamp']?.toString() ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Timestamp (ISO8601)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged:
                                (value) =>
                                    _setEmbedValue(index, 'timestamp', value),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextFormField(
                            initialValue: embed['color']?.toString() ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Color (int or #hex)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged:
                                (value) =>
                                    _setEmbedValue(index, 'color', value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Footer'),
                      children: [
                        TextFormField(
                          initialValue: footer['text']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Footer Text',
                            border: OutlineInputBorder(),
                          ),
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'footer',
                                'text',
                                value,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: footer['icon_url']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Footer Icon URL',
                            border: OutlineInputBorder(),
                          ),
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'footer',
                                'icon_url',
                                value,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Author'),
                      children: [
                        TextFormField(
                          initialValue: author['name']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Author Name',
                            border: OutlineInputBorder(),
                          ),
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'author',
                                'name',
                                value,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: author['url']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Author URL',
                            border: OutlineInputBorder(),
                          ),
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'author',
                                'url',
                                value,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: author['icon_url']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Author Icon URL',
                            border: OutlineInputBorder(),
                          ),
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'author',
                                'icon_url',
                                value,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Media'),
                      children: [
                        TextFormField(
                          initialValue: image['url']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Image URL',
                            border: OutlineInputBorder(),
                          ),
                          onChanged:
                              (value) =>
                                  _setNestedValue(index, 'image', 'url', value),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: thumbnail['url']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Thumbnail URL',
                            border: OutlineInputBorder(),
                          ),
                          onChanged:
                              (value) => _setNestedValue(
                                index,
                                'thumbnail',
                                'url',
                                value,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Fields (${fields.length}/25)'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed:
                            fields.length >= 25 ? null : () => _addField(index),
                      ),
                      children: [
                        if (fields.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text('No fields yet.'),
                          )
                        else
                          ...fields.asMap().entries.map((fieldEntry) {
                            final fieldIndex = fieldEntry.key;
                            final field = fieldEntry.value;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Field #${fieldIndex + 1}'),
                                        IconButton(
                                          onPressed:
                                              () => _removeField(
                                                index,
                                                fieldIndex,
                                              ),
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextFormField(
                                      initialValue:
                                          field['name']?.toString() ?? '',
                                      decoration: const InputDecoration(
                                        labelText: 'Name',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged:
                                          (value) => _setFieldValue(
                                            index,
                                            fieldIndex,
                                            'name',
                                            value,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      initialValue:
                                          field['value']?.toString() ?? '',
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        labelText: 'Value',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged:
                                          (value) => _setFieldValue(
                                            index,
                                            fieldIndex,
                                            'value',
                                            value,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Inline'),
                                      value: field['inline'] == true,
                                      onChanged:
                                          (value) => _setFieldValue(
                                            index,
                                            fieldIndex,
                                            'inline',
                                            value,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
