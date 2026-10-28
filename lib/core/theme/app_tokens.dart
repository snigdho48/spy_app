import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_colors.dart';

/// Consent Horizon spacing (DESIGN.md — 8pt grid).
abstract final class AppSpacing {
  static const double xs = 4; // space-xs
  static const double sm = 8; // space-sm
  static const double md = 16; // space-md / gutter / margin mobile
  static const double lg = 24; // space-lg
  static const double xl = 32; // space-xl
  static const double xxl = 48;
  static const double section = 32;
  static const double page = 16;
  static const double pageTablet = 32;
  static const double pageDesktop = 48;
  static const double gutter = 16;
  static const double gutterTablet = 24;
  static const double gutterDesktop = 32;
  static const double touchMin = 48;
}

/// Consent Horizon radii (DESIGN.md).
abstract final class AppRadius {
  static const double sm = 4;
  static const double base = 8; // DESIGN.md rounded DEFAULT
  static const double md = 12;
  static const double lg = 16; // cards
  static const double xl = 24;
  static const double full = 9999;

  static const double card = lg;
  static const double button = full;
  static const double input = md;
  static const double badge = full;
  static const double sheet = xl;
  static const double chipInner = base;

  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius buttonBorder = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius inputBorder = BorderRadius.all(
    Radius.circular(input),
  );
  static const BorderRadius sheetBorder = BorderRadius.all(
    Radius.circular(sheet),
  );
}

/// Layout breakpoints from Consent Horizon DESIGN.md.
abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double expanded = 1024;
  static const double maxContentWidth = 1280;

  static AppLayoutSize ofWidth(double width) {
    if (width < compact) return AppLayoutSize.compact;
    if (width < expanded) return AppLayoutSize.medium;
    return AppLayoutSize.expanded;
  }
}

