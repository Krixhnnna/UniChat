import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'app_fonts.dart';

// Custom scroll physics for Instagram-like smoothness
class CustomBouncyScrollPhysics extends BouncingScrollPhysics {
  const CustomBouncyScrollPhysics({ScrollPhysics? parent})
      : super(parent: parent);

  @override
  CustomBouncyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomBouncyScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.5,
        stiffness: 100.0,
        damping: 10.0,
      );

  @override
  double get minFlingVelocity => 50.0;

  @override
  double get maxFlingVelocity => 4000.0;

  @override
  Tolerance get tolerance => Tolerance(
        velocity:
            1.0 / (0.050 * WidgetsBinding.instance.window.devicePixelRatio),
        distance: 1.0 / WidgetsBinding.instance.window.devicePixelRatio,
      );
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    fontFamily: 'Rewalt',
    primarySwatch: Colors.purple,
    primaryColor: Colors.purple.shade400,
    colorScheme: ColorScheme.light(
      primary: Colors.purple.shade400,
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
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.black,
      elevation: 0,
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: Colors.purple.shade400,
      textTheme: ButtonTextTheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple.shade400,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        textStyle: const TextStyle(fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.purple.shade400,
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
    cardTheme: const CardThemeData(
      // Corrected from CardTheme to CardThemeData
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(15)),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Rewalt'),
      displayMedium: TextStyle(fontFamily: 'Rewalt'),
      displaySmall: TextStyle(fontFamily: 'Rewalt'),
      headlineLarge: TextStyle(fontFamily: 'Rewalt'),
      headlineMedium: TextStyle(fontFamily: 'Rewalt'),
      headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
          fontFamily: 'Rewalt'),
      titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
          fontFamily: 'Rewalt'),
      titleMedium: TextStyle(fontFamily: 'Rewalt'),
      titleSmall: TextStyle(fontFamily: 'Rewalt'),
      bodyLarge:
          TextStyle(fontSize: 16, color: Colors.black87, fontFamily: 'Rewalt'),
      bodyMedium:
          TextStyle(fontSize: 14, color: Colors.black87, fontFamily: 'Rewalt'),
      bodySmall: TextStyle(fontFamily: 'Rewalt'),
      labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
          fontFamily: 'Rewalt'),
      labelMedium: TextStyle(fontFamily: 'Rewalt'),
      labelSmall: TextStyle(fontFamily: 'Rewalt'),
    ).apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Colors.purple,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      selectedLabelStyle: TextStyle(),
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

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.purple,
      fontFamily: AppFonts.headingFont, // Set NudMotoya as default font
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: AppFonts.headlineLarge.copyWith(
          color: Colors.white,
          fontSize: 26,
        ),
      ),
      textTheme: TextTheme(
        // Display text - Large headings with NudMotoya
        displayLarge: AppFonts.displayLarge,
        displayMedium: AppFonts.displayMedium,
        displaySmall: AppFonts.displaySmall,

        // Headline text - Section headings with NudMotoya
        headlineLarge: AppFonts.headlineLarge,
        headlineMedium: AppFonts.headlineMedium,
        headlineSmall: AppFonts.headlineSmall,

        // Title text - Card titles, app bar with NudMotoya
        titleLarge: AppFonts.titleLarge,
        titleMedium: AppFonts.titleMedium,
        titleSmall: AppFonts.titleSmall,

        // Body text - Main content with Satoshi-like fonts
        bodyLarge: AppFonts.bodyLarge,
        bodyMedium: AppFonts.bodyMedium,
        bodySmall: AppFonts.bodySmall,

        // Label text - Buttons, form fields with Satoshi-like fonts
        labelLarge: AppFonts.labelLarge,
        labelMedium: AppFonts.labelMedium,
        labelSmall: AppFonts.labelSmall,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          textStyle: AppFonts.buttonText.copyWith(fontSize: 18),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AppFonts.bodyMedium.copyWith(fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: AppFonts.bodyMedium.copyWith(fontSize: 16),
        hintStyle: AppFonts.bodyMedium.copyWith(fontSize: 16),
        errorStyle: AppFonts.bodySmall.copyWith(fontSize: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black,
        selectedLabelStyle: AppFonts.labelMedium.copyWith(fontSize: 14),
        unselectedLabelStyle: AppFonts.labelSmall.copyWith(fontSize: 12),
      ),
    );
  }
}
