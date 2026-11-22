import 'package:flutter/material.dart';

/// Public Sans is bundled locally by each application.
/// No runtime font fetching is performed.
abstract final class BThereTypography {
  static const fontFamily = 'PublicSans';
  static const h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 32 / 24,
  );
  static const h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
  );
  static const h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
  );
  static const bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
  );
  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );
  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );
  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
  );

  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
    displayLarge: h1.copyWith(color: primary),
    displayMedium: h2.copyWith(color: primary),
    displaySmall: h3.copyWith(color: primary),
    headlineLarge: h1.copyWith(color: primary),
    headlineMedium: h2.copyWith(color: primary),
    headlineSmall: h3.copyWith(color: primary),
    titleLarge: h3.copyWith(color: primary),
    titleMedium: bodyLarge.copyWith(color: primary),
    titleSmall: label.copyWith(color: primary),
    bodyLarge: bodyLarge.copyWith(color: primary),
    bodyMedium: body.copyWith(color: primary),
    bodySmall: caption.copyWith(color: secondary),
    labelLarge: button.copyWith(color: primary),
    labelMedium: label.copyWith(color: primary),
    labelSmall: caption.copyWith(color: secondary),
  );
}
