import 'package:flutter/material.dart';

import 'src/playground_page.dart';
import 'src/playground_theme.dart';

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
      theme: buildPlaygroundTheme(Brightness.light),
      darkTheme: buildPlaygroundTheme(Brightness.dark),
      home: PlaygroundPage(onToggleTheme: _toggleTheme),
    );
  }
}
