import 'package:flutter/material.dart';

import 'bthere_colors.dart';
import 'bthere_radius.dart';
import 'bthere_spacing.dart';
import 'bthere_typography.dart';

abstract final class BThereTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// A bright presentation variant; other feature themes retain their roles.
  static ThemeData authentication() {
    final base = light();
    final scheme = base.colorScheme.copyWith(
      primary: BThereColors.primaryAction,
      surfaceContainerHighest: BThereColors.divider,
    );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(BThereRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );
    return base.copyWith(
      colorScheme: scheme,
      textTheme: base.textTheme.copyWith(
        headlineLarge: BThereTypography.h1.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 32 / 24,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        enabledBorder: border(BThereColors.border),
        focusedBorder: border(scheme.primary, 2),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style!.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? BThereColors.disabledBackground
                : scheme.primary,
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style!.copyWith(
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          side: const WidgetStatePropertyAll(
            BorderSide(color: BThereColors.border),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: base.textButtonTheme.style!.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? scheme.onSurfaceVariant
                : scheme.primary,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BThereSpacing.xxs),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BThereColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: dark ? BThereDarkColors.primary : BThereColors.primary,
          onPrimary: dark ? BThereDarkColors.onPrimary : BThereColors.surface,
          primaryContainer: dark
              ? BThereColors.primary
              : BThereColors.selection,
          onPrimaryContainer: dark
              ? BThereDarkColors.textPrimary
              : BThereColors.textPrimary,
          secondary: dark ? BThereDarkColors.secondary : BThereColors.secondary,
          onSecondary: BThereColors.secondaryContent,
          tertiary: BThereColors.green,
          onTertiary: BThereColors.textPrimary,
          surface: dark ? BThereDarkColors.surface : BThereColors.surface,
          surfaceContainerLow: dark
              ? BThereDarkColors.surfaceContainer
              : BThereColors.background,
          onSurface: dark
              ? BThereDarkColors.textPrimary
              : BThereColors.textPrimary,
          onSurfaceVariant: dark
              ? BThereDarkColors.textSecondary
              : BThereColors.textSecondaryAccessible,
          outline: dark ? BThereDarkColors.border : BThereColors.inputBorder,
          outlineVariant: dark ? BThereDarkColors.divider : BThereColors.border,
          error: dark ? BThereDarkColors.error : BThereColors.errorText,
          onError: dark ? BThereDarkColors.onError : BThereColors.surface,
          errorContainer: dark
              ? BThereDarkColors.errorContainer
              : BThereColors.errorContainer,
          onErrorContainer: dark
              ? BThereDarkColors.error
              : BThereColors.onErrorContainer,
        );
    final disabledBackground = dark
        ? BThereDarkColors.disabledBackground
        : BThereColors.disabledBackground;
    final disabledText = dark
        ? BThereDarkColors.disabledText
        : BThereColors.disabledText;
    final disabledBorder = dark
        ? BThereDarkColors.disabledBorder
        : BThereColors.disabledBorder;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BThereRadius.control),
    );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(BThereRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: BThereSpacing.lg,
          vertical: BThereSpacing.md,
        ),
      ),
      shape: WidgetStatePropertyAll(shape),
      textStyle: const WidgetStatePropertyAll(BThereTypography.button),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? disabledText
            : scheme.onPrimary,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? disabledBackground
            : scheme.primary,
      ),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: BThereTypography.fontFamily,
      textTheme: BThereTypography.textTheme(
        scheme.onSurface,
        scheme.onSurfaceVariant,
      ),
      scaffoldBackgroundColor: dark
          ? BThereDarkColors.background
          : BThereColors.background,
      disabledColor: disabledText,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BThereRadius.surface),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.all(BThereSpacing.md),
        labelStyle: BThereTypography.body.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: BThereTypography.body.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        errorStyle: BThereTypography.caption.copyWith(color: scheme.error),
        errorMaxLines: 3,
        border: border(scheme.outline),
        enabledBorder: border(scheme.outline),
        focusedBorder: border(scheme.primary, 2),
        disabledBorder: border(disabledBorder),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: buttonStyle.copyWith(
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? 0
                : states.contains(WidgetState.pressed)
                ? 1
                : 2,
          ),
          shadowColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: 0.2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle.copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? disabledText
                : scheme.primary,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? disabledBorder
                  : scheme.primary,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.primary,
          disabledForegroundColor: disabledText,
          textStyle: BThereTypography.button,
          shape: shape,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? BThereDarkColors.divider : BThereColors.divider,
        thickness: 1,
        space: BThereSpacing.md,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: BThereTypography.body.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: shape,
      ),
    );
  }
}
