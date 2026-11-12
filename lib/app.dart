import 'package:flutter/material.dart';

import 'ui/app_colors.dart';
import 'ui/scanner_screen.dart';

class BanknoteApp extends StatelessWidget {
  const BanknoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: Color(0xFF3A2E0C),
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.secondary,
      onSecondary: Color(0xFF00201C),
      secondaryContainer: Color(0xFF12332F),
      onSecondaryContainer: AppColors.secondary,
      error: AppColors.error,
      onError: Color(0xFF2B0000),
      surface: AppColors.backgroundRaised,
      onSurface: AppColors.textPrimary,
      outline: AppColors.borderStrong,
    );

    return MaterialApp(
      title: 'Banknot Tanıma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.background,
        canvasColor: AppColors.background,
        splashFactory: InkSparkle.splashFactory,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textPrimary),
          bodySmall: TextStyle(color: AppColors.textMuted),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            minimumSize: const Size.fromHeight(56),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: const Color(0xFF26313C),
            disabledForegroundColor: AppColors.textFaint,
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
          linearTrackColor: AppColors.border,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.panelRaised,
          contentTextStyle: TextStyle(color: AppColors.textPrimary),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const ScannerScreen(),
    );
  }
}
