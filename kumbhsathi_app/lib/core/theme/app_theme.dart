import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Design System v2 "Sanctum" Material themes (DESIGN.md).
/// Depth via tonal layering + hairline borders; radius scale from AppRadius.
abstract final class AppTheme {
  // Legacy radius aliases still referenced by v1 screens.
  static const double rLg = AppRadius.chip;
  static const double rXl = AppRadius.input;
  static const double r2xl = AppRadius.card;

  static const _input = BorderRadius.all(Radius.circular(AppRadius.input));
  static const _card = BorderRadius.all(Radius.circular(AppRadius.card));

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.primaryBright : AppColors.primary,
      onPrimary: isDark ? AppColors.primaryDeep : AppColors.onPrimary,
      primaryContainer:
          isDark ? const Color(0xFF14335C) : AppColors.primaryContainer,
      onPrimaryContainer:
          isDark ? const Color(0xFFC9DDF8) : AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer:
          isDark ? const Color(0xFF14335C) : AppColors.secondaryContainer,
      onSecondaryContainer:
          isDark ? const Color(0xFFC9DDF8) : AppColors.onSecondaryContainer,
      tertiary: AppColors.accent,
      onTertiary: AppColors.onAccent,
      tertiaryContainer:
          isDark ? const Color(0xFF4A2A00) : AppColors.accentContainer,
      onTertiaryContainer:
          isDark ? const Color(0xFFFBD9AE) : AppColors.onAccentContainer,
      error: AppColors.danger,
      onError: AppColors.onError,
      errorContainer:
          isDark ? const Color(0xFF5C1616) : AppColors.dangerContainer,
      onErrorContainer:
          isDark ? const Color(0xFFF6C6C6) : AppColors.onDangerContainer,
      surface: isDark ? AppColors.surfaceDark : AppColors.surface,
      onSurface: isDark ? AppColors.inkDark : AppColors.ink,
      surfaceContainerLowest:
          isDark ? AppColors.surfaceSunkenDark : AppColors.surface,
      surfaceContainerLow:
          isDark ? AppColors.surfaceDark : AppColors.surfaceRaised,
      surfaceContainer:
          isDark ? AppColors.surfaceRaisedDark : AppColors.surfaceContainer,
      surfaceContainerHigh:
          isDark ? const Color(0xFF1E2B44) : AppColors.surfaceSunken,
      surfaceContainerHighest:
          isDark ? const Color(0xFF253552) : AppColors.surfaceContainerHighest,
      onSurfaceVariant: isDark ? AppColors.inkMediumDark : AppColors.inkMedium,
      outline: isDark ? const Color(0xFF3A4A66) : AppColors.outline,
      outlineVariant: isDark ? AppColors.hairlineDark : AppColors.hairline,
      inverseSurface: isDark ? AppColors.background : AppColors.primaryDeep,
      onInverseSurface: isDark ? AppColors.ink : Colors.white,
      inversePrimary: AppColors.primaryBright,
      surfaceTint: Colors.transparent,
    );

    final textTheme = AppTypography.textTheme(brightness);
    final hairline = isDark ? AppColors.hairlineDark : AppColors.hairline;
    final scaffoldBg = isDark ? AppColors.backgroundDark : AppColors.background;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scaffoldBg,
        foregroundColor: scheme.onSurface,
        titleTextStyle:
            textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: _card,
          side: BorderSide(color: hairline),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? AppColors.surfaceSunkenDark : AppColors.surfaceSunken,
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: const OutlineInputBorder(
            borderRadius: _input, borderSide: BorderSide.none),
        enabledBorder: const OutlineInputBorder(
            borderRadius: _input, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: _input,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: _input,
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: _input,
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(borderRadius: _input),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: scheme.primary, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: _input),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.chip)),
        ),
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: hairline, space: 1, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: _input),
        iconColor: scheme.onSurfaceVariant,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.modal)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.surfaceRaisedDark : AppColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: _input),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.success : null),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: hairline,
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
        dataTextStyle: textTheme.bodyMedium,
        dividerThickness: 1,
      ),
    );
  }
}
