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
  List<String> _globalPatterns = [];
  Map<String, String> _sagaCodes = {};
  
  bool _isLoading = true;

  // Controllers for Specific Rules
  final _seriesController = TextEditingController();
  final _patternController = TextEditingController();
  
  // Controllers for Global Patterns
  final _globalPatternController = TextEditingController();
  
  // Controllers for Saga Codes
  final _codeController = TextEditingController();
  final _codeSagaController = TextEditingController();

  // Controllers for Simulator
  final _simTestController = TextEditingController();
  final _simRegexController = TextEditingController();
  String? _simError;
  RegExpMatch? _simMatch;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final rules = await _storage.getSeriesMappingRules();
    final globals = await _storage.getGlobalPatterns();
    final codes = await _storage.getSagaCodes();
    
    setState(() {
      _rules = rules;
      _globalPatterns = globals;
      _sagaCodes = codes;
      _isLoading = false;
    });
  }

  // --- Specific Rules Logic ---
  
  void _saveRules() {
    _storage.saveSeriesMappingRules(_rules);
  }

  void _addRule() {
    final series = _seriesController.text.trim();
    final pattern = _patternController.text.trim();
    if (series.isEmpty || pattern.isEmpty) return;
    try { RegExp(pattern); } catch (_) { return; }

    setState(() {
      if (!_rules.containsKey(series)) _rules[series] = [];
      if (!_rules[series]!.contains(pattern)) _rules[series]!.add(pattern);
    });
    _seriesController.clear();
    _patternController.clear();
    _saveRules();
  }

  void _removeRule(String series, String pattern) {
    setState(() {
      _rules[series]?.remove(pattern);
      if (_rules[series]?.isEmpty ?? true) _rules.remove(series);
    });
    _saveRules();
  }

  // --- Global Patterns Logic ---
  
  void _saveGlobals() {
    _storage.saveGlobalPatterns(_globalPatterns);
  }

  void _addGlobalPattern() {
    final pattern = _globalPatternController.text.trim();
    if (pattern.isEmpty) return;
    try { RegExp(pattern); } catch (_) { return; }

    setState(() {
      if (!_globalPatterns.contains(pattern)) _globalPatterns.add(pattern);
    });
    _globalPatternController.clear();
    _saveGlobals();
  }

  void _removeGlobalPattern(String pattern) {
    setState(() {
      _globalPatterns.remove(pattern);
    });
    _saveGlobals();
  }

  // --- Saga Codes Logic ---
  
  void _saveCodes() {
    _storage.saveSagaCodes(_sagaCodes);
  }

  void _addCode() {
    final code = _codeController.text.trim().toUpperCase();
    final saga = _codeSagaController.text.trim();
    if (code.isEmpty || saga.isEmpty) return;

    setState(() {
      _sagaCodes[code] = saga;
    });
    _codeController.clear();
    _codeSagaController.clear();
    _saveCodes();
  }

  void _removeCode(String code) {
    setState(() {
      _sagaCodes.remove(code);
    });
    _saveCodes();
  }

  // --- Simulator Logic ---
  void _evaluateSimulator() {
    final testStr = _simTestController.text;
    final regexStr = _simRegexController.text;
    
    if (regexStr.isEmpty) {
      setState(() {
        _simError = null;
        _simMatch = null;
      });
      return;
    }

    try {
      final regExp = RegExp(regexStr, caseSensitive: false);
      setState(() {
        _simError = null;
        _simMatch = regExp.firstMatch(testStr);
      });
    } catch (e) {
      setState(() {
        _simError = 'Invalid Regular Expression';
        _simMatch = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          title: const Text('Series Mapping Rules'),
          backgroundColor: const Color(0xFF252525),
          bottom: const TabBar(
            indicatorColor: Color(0xFFE8B86D),
            labelColor: Color(0xFFE8B86D),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Specific'),
              Tab(text: 'Global'),
              Tab(text: 'Codes'),
              Tab(text: 'Simulator'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8B86D)))
            : TabBarView(
                children: [
                  _buildSpecificTab(),
                  _buildGlobalTab(),
                  _buildCodesTab(),
                  _buildSimulatorTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildSpecificTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF252525),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add a specific saga rule', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _patternController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Regex Pattern',
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
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8B86D), foregroundColor: const Color(0xFF1A1A1A)),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _rules.length,
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
                      Text(series, style: const TextStyle(color: Color(0xFFE8B86D), fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...patterns.map((pattern) => Row(
                        children: [
                          const Icon(Icons.code, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(child: Text(pattern, style: const TextStyle(fontFamily: 'monospace', color: Colors.white70))),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _removeRule(series, pattern), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                        ],
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF252525),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _globalPatternController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Add Global Regex Pattern',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addGlobalPattern,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8B86D), foregroundColor: const Color(0xFF1A1A1A)),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _globalPatterns.length,
            itemBuilder: (context, index) {
              final pattern = _globalPatterns[index];
              return Card(
                color: const Color(0xFF333333),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.public, color: Colors.white54),
                  title: Text(pattern, style: const TextStyle(fontFamily: 'monospace', color: Colors.white70)),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _removeGlobalPattern(pattern)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCodesTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF252525),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Saga Code (e.g., Code: HP, Saga: Harry Potter)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _codeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _codeSagaController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Saga Name',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addCode,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8B86D), foregroundColor: const Color(0xFF1A1A1A)),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _sagaCodes.length,
            itemBuilder: (context, index) {
              final code = _sagaCodes.keys.elementAt(index);
              final saga = _sagaCodes[code]!;
              return Card(
                color: const Color(0xFF333333),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: const Color(0xFFE8B86D).withValues(alpha: 0.2), child: Text(code, style: const TextStyle(color: Color(0xFFE8B86D), fontWeight: FontWeight.bold))),
                  title: Text(saga, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _removeCode(code)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatorTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF252525),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Test String (e.g. folder path or file name)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _simTestController,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => _evaluateSimulator(),
                decoration: const InputDecoration(
                  labelText: 'String to evaluate',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Regex Pattern', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE8B86D)),
                    color: const Color(0xFF333333),
                    tooltip: 'Select an existing pattern',
                    onSelected: (pattern) {
                      _simRegexController.text = pattern;
                      _evaluateSimulator();
                    },
                    itemBuilder: (context) {
                      final List<String> allPatterns = [..._globalPatterns];
                      for (final rules in _rules.values) {
                        allPatterns.addAll(rules);
                      }
                      return allPatterns.toSet().map((p) => PopupMenuItem(
                        value: p,
                        child: Text(p, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12)),
                      )).toList();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _simRegexController,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => _evaluateSimulator(),
                decoration: const InputDecoration(
                  labelText: 'e.g. ^(?<author>[^/]+)/(?<title>.*)',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildSimulatorResults(),
        ),
      ],
    );
  }

  Widget _buildSimulatorResults() {
    if (_simRegexController.text.isEmpty) {
      return Center(child: Text('Enter a pattern to begin', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))));
    }

    if (_simError != null) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(_simError!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
      );
    }

    if (_simMatch == null) {
      return const Center(child: Text('No Match Found', style: TextStyle(color: Colors.orangeAccent, fontSize: 16)));
    }

    final match = _simMatch!;
    final List<Widget> groupWidgets = [];
    
    // We try to grab named groups. If the environment doesn't expose `groupNames` natively we can iterate 
    // over common known groups, or just use the new `groupNames` getter.
    for (final groupName in match.groupNames) {
      final value = match.namedGroup(groupName);
      if (value != null) {
        groupWidgets.add(
          Card(
            color: const Color(0xFF333333),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(groupName, style: const TextStyle(color: Color(0xFFE8B86D), fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          )
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('Match Successful', style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        if (groupWidgets.isEmpty)
          Text('No named groups extracted.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5)))
        else
          ...groupWidgets,
      ],
    );
  }
}
