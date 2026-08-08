import 'package:flutter/material.dart';

abstract final class AppColors {
  // High-density TaskGrid palette from the supplied frontend references.
  static const background = Color(0xFF010102);
  static const surface = Color(0xFF141218);
  static const surfaceHigh = Color(0xFF211F24);
  static const surfaceHighest = Color(0xFF36343A);
  static const primary = Color(0xFFCFBCFF);
  static const primaryContainer = Color(0xFF6750A4);
  static const secondary = Color(0xFFCDC0E9);
  static const tertiary = Color(0xFFE7C365);
  static const blush = Color(0xFFE7C365);
  static const pearl = Color(0xFFE9DDFF);
  static const onSurface = Color(0xFFE6E0E9);
  static const onSurfaceVariant = Color(0xFFCBC4D2);
  static const outline = Color(0xFF948E9C);
  static const outlineVariant = Color(0xFF494551);
  static const error = Color(0xFFFFB4AB);
}

abstract final class AppTheme {
  static const _baseTextTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 30,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -.45,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -.25,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
      letterSpacing: -.1,
    ),
    bodyLarge: TextStyle(fontSize: 15, height: 1.4, letterSpacing: -.1),
    bodyMedium: TextStyle(fontSize: 13.5, height: 1.4, letterSpacing: -.05),
    labelLarge: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.background,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.pearl,
      secondary: AppColors.secondary,
      onSecondary: AppColors.background,
      secondaryContainer: AppColors.surfaceHighest,
      onSecondaryContainer: AppColors.pearl,
      tertiary: AppColors.tertiary,
      onTertiary: Color(0xFF3E2E00),
      tertiaryContainer: Color(0xFFC9A74D),
      onTertiaryContainer: Color(0xFF503D00),
      error: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );
    return _buildTheme(
      scheme: scheme,
      scaffold: AppColors.background,
      inputFill: AppColors.surfaceHigh,
      navBackground: AppColors.surface,
      divider: AppColors.outlineVariant,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffold,
    required Color inputFill,
    required Color navBackground,
    required Color divider,
  }) {
    final textTheme = _baseTextTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          bodyMedium: _baseTextTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        );
    return ThemeData(
      brightness: scheme.brightness,
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        backgroundColor: navBackground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: .18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 1.5),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          side: BorderSide(color: AppColors.outlineVariant),
        ),
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      listTileTheme: ListTileThemeData(
        dense: true,
        minVerticalPadding: 4,
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      dividerColor: divider,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: color, width: width),
      );
}
