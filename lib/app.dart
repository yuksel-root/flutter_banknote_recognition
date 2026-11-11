import 'package:flutter/material.dart';

import 'ui/scanner_screen.dart';

class BanknoteApp extends StatelessWidget {
  const BanknoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFFFFD54F),
      onPrimary: Colors.black,
      secondary: Color(0xFF80CBC4),
      onSecondary: Colors.black,
      error: Color(0xFFFF8A80),
      onError: Colors.black,
      surface: Color(0xFF121212),
      onSurface: Colors.white,
    );

    return MaterialApp(
      title: 'Banknot Tanıma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(72),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            disabledBackgroundColor: const Color(0xFF424242),
            disabledForegroundColor: const Color(0xFFBDBDBD),
            textStyle: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const ScannerScreen(),
    );
  }
}
