import 'package:flutter/material.dart';

/// Customer UI tokens from the designer's October 2026 guidelines.
/// Kept app-local so the independently maintained Provider UI is unaffected.
abstract final class CustomerColors {
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

abstract final class CustomerTypography {
  static const family = 'Public Sans';
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
}

abstract final class CustomerTheme {
  static ThemeData authentication() => light();
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: CustomerColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: dark ? CustomerColors.mint : CustomerColors.action,
          onPrimary: dark ? CustomerColors.text : Colors.white,
          secondary: CustomerColors.secondary,
          tertiary: CustomerColors.careGreen,
          surface: dark ? const Color(0xFF142B30) : CustomerColors.surface,
          onSurface: dark ? CustomerColors.background : CustomerColors.text,
          onSurfaceVariant: dark
              ? const Color(0xFFB9C9CE)
              : CustomerColors.secondaryText,
          outline: dark ? const Color(0xFF52666C) : CustomerColors.border,
          outlineVariant: dark
              ? const Color(0xFF344A50)
              : CustomerColors.border,
          primaryContainer: dark
              ? CustomerColors.primary
              : CustomerColors.selection,
          error: dark ? const Color(0xFFFFB4AB) : CustomerColors.error,
        );
    TextStyle ink(TextStyle style) => style.copyWith(color: scheme.onSurface);
    final text = TextTheme(
      displayLarge: ink(CustomerTypography.screen),
      displayMedium: ink(CustomerTypography.screen),
      displaySmall: ink(CustomerTypography.screen),
      headlineLarge: ink(CustomerTypography.screen),
      headlineMedium: ink(CustomerTypography.screen),
      headlineSmall: ink(CustomerTypography.screen),
      titleLarge: ink(CustomerTypography.section),
      titleMedium: ink(
        CustomerTypography.body.copyWith(fontWeight: FontWeight.w500),
      ),
      titleSmall: ink(CustomerTypography.card),
      bodyLarge: ink(
        CustomerTypography.body.copyWith(fontWeight: FontWeight.w500),
      ),
      bodyMedium: ink(CustomerTypography.body),
      bodySmall: CustomerTypography.compact.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: ink(CustomerTypography.card),
      labelMedium: ink(CustomerTypography.compact),
      labelSmall: CustomerTypography.micro.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final buttons = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 50)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      textStyle: const WidgetStatePropertyAll(CustomerTypography.card),
      shape: WidgetStatePropertyAll(shape),
    );
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: CustomerTypography.family,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0D2125)
          : CustomerColors.background,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: ink(CustomerTypography.section),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: text.labelMedium,
        floatingLabelStyle: text.labelMedium,
        hintStyle: CustomerTypography.body.copyWith(
          color: dark ? scheme.onSurfaceVariant : CustomerColors.muted,
        ),
        helperStyle: text.bodySmall,
        errorStyle: CustomerTypography.compact.copyWith(color: scheme.error),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: border(scheme.outline),
        enabledBorder: border(scheme.outline),
        focusedBorder: border(scheme.primary),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error),
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttons),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttons.copyWith(
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: buttons.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: text.labelMedium,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outline),
        shape: shape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
        indicatorColor: scheme.primaryContainer,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
