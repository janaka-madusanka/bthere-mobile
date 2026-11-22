import 'package:flutter/material.dart';

/// Booking chat palette shared visually with Customer; Provider uses PublicSans.
abstract final class ProviderChatColors {
  static const primary = Color(0xFF0F666B);
  static const action = Color(0xFF008F95);
  static const secondary = Color(0xFF3E8EC7);
  static const careGreen = Color(0xFF62C3A0);
  static const mint = Color(0xFF66F4F2);
  static const coral = Color(0xFFF2998C);
  static const background = Color(0xFFF8FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF0B3037);
  static const secondaryText = Color(0xFF687B83);
  static const muted = Color(0xFF8997A0);
  static const border = Color(0xFFE6EDF0);
  static const selection = Color(0xFFE5FAFA);
  static const success = Color(0xFF21866D);
  static const warning = Color(0xFFB7791F);
  static const error = Color(0xFFC44444);
}

abstract final class ProviderChatTypography {
  static const family = 'PublicSans';
  static const screen = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
  );
  static const section = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );
  static const card = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
  static const compact = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );
  static const minimumMicro = TextStyle(
    fontFamily: family,
    fontSize: 8,
    height: 10 / 8,
    fontWeight: FontWeight.w500,
  );
  static const micro = TextStyle(
    fontFamily: family,
    fontSize: 10,
    height: 12 / 10,
    fontWeight: FontWeight.w500,
  );
  static const compactStrong = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// A deliberate display exception for the payment deadline, not a heading.
  static const countdown = TextStyle(
    fontFamily: family,
    fontSize: 38,
    height: 44 / 38,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
