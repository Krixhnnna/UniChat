import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFFF3366); // Pinkish red

  static ThemeData get themeData => ThemeData(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: primaryColor,
          secondary: primaryColor,
        ),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 32),
          headlineMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 24),
          bodyLarge: TextStyle(fontFamily: 'Poppins', fontSize: 16),
          bodyMedium: TextStyle(fontFamily: 'Poppins', fontSize: 14),
        ),
      );
} 