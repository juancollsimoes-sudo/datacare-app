import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class AppTheme {
  static ThemeData getLightTheme([Color? seedColor]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? AppConstants.brandColor,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
    return _buildTheme(colorScheme, Brightness.light);
  }

  static ThemeData getDarkTheme([Color? seedColor]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? AppConstants.brandColor,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
    return _buildTheme(colorScheme, Brightness.dark);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      visualDensity: VisualDensity.compact,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      navigationRailTheme: NavigationRailThemeData(
        useIndicator: true,
        labelType: NavigationRailLabelType.none, // We handle it custom if extended
      ),
    );
  }
}
