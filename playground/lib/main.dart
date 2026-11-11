import 'package:flutter/material.dart';

import 'src/playground_page.dart';

void main() => runApp(const NostrPlaygroundApp());

class NostrPlaygroundApp extends StatefulWidget {
  const NostrPlaygroundApp({super.key});

  @override
  State<NostrPlaygroundApp> createState() => _NostrPlaygroundAppState();
}

class _NostrPlaygroundAppState extends State<NostrPlaygroundApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    final isDark =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    setState(() {
      _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nostr debug playground',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: PlaygroundPage(onToggleTheme: _toggleTheme),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF245AC4),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF111B2B)
        : const Color(0xFFF6F8FC),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
  );
}
