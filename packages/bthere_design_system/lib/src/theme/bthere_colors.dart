import 'package:flutter/material.dart';

/// Approved palette. Use the current theme for light/dark UI roles.
abstract final class BThereColors {
  static const primary = Color(0xFF0F666B);
  // Accessible brighter roles for white-canvas marketplace actions/emphasis.
  static const primaryAction = Color(0xFF087F89);
  static const primaryEmphasis = Color(0xFF008F95);
  static const secondary = Color(0xFF3E8EC7);
  static const selection = Color(0xFFE5FAFA);
  static const success = Color(0xFF21866D);
  static const warning = Color(0xFFB7791F);
  static const info = secondary;
  static const green = Color(0xFF62C3A0);
  static const softMint = Color(0xFF66F4F2);
  static const coral = Color(0xFFF2998C);
  static const background = Color(0xFFF8FAFB);
  static const textPrimary = Color(0xFF0B3037);
  static const textSecondary = Color(0xFF687B83);
  static const textTertiary = Color(0xFF8997A0);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6EDF0);
  static const divider = Color(0xFFE6EDF0);
  static const error = Color(0xFFC44444);
  static const disabledBackground = Color(0xFFE4EAEC);
  static const disabledText = textTertiary;
  static const disabledBorder = Color(0xFFCDD9DD);
  // Accessible role variants preserve the approved decorative colors above.
  static const errorText = Color(0xFFAC3030);
  static const textSecondaryAccessible = Color(0xFF586F7B);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF410002);
  static const inputBorder = Color(0xFF73868E);
  static const secondaryContent = Color(0xFF001923);
}

/// Selected dark roles, not mechanically inverted light colors.
abstract final class BThereDarkColors {
  static const background = Color(0xFF101C20);
  static const surface = Color(0xFF19292E);
  static const surfaceContainer = Color(0xFF22363B);
  static const primary = Color(0xFF80CFD2);
  static const onPrimary = Color(0xFF00373B);
  // Accessible brighter roles for white-canvas marketplace actions/emphasis.
  static const primaryAction = Color(0xFF087F89);
  static const primaryEmphasis = Color(0xFF008F95);
  static const secondary = Color(0xFF8BC9F0);
  static const textPrimary = Color(0xFFE7F1F3);
  static const textSecondary = Color(0xFFB6C9D0);
  static const border = Color(0xFF8CABB3);
  static const divider = Color(0xFF364C53);
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const disabledBackground = Color(0xFF2A3B41);
  static const disabledText = Color(0xFF81969E);
  static const disabledBorder = Color(0xFF40565E);
}
