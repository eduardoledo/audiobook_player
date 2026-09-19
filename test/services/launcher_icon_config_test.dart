import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Ticket 01: Android Launcher Adaptive Icon Configuration', () {
    test('pubspec.yaml configures flutter_icons adaptive icon background and foreground', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);

      final content = pubspecFile.readAsStringSync();
      final doc = loadYaml(content) as Map;

      final flutterIcons = doc['flutter_icons'] as Map?;
      expect(flutterIcons, isNotNull);

      expect(flutterIcons!['adaptive_icon_background'], isNotNull);
      expect(flutterIcons['adaptive_icon_foreground'], equals('assets/icon.png'));
    });
  });
}
