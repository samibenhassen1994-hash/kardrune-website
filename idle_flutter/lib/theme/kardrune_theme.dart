import 'package:flutter/material.dart';

abstract final class KardRuneTheme {
  static const navy = Color(0xff071426);
  static const blue = Color(0xff153b66);
  static const gold = Color(0xffd8ad55);
  static const parchment = Color(0xffffe9b8);

  static ThemeData get data => ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          secondary: Color(0xff68b9ff),
          surface: navy,
        ),
        scaffoldBackgroundColor: navy,
        useMaterial3: true,
      );
}
