import 'package:flutter/material.dart';

class AppFonts {
  // NudMotoya for main headings and titles
  static const String headingFont = 'NudMotoya';

  // Satoshi for body text and other content
  static const String bodyFont = 'Satoshi';

  // Heading styles with NudMotoya
  static TextStyle get displayLarge => const TextStyle(
        fontFamily: headingFont,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get displayMedium => const TextStyle(
        fontFamily: headingFont,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get displaySmall => const TextStyle(
        fontFamily: headingFont,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get headlineLarge => const TextStyle(
        fontFamily: headingFont,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get headlineMedium => const TextStyle(
        fontFamily: headingFont,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get headlineSmall => const TextStyle(
        fontFamily: headingFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleLarge => const TextStyle(
        fontFamily: headingFont,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleMedium => const TextStyle(
        fontFamily: headingFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleSmall => const TextStyle(
        fontFamily: headingFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );

  // Body styles with Satoshi-like system fonts
  static TextStyle get bodyLarge => const TextStyle(
        fontFamily:
            'Satoshi, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        fontSize: 18,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontFamily:
            'Satoshi, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        fontSize: 16,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodySmall => const TextStyle(
        fontFamily:
            'Satoshi, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  // Label styles with Satoshi-like system fonts
  static TextStyle get labelLarge => const TextStyle(
        fontFamily:
            'Satoshi, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        fontSize: 18,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get labelMedium => const TextStyle(
        fontFamily:
            'Satoshi, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get labelSmall => const TextStyle(
        fontFamily:
            'Satoshi, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );

  // Button text with Satoshi-like system fonts
  static TextStyle get buttonText => const TextStyle(
        fontFamily:
            'Satoshi, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  // Caption text with Satoshi-like system fonts
  static TextStyle get caption => const TextStyle(
        fontFamily:
            'Satoshi, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  // Overline text with Satoshi-like system fonts
  static TextStyle get overline => const TextStyle(
        fontFamily:
            'Satoshi, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
      );

  // Custom heading with NudMotoya
  static TextStyle heading({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: headingFont,
      fontSize: fontSize ?? 20,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
      height: height,
    );
  }

  // Custom body text with Satoshi-like system fonts
  static TextStyle body({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily:
          'Satoshi, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
      fontSize: fontSize ?? 16,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: height,
    );
  }
}
