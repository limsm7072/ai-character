import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    colorSchemeSeed: AppColors.primary,
    useMaterial3: true,
    brightness: Brightness.light,
  );

  static ThemeData get dark => ThemeData(
    colorSchemeSeed: AppColors.primary,
    useMaterial3: true,
    brightness: Brightness.dark,
  );
}
