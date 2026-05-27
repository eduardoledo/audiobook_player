import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AudiobookPlayerApp());
}

class AudiobookPlayerApp extends StatelessWidget {
  const AudiobookPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audiobook Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFE8B86D),
          surface: const Color(0xFF1A1A1A),
          onSurface: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
