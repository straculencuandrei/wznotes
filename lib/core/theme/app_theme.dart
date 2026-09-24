import 'package:flutter/material.dart';
import 'app_themes.dart';

class AppTheme {
  static ThemeData get darkTheme => AppThemes.getThemeData('amoled');
  static ThemeData getThemeData(String themeId) => AppThemes.getThemeData(themeId);
  static ThemeData get lightTheme => darkTheme;
}