enum AppLayoutSize { compact, medium, expanded }

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerLow,
    required this.surfaceContainerHigh,
    required this.border,
    required this.input,
    required this.inputBorder,
    required this.primaryText,
    required this.secondaryText,
    required this.primarySoft,
    required this.successSoft,
    required this.warningSoft,
    required this.dangerSoft,
    required this.dormantSoft,
    required this.navy,
    required this.navySurface,
    required this.consented,
    required this.consentedLabel,
    required this.pending,
    required this.revoked,
    required this.revokeText,
    required this.dormant,
    required this.focusHalo,
    required this.modalScrim,
    required this.cardShadow,
    required this.floatingShadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerLow;
  final Color surfaceContainerHigh;
  final Color border;
  final Color input;
  final Color inputBorder;
  final Color primaryText;
  final Color secondaryText;
  final Color primarySoft;
  final Color successSoft;
  final Color warningSoft;
  final Color dangerSoft;
  final Color dormantSoft;
  final Color navy;
  final Color navySurface;
  final Color consented;
  final Color consentedLabel;
  final Color pending;
  final Color revoked;
  final Color revokeText;
  final Color dormant;
  final Color focusHalo;
  final Color modalScrim;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> floatingShadow;

  static const List<BoxShadow> _lightCardShadow = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> _lightFloatingShadow = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 6, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const AppTokens light = AppTokens(
    background: AppColors.coolIceSlate,
    surface: AppColors.surfaceContainerLowest,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    border: AppColors.borderSlate,
    input: AppColors.lightSurfaceSlate,
    inputBorder: AppColors.inputBorder,
    primaryText: AppColors.trustNavy,
    secondaryText: AppColors.slateSecondary,
    primarySoft: AppColors.lightPrimarySoft,
    successSoft: AppColors.consentedSoft,
    warningSoft: AppColors.pendingSoft,
    dangerSoft: AppColors.revokedSoft,
    dormantSoft: AppColors.dormantSoft,
    navy: AppColors.trustNavy,
    navySurface: AppColors.darkSurface,
    consented: AppColors.consented,
    consentedLabel: AppColors.consentedLabel,
    pending: AppColors.pending,
    revoked: AppColors.revoked,
    revokeText: AppColors.revokeText,
    dormant: AppColors.dormant,
    focusHalo: AppColors.focusHalo,
    modalScrim: AppColors.modalScrim,
    cardShadow: _lightCardShadow,
    floatingShadow: _lightFloatingShadow,
  );

  static const AppTokens dark = AppTokens(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceContainer: AppColors.darkSurfaceContainer,
    surfaceContainerLow: Color(0xFF0F172A),
    surfaceContainerHigh: Color(0xFF1E293B),
    border: AppColors.darkBorder,
    input: AppColors.darkInput,
    inputBorder: AppColors.darkBorder,
    primaryText: AppColors.darkOnSurface,
    secondaryText: AppColors.darkOnSurfaceVariant,
    primarySoft: AppColors.darkPrimarySoft,
    successSoft: AppColors.darkSuccessSoft,
    warningSoft: AppColors.darkWarningSoft,
    dangerSoft: AppColors.darkDangerSoft,
    dormantSoft: Color(0xFF1E293B),
    navy: AppColors.trustNavy,
    navySurface: AppColors.darkSurface,
    consented: AppColors.consented,
    consentedLabel: Color(0xFF6EE7B7),
    pending: AppColors.pending,
    revoked: AppColors.revoked,
    revokeText: Color(0xFFFB7185),
    dormant: AppColors.mutedTertiary,
    focusHalo: AppColors.focusHalo,
    modalScrim: Color(0x99000000),
    cardShadow: [],
    floatingShadow: [],
  );

  @override
  AppTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceContainer,
    Color? surfaceContainerLow,
    Color? surfaceContainerHigh,
    Color? border,
    Color? input,
    Color? inputBorder,
    Color? primaryText,
    Color? secondaryText,
    Color? primarySoft,
    Color? successSoft,
    Color? warningSoft,
    Color? dangerSoft,
    Color? dormantSoft,
    Color? navy,
    Color? navySurface,
    Color? consented,
    Color? consentedLabel,
    Color? pending,
    Color? revoked,
    Color? revokeText,
    Color? dormant,
    Color? focusHalo,
    Color? modalScrim,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? floatingShadow,
  }) {
    return AppTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      border: border ?? this.border,
      input: input ?? this.input,
      inputBorder: inputBorder ?? this.inputBorder,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      primarySoft: primarySoft ?? this.primarySoft,
      successSoft: successSoft ?? this.successSoft,
      warningSoft: warningSoft ?? this.warningSoft,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dormantSoft: dormantSoft ?? this.dormantSoft,
      navy: navy ?? this.navy,
      navySurface: navySurface ?? this.navySurface,
      consented: consented ?? this.consented,
      consentedLabel: consentedLabel ?? this.consentedLabel,
      pending: pending ?? this.pending,
      revoked: revoked ?? this.revoked,
      revokeText: revokeText ?? this.revokeText,
      dormant: dormant ?? this.dormant,
      focusHalo: focusHalo ?? this.focusHalo,
      modalScrim: modalScrim ?? this.modalScrim,
      cardShadow: cardShadow ?? this.cardShadow,
      floatingShadow: floatingShadow ?? this.floatingShadow,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      surfaceContainerLow: Color.lerp(
        surfaceContainerLow,
        other.surfaceContainerLow,
        t,
      )!,
      surfaceContainerHigh: Color.lerp(
        surfaceContainerHigh,
        other.surfaceContainerHigh,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      input: Color.lerp(input, other.input, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      dormantSoft: Color.lerp(dormantSoft, other.dormantSoft, t)!,
      navy: Color.lerp(navy, other.navy, t)!,
      navySurface: Color.lerp(navySurface, other.navySurface, t)!,
      consented: Color.lerp(consented, other.consented, t)!,
      consentedLabel: Color.lerp(consentedLabel, other.consentedLabel, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      revoked: Color.lerp(revoked, other.revoked, t)!,
      revokeText: Color.lerp(revokeText, other.revokeText, t)!,
      dormant: Color.lerp(dormant, other.dormant, t)!,
      focusHalo: Color.lerp(focusHalo, other.focusHalo, t)!,
      modalScrim: Color.lerp(modalScrim, other.modalScrim, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      floatingShadow: t < 0.5 ? floatingShadow : other.floatingShadow,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.light;

  AppLayoutSize get layoutSize {
    final width = MediaQuery.sizeOf(this).width;
    return AppBreakpoints.ofWidth(width);
  }

  EdgeInsets get pagePadding {
    final size = layoutSize;
    final horizontal = switch (size) {
      AppLayoutSize.compact => AppSpacing.page,
      AppLayoutSize.medium => AppSpacing.pageTablet,
      AppLayoutSize.expanded => AppSpacing.pageDesktop,
    };
    return EdgeInsets.fromLTRB(
      horizontal,
      AppSpacing.sm,
      horizontal,
      AppSpacing.xl,
    );
  }

  double get contentMaxWidth => AppBreakpoints.maxContentWidth;
}
