import 'package:flutter/material.dart';

/// Shared interface tokens. Keep these values in step with the web theme.
class PlaygroundColors {
  const PlaygroundColors({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.border,
    required this.accent,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color border;
  final Color accent;
  final Color success;
}

const PlaygroundColors playgroundLightColors = PlaygroundColors(
  background: Color(0xFFF6F8FC),
  surface: Color(0xFFFFFFFF),
  ink: Color(0xFF17263E),
  muted: Color(0xFF4A5B73),
  border: Color(0xFFCBD5E2),
  accent: Color(0xFF245AC4),
  success: Color(0xFF1B7F3B),
);

const PlaygroundColors playgroundDarkColors = PlaygroundColors(
  background: Color(0xFF111B2B),
  surface: Color(0xFF18263B),
  ink: Color(0xFFECF1FA),
  muted: Color(0xFFB6C4DA),
  border: Color(0xFF43536C),
  accent: Color(0xFF95BBFF),
  success: Color(0xFF6FCF97),
);

const String _fontFamily = 'IBM Plex Sans';
const double _corner = 4;
const double playgroundFocusWidth = 3;

PlaygroundColors playgroundColorsOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? playgroundDarkColors
    : playgroundLightColors;

TextTheme _textTheme(Typography typography, PlaygroundColors colors) {
  final applied = typography.englishLike.apply(
    fontFamily: _fontFamily,
    bodyColor: colors.ink,
    displayColor: colors.ink,
  );
  final body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 1.6,
    color: colors.ink,
  );
  return applied.copyWith(
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: applied.bodySmall?.copyWith(height: 1.5),
    labelSmall: applied.labelSmall?.copyWith(fontSize: 12, height: 1.4),
  );
}

WidgetStateProperty<BorderSide?> _focusedSide(Color color) =>
    WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: color, width: playgroundFocusWidth)
          : null,
    );

/// Focus ring for controls whose filled background differs from the accent.
ButtonStyle playgroundFocusSideStyle(Color color) =>
    ButtonStyle(side: _focusedSide(color));

ThemeData buildPlaygroundTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? playgroundDarkColors
      : playgroundLightColors;
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: _fontFamily,
  );
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.accent,
    brightness: brightness,
    primary: colors.accent,
    onPrimary: brightness == Brightness.dark
        ? playgroundDarkColors.background
        : Colors.white,
    surface: colors.surface,
    onSurface: colors.ink,
    onSurfaceVariant: colors.muted,
    outline: colors.border,
    outlineVariant: colors.border,
  );
  final radius = BorderRadius.circular(_corner);
  final focusSide = _focusedSide(colors.accent);
  const buttonSize = WidgetStatePropertyAll(Size(0, 48));

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    textTheme: _textTheme(base.typography, colors),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: colors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colors.accent, width: 3),
      ),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: buttonSize,
        side: _focusedSide(scheme.onPrimary),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(minimumSize: buttonSize, side: focusSide),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(minimumSize: buttonSize, side: focusSide),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        side: focusSide,
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
    focusColor: colors.accent.withValues(alpha: 0.18),
  );
}
