import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.light,
    ).copyWith(
      onSurface: AppColors.primaryText,
      outline: AppColors.visibleBorder,
      outlineVariant: AppColors.disabledBorder,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightSurface,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.primaryText,
        displayColor: AppColors.primaryText,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        bodyColor: AppColors.darkSurfaceText,
        displayColor: AppColors.darkSurfaceText,
      ),
      iconTheme: const IconThemeData(color: AppColors.secondaryText),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryText,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.primaryText,
        iconColor: AppColors.secondaryText,
        titleTextStyle: TextStyle(
          color: AppColors.primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: AppColors.secondaryText,
          fontSize: 14,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: AppColors.primaryText),
        floatingLabelStyle: TextStyle(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: AppColors.hintText),
        helperStyle: TextStyle(color: AppColors.secondaryText),
        suffixStyle: TextStyle(color: AppColors.secondaryText),
        prefixIconColor: AppColors.secondaryText,
        suffixIconColor: AppColors.secondaryText,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.visibleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.visibleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.disabledBorder),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.disabledText;
            }
            if (states.contains(WidgetState.selected)) return Colors.white;
            return AppColors.secondaryText;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlue;
            }
            return Colors.white;
          }),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? AppColors.disabledBorder
                  : AppColors.visibleBorder,
            ),
          ),
        ),
      ),
    );
  }
}
