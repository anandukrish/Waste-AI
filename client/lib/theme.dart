import 'package:flutter/material.dart';

class WasteTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff25d0b0),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xff45ddc1),
      secondary: const Color(0xffaa8cff),
      surface: const Color(0xff151722),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xff0e1018),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff191c2a),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
    );
  }
}
