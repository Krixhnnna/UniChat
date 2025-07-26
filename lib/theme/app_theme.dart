import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.pink,
    primaryColor: Colors.pink.shade400,
    colorScheme: ColorScheme.light(
      primary: Colors.pink.shade400,
      secondary: Colors.purple.shade300, // Used for accentColor replacement
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black87,
      background: Colors.white,
      onBackground: Colors.black87,
      error: Colors.red,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      color: Colors.pink,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: Colors.pink.shade400,
      textTheme: ButtonTextTheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink.shade400,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.pink.shade400,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    ),
    cardTheme: const CardThemeData( // Corrected from CardTheme to CardThemeData
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(15)),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Colors.pink,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
      showUnselectedLabels: true,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.pink,
    primaryColor: Colors.pink.shade700,
    colorScheme: ColorScheme.dark(
      primary: Colors.pink.shade700,
      secondary: Colors.purple.shade700,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      surface: Colors.grey.shade800,
      onSurface: Colors.white70,
      background: Colors.grey.shade900,
      onBackground: Colors.white70,
      error: Colors.red.shade700,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.grey.shade900,
    appBarTheme: const AppBarTheme(
      color: Colors.grey,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: Colors.pink.shade700,
      textTheme: ButtonTextTheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.pink.shade700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey.shade700,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      hintStyle: const TextStyle(color: Colors.grey),
    ),
    cardTheme: const CardThemeData( // Corrected from CardTheme to CardThemeData
      elevation: 4,
      color: Colors.grey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(15)),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Colors.pink,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.grey,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
      showUnselectedLabels: true,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
