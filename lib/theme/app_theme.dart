import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFFF4F4F0);
  static const muted = Color(0xFF9EA3AE);
  static const background = Color(0xFF0A0D14);
  static const surface = Color(0xFF111722);
  static const surfaceRaised = Color(0xFF171E2B);
  static const line = Color(0x22FFFFFF);
  static const lime = Color(0xFFD8F36A);
  static const limeDeep = Color(0xFFA7C83B);
  static const purple = Color(0xFF9B8CFF);
  static const orange = Color(0xFFFFA36B);
  static const aqua = Color(0xFF75E4D1);
  static const warning = Color(0xFFFFC56E);
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.lime,
      onPrimary: AppColors.background,
      secondary: AppColors.purple,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: Color(0xFFFF7B7B),
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Avenir',
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.lime,
      inactiveTrackColor: Colors.white12,
      thumbColor: AppColors.ink,
      overlayColor: AppColors.lime.withAlpha(30),
      trackHeight: 4,
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: Colors.transparent,
      elevation: 0,
      indicatorColor: AppColors.lime.withAlpha(28),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? AppColors.lime : AppColors.muted,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.lime : AppColors.muted,
          size: 22,
        );
      }),
    ),
  );
}
