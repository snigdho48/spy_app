import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spy_love/core/theme/app_colors.dart';
import 'package:spy_love/core/theme/app_tokens.dart';

/// Consent Horizon ThemeData (Stitch DESIGN.md) — light and dark.
class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppTokens.light);

  static ThemeData get dark => _build(Brightness.dark, AppTokens.dark);

  static ThemeData _build(Brightness brightness, AppTokens tokens) {
    final isDark = brightness == Brightness.dark;
    final base = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    final textTheme = base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w600,
        height: 64 / 56,
        letterSpacing: -0.02 * 16,
        color: tokens.primaryText,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 40 / 32,
        letterSpacing: -0.015 * 16,
        color: tokens.primaryText,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 26, // headline-lg-mobile
        fontWeight: FontWeight.w600,
        height: 32 / 26,
        letterSpacing: -0.01 * 16,
        color: tokens.primaryText,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: tokens.primaryText,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 24 / 18,
        color: tokens.primaryText,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: tokens.primaryText,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 26 / 16,
        color: tokens.primaryText,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 22 / 14,
        color: tokens.primaryText,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.01 * 16,
        color: tokens.primaryText,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.02 * 16,
        color: tokens.secondaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 14 / 11,
        letterSpacing: 0.04 * 16,
        color: tokens.secondaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: isDark ? AppColors.inversePrimary : const Color(0xFFFDFCFF),
      secondary: AppColors.skyTint,
      onSecondary: AppColors.white,
      secondaryContainer: const Color(0xFF39B8FD),
      onSecondaryContainer: const Color(0xFF004666),
      tertiary: AppColors.consented,
      onTertiary: AppColors.white,
      tertiaryContainer: const Color(0xFF00855B),
      onTertiaryContainer: const Color(0xFFF5FFF6),
      error: AppColors.danger,
      onError: AppColors.onError,
      errorContainer: AppColors.dangerSoft,
      onErrorContainer: AppColors.onErrorContainer,
      surface: tokens.surface,
      onSurface: tokens.primaryText,
      onSurfaceVariant: tokens.secondaryText,
      outline: tokens.border,
      outlineVariant: isDark ? tokens.border : AppColors.outlineVariant,
      surfaceContainerHighest: tokens.surfaceContainerHigh,
      surfaceContainerHigh: tokens.surfaceContainer,
      surfaceContainer: tokens.surfaceContainerLow,
      surfaceContainerLow: tokens.input,
      inverseSurface: AppColors.inverseSurface,
      onInverseSurface: AppColors.inverseOnSurface,
      inversePrimary: AppColors.inversePrimary,
    );

    final pill = RoundedRectangleBorder(borderRadius: AppRadius.buttonBorder);
    final cardShape = RoundedRectangleBorder(
      borderRadius: AppRadius.cardBorder,
      side: BorderSide(color: tokens.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      canvasColor: tokens.background,
      textTheme: textTheme,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: tokens.background,
        foregroundColor: tokens.primaryText,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.headlineSmall,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSpacing.touchMin, AppSpacing.touchMin),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(color: tokens.border, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: tokens.border,
          minimumSize: const Size(0, AppSpacing.touchMin),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: pill,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primaryText,
          backgroundColor: tokens.input,
          side: BorderSide.none,
          minimumSize: const Size(0, AppSpacing.touchMin),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, AppSpacing.touchMin),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
        labelStyle: textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: tokens.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: tokens.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.skyTint, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.input,
        selectedColor: tokens.primarySoft,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium?.copyWith(color: tokens.primaryText),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        elevation: 0,
        height: 72,
        indicatorColor: tokens.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? AppColors.primary : tokens.secondaryText,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : tokens.secondaryText,
            size: 22,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.primarySoft,
        selectedIconTheme: const IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: tokens.secondaryText),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: AppColors.primary),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: tokens.secondaryText),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.navy,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: tokens.secondaryText,
        indicatorColor: AppColors.primary,
        dividerColor: tokens.border,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.bodyMedium,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? AppColors.white : tokens.secondaryText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? AppColors.primary : tokens.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? AppColors.primary : Colors.transparent;
        }),
        side: BorderSide(color: AppColors.mutedTertiary, width: 1.5),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    );
  }
}
