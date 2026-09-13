import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color primaryColor = Color(0xFFE8B86D);
  static const Color surfaceColor = Color(0xFF1A1A1A);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          surface: surfaceColor,
          onSurface: Colors.white,
        ),
      );
}
