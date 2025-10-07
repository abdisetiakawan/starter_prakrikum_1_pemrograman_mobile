import 'package:flutter/material.dart';

import 'home_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F378B),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: baseColorScheme,
        scaffoldBackgroundColor: baseColorScheme.surfaceContainerHighest,
        textTheme: Theme.of(context).textTheme.apply(
          displayColor: baseColorScheme.onSurface,
          bodyColor: baseColorScheme.onSurface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: baseColorScheme.surface,
          foregroundColor: baseColorScheme.onSurface,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: baseColorScheme.primary,
            foregroundColor: baseColorScheme.onPrimary,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            elevation: 6,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
