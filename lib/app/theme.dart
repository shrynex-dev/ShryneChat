import 'package:flutter/material.dart';

class AppThemes {
  const AppThemes({required this.lightTheme, required this.darkTheme});

  final ThemeData lightTheme;
  final ThemeData darkTheme;
}

AppThemes buildAppThemes({
  required bool useDynamicColor,
  required ColorScheme? lightDynamicScheme,
  required ColorScheme? darkDynamicScheme,
  required double fontScale,
}) {
  const lightSeed = Color(0xFF6A7B67);
  const darkSeed = Color(0xFF95B197);

  final lightScheme = useDynamicColor && lightDynamicScheme != null
      ? lightDynamicScheme
      : ColorScheme.fromSeed(
          seedColor: lightSeed,
          brightness: Brightness.light,
          surface: const Color(0xFFF7F3EC),
        );
  final darkScheme = useDynamicColor && darkDynamicScheme != null
      ? darkDynamicScheme
      : ColorScheme.fromSeed(
          seedColor: darkSeed,
          brightness: Brightness.dark,
          surface: const Color(0xFF141715),
        );

  return AppThemes(
    lightTheme: _buildTheme(lightScheme, Brightness.light, fontScale),
    darkTheme: _buildTheme(darkScheme, Brightness.dark, fontScale),
  );
}

ThemeData _buildTheme(
  ColorScheme scheme,
  Brightness brightness,
  double fontScale,
) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  );

  final textTheme =
      Typography.material2021(
        platform: TargetPlatform.android,
        colorScheme: scheme,
      ).black.apply(
        fontSizeFactor: fontScale,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );

  final monoTextTheme = base.textTheme.apply(fontFamily: 'monospace');

  return base.copyWith(
    textTheme: textTheme.copyWith(
      bodySmall: monoTextTheme.bodySmall,
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.45),
      bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.5),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
      ),
    ),
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface.withValues(alpha: 0.94),
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => base.textTheme.labelMedium?.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: scheme.primary, width: 1.2),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.45),
      thickness: 1,
      space: 1,
    ),
  );
}
