import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ──────────────────────────────────────────────
  // Color Schemes
  // ──────────────────────────────────────────────

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    // Surfaces
    surface: Color(0xFFFFF8F6),
    onSurface: Color(0xFF1A1B3A),
    onSurfaceVariant: Color(0xFF6B5D5A),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFF4F1),
    surfaceContainer: Color(0xFFFFF0ED),
    surfaceContainerHigh: Color(0xFFFFEBE7),
    surfaceContainerHighest: Color(0xFFFFE5E0),
    // Primary
    primary: Color(0xFFC77D9C),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFCDEE8),
    onPrimaryContainer: Color(0xFF3E1929),
    // Secondary
    secondary: Color(0xFF1A1B3A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE8E8F4),
    onSecondaryContainer: Color(0xFF1A1B3A),
    // Tertiary
    tertiary: Color(0xFFD4B896),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF5E6D0),
    onTertiaryContainer: Color(0xFF3D2E1E),
    // Error
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    // Outline
    outline: Color(0xFFBEB0AD),
    outlineVariant: Color(0xFFE0D4D1),
    // Misc
    inverseSurface: Color(0xFF1A1B3A),
    onInverseSurface: Color(0xFFF2E0DC),
    inversePrimary: Color(0xFFE8A4C0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    // Surfaces
    surface: Color(0xFF1A1B3A),
    onSurface: Color(0xFFF2E0DC),
    onSurfaceVariant: Color(0xFFC4B8B5),
    surfaceContainerLowest: Color(0xFF141530),
    surfaceContainerLow: Color(0xFF1F2040),
    surfaceContainer: Color(0xFF252745),
    surfaceContainerHigh: Color(0xFF2D2F50),
    surfaceContainerHighest: Color(0xFF35375A),
    // Primary
    primary: Color(0xFFE8A4C0),
    onPrimary: Color(0xFF1A1B3A),
    primaryContainer: Color(0xFF4A2D3C),
    onPrimaryContainer: Color(0xFFFCDEE8),
    // Secondary
    secondary: Color(0xFFF2E0DC),
    onSecondary: Color(0xFF1A1B3A),
    secondaryContainer: Color(0xFF3A3B5C),
    onSecondaryContainer: Color(0xFFF2E0DC),
    // Tertiary
    tertiary: Color(0xFFD4B896),
    onTertiary: Color(0xFF1A1B3A),
    tertiaryContainer: Color(0xFF4A3D2E),
    onTertiaryContainer: Color(0xFFF5E6D0),
    // Error
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    // Outline
    outline: Color(0xFF4A4C6E),
    outlineVariant: Color(0xFF353757),
    // Misc
    inverseSurface: Color(0xFFF2E0DC),
    onInverseSurface: Color(0xFF1A1B3A),
    inversePrimary: Color(0xFFC77D9C),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  // ──────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────

  static ThemeData getLightTheme([Color? seedColor]) {
    return _buildTheme(lightColorScheme);
  }

  static ThemeData getDarkTheme([Color? seedColor]) {
    return _buildTheme(darkColorScheme);
  }

  // ──────────────────────────────────────────────
  // Typography
  // ──────────────────────────────────────────────

  static TextTheme _buildTextTheme(Brightness brightness) {
    final baseTheme = ThemeData(brightness: brightness).textTheme;

    // Playfair Display for display & headline styles + titleLarge
    final playfair = GoogleFonts.playfairDisplayTextTheme(baseTheme);

    // Inter for body, label, and remaining title styles
    final inter = GoogleFonts.interTextTheme(baseTheme);

    return TextTheme(
      displayLarge: playfair.displayLarge,
      displayMedium: playfair.displayMedium,
      displaySmall: playfair.displaySmall,
      headlineLarge: playfair.headlineLarge,
      headlineMedium: playfair.headlineMedium,
      headlineSmall: playfair.headlineSmall,
      titleLarge: playfair.titleLarge,
      titleMedium: inter.titleMedium,
      titleSmall: inter.titleSmall,
      bodyLarge: inter.bodyLarge,
      bodyMedium: inter.bodyMedium,
      bodySmall: inter.bodySmall,
      labelLarge: inter.labelLarge,
      labelMedium: inter.labelMedium,
      labelSmall: inter.labelSmall,
    );
  }

  // ──────────────────────────────────────────────
  // Theme Builder
  // ──────────────────────────────────────────────

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final brightness = colorScheme.brightness;
    final textTheme = _buildTextTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: colorScheme.surface,

      // ── Page Transitions ──
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Elevated Button ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          minimumSize: const Size(0, 48),
        ),
      ),

      // ── Filled Button ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),

      // ── Outlined Button ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),

      // ── Navigation Rail ──
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        useIndicator: true,
        indicatorColor: colorScheme.primaryContainer,
        labelType: NavigationRailLabelType.none,
      ),

      // ── Drawer ──
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
      ),

      // ── Input Decoration ──
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ── SnackBar ──
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ── Search Bar ──
      searchBarTheme: SearchBarThemeData(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainer),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
      ),

      // ── Floating Action Button ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }
}
