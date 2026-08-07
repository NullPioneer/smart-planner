import 'package:flutter/material.dart';

abstract final class AppColors {
  // Dark palette: graphite glass with restrained emerald and cool-blue light.
  static const background = Color(0xFF0A171D);
  static const surface = Color(0xFF122832);
  static const surfaceHigh = Color(0xFF1C3A44);
  static const surfaceHighest = Color(0xFF2B535C);
  static const primary = Color(0xFF67D7B8);
  static const primaryContainer = Color(0xFF176B5B);
  static const secondary = Color(0xFF83BFEA);
  static const blush = Color(0xFF87C8D7);
  static const pearl = Color(0xFFF3F8FA);
  static const onSurface = Color(0xFFF5FAFB);
  static const onSurfaceVariant = Color(0xFFBBCDD3);
  static const outline = Color(0xFF78959F);
  static const outlineVariant = Color(0xFF3A606B);
  static const error = Color(0xFFFFAAAA);

  // Light palette: mineral teal layers with deep ink contrast.
  static const lightBackground = Color(0xFF8FADAB);
  static const lightSurface = Color(0xFFBDD1CA);
  static const lightSurfaceHigh = Color(0xFF9DBCB6);
  static const lightPrimary = Color(0xFF075E52);
  static const lightSecondary = Color(0xFF1D527D);
  static const lightOnSurface = Color(0xFF071B21);
  static const lightOnSurfaceVariant = Color(0xFF263F45);
  static const lightOutline = Color(0xFF405E66);
  static const lightOutlineVariant = Color(0xFF7F9CA2);
}

abstract final class AppTheme {
  static const _baseTextTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 36,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
    ),
    headlineMedium: TextStyle(
      fontSize: 25,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -.45,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
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
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, letterSpacing: -.1),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45, letterSpacing: -.05),
    labelLarge: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.lightPrimary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFB6E6D8),
      onPrimaryContainer: Color(0xFF073C33),
      secondary: AppColors.lightSecondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFA7C4CF),
      onSecondaryContainer: Color(0xFF102F43),
      error: Color(0xFFBA3A3A),
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnSurface,
      onSurfaceVariant: AppColors.lightOnSurfaceVariant,
      outline: AppColors.lightOutline,
      outlineVariant: AppColors.lightOutlineVariant,
    );
    return _buildTheme(
      scheme: scheme,
      scaffold: AppColors.lightBackground,
      inputFill: AppColors.lightSurfaceHigh.withValues(alpha: .88),
      navBackground: AppColors.lightSurface.withValues(alpha: .97),
      divider: AppColors.lightOutline.withValues(alpha: .55),
    );
  }

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
      inputFill: AppColors.surfaceHigh.withValues(alpha: .78),
      navBackground: AppColors.surface.withValues(alpha: .96),
      divider: AppColors.outlineVariant.withValues(alpha: .78),
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
          vertical: 15,
        ),
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 1.5),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      dividerColor: divider,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
}
