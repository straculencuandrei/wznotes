import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.samsungOrange,
        secondary: AppColors.primaryBlue,
        surface: AppColors.amoledSurface,
        background: AppColors.amoledBlack,
        outline: AppColors.amoledBorder,
      ),
      scaffoldBackgroundColor: AppColors.amoledBlack,
      canvasColor: AppColors.amoledBlack,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.amoledBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.amoledTextPrimary, size: 26),
        titleTextStyle: TextStyle(
          color: AppColors.amoledTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.amoledSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.amoledBorder, width: 1.2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.amoledBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get lightTheme => darkTheme; // Defaulting to pure AMOLED theme
}
