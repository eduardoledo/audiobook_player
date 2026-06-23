import 'package:flutter/material.dart';

import '../service_locator.dart';
import '../services/library_storage.dart';

class SeriesMappingScreen extends StatefulWidget {
  const SeriesMappingScreen({super.key});

  @override
  State<SeriesMappingScreen> createState() => _SeriesMappingScreenState();
}

class _SeriesMappingScreenState extends State<SeriesMappingScreen> {
  final _storage = getIt<LibraryStorage>();
  Map<String, List<String>> _rules = {};
  bool _isLoading = true;

  final _seriesController = TextEditingController();
  final _patternController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final rules = await _storage.getSeriesMappingRules();
    setState(() {
      _rules = rules;
      _isLoading = false;
    });
  }

  Future<void> _saveRules() async {
    await _storage.saveSeriesMappingRules(_rules);
  }

  void _addRule() {
    final series = _seriesController.text.trim();
    final pattern = _patternController.text.trim();

    if (series.isEmpty || pattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both series name and pattern')),
      );
      return;
    }

    try {
      RegExp(pattern); // Validate regex
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid regular expression')),
      );
      return;
    }

    setState(() {
      if (!_rules.containsKey(series)) {
        _rules[series] = [];
      }
      if (!_rules[series]!.contains(pattern)) {
        _rules[series]!.add(pattern);
      }
    });

    _seriesController.clear();
    _patternController.clear();
    _saveRules();
  }

  void _removeRule(String series, String pattern) {
    setState(() {
      _rules[series]?.remove(pattern);
      if (_rules[series]?.isEmpty ?? true) {
        _rules.remove(series);
      }
    });
    _saveRules();
  }

  void _editSeriesName(String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Edit Saga Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                setState(() {
                  final patterns = _rules.remove(oldName);
                  if (patterns != null) {
                    // Merge if the new name already exists
                    if (_rules.containsKey(newName)) {
                      _rules[newName]!.addAll(patterns);
                      _rules[newName] = _rules[newName]!.toSet().toList(); // Remove duplicates
                    } else {
                      _rules[newName] = patterns;
                    }
                  }
                });
                _saveRules();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFFE8B86D))),
          ),
        ],
      ),
    );
  }

  void _editPattern(String series, String oldPattern) {
    final controller = TextEditingController(text: oldPattern);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Edit Pattern', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              final newPattern = controller.text.trim();
              if (newPattern.isNotEmpty && newPattern != oldPattern) {
                try {
                  RegExp(newPattern);
                  setState(() {
                    final index = _rules[series]?.indexOf(oldPattern) ?? -1;
                    if (index != -1) {
                      _rules[series]![index] = newPattern;
                      // Remove duplicates if editing resulted in same pattern
                      _rules[series] = _rules[series]!.toSet().toList();
                    }
                  });
                  _saveRules();
                  Navigator.pop(ctx);
                } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid regular expression')),
                   );
                }
              } else {
                 Navigator.pop(ctx);
              }
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFFE8B86D))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Series Mapping Rules'),
        backgroundColor: const Color(0xFF252525),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8B86D)))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF252525),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add a new mapping rule',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _seriesController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Saga / Series Name',
                          labelStyle: TextStyle(color: Colors.white54),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _patternController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Regex Pattern (variables: ?<year>, ?<title>, ?<author>)',
                                labelStyle: TextStyle(color: Colors.white54),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addRule,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE8B86D),
                              foregroundColor: const Color(0xFF1A1A1A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _rules.isEmpty
                      ? Center(
                          child: Text(
                            'No mapping rules defined.',
                            style: TextStyle(color: Colors.white.withOpacity(0.5)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _rules.keys.length,
                          itemBuilder: (context, index) {
                            final series = _rules.keys.elementAt(index);
                            final patterns = _rules[series]!;

                            return Card(
                              color: const Color(0xFF333333),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            series,
                                            style: const TextStyle(
                                              color: Color(0xFFE8B86D),
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                                          onPressed: () => _editSeriesName(series),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...patterns.map((pattern) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.code, size: 16, color: Colors.white54),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              pattern,
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                                            onPressed: () => _editPattern(series, pattern),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                            onPressed: () => _removeRule(series, pattern),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
