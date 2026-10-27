import 'package:flutter/material.dart';

/// Consent Horizon palette from Stitch DESIGN.md. Prefer [AppTokens] in widgets.
abstract final class AppColors {
  // Brand / interactive (DESIGN.md overrides)
  static const Color primary = Color(0xFF0284C7);
  static const Color primaryPressed = Color(0xFF0369A1);
  static const Color primaryContainer = Color(0xFF007BB9);
  static const Color skyTint = Color(0xFF0EA5E9);
  static const Color inversePrimary = Color(0xFF93CCFF);

  // M3 surface roles (light)
  static const Color background = Color(0xFFFAF8FF);
  static const Color surface = Color(0xFFFAF8FF);
  static const Color surfaceBright = Color(0xFFFAF8FF);
  static const Color surfaceDim = Color(0xFFD2D9F4);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F3FF);
  static const Color surfaceContainer = Color(0xFFEAEDFF);
  static const Color surfaceContainerHigh = Color(0xFFE2E7FF);
  static const Color surfaceContainerHighest = Color(0xFFDAE2FD);
  static const Color surfaceVariant = Color(0xFFDAE2FD);

  // Brand neutrals (narrative palette)
  static const Color trustNavy = Color(0xFF0F172A);
  static const Color slateSecondary = Color(0xFF475569);
  static const Color mutedTertiary = Color(0xFF94A3B8);
  static const Color coolIceSlate = Color(0xFFF8FAFC);
  static const Color lightSurfaceSlate = Color(0xFFF1F5F9);
  static const Color borderSlate = Color(0xFFE2E8F0);
  static const Color inputBorder = Color(0xFFCBD5E1);

  // On-surface (M3)
  static const Color onSurface = Color(0xFF131B2E);
  static const Color onSurfaceVariant = Color(0xFF3F4850);
  static const Color outline = Color(0xFF707881);
  static const Color outlineVariant = Color(0xFFBFC7D2);
  static const Color inverseSurface = Color(0xFF283044);
  static const Color inverseOnSurface = Color(0xFFEEF0FF);

  // Consent / governance
  static const Color consented = Color(0xFF10B981);
  static const Color consentedLabel = Color(0xFF065F46);
  static const Color consentedSoft = Color(0xFFECFDF5);
  static const Color pending = Color(0xFFF59E0B);
  static const Color pendingSoft = Color(0xFFFFFBEB);
  static const Color revoked = Color(0xFFF43F5E);
  static const Color revokeText = Color(0xFFE11D48);
  static const Color revokedSoft = Color(0xFFFFF1F2);
  static const Color dormant = Color(0xFF64748B);
  static const Color dormantSoft = Color(0xFFF1F5F9);

  // Semantic (aligned to design system)
  static const Color success = consented;
  static const Color successSoft = consentedSoft;
  static const Color warning = pending;
  static const Color warningSoft = pendingSoft;
  static const Color danger = Color(0xFFBA1A1A);
  static const Color dangerSoft = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color info = skyTint;
  static const Color disabled = mutedTertiary;
  static const Color white = Color(0xFFFFFFFF);

  // Dark theme surfaces
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111A2E);
  static const Color darkSurfaceContainer = Color(0xFF1A2540);
  static const Color darkBorder = Color(0xFF24314A);
  static const Color darkOnSurface = Color(0xFFF8FAFC);
  static const Color darkOnSurfaceVariant = Color(0xFF98A2B3);
  static const Color darkPrimarySoft = Color(0xFF0C2D44);
  static const Color darkSuccessSoft = Color(0xFF163528);
  static const Color darkWarningSoft = Color(0xFF3A2A12);
  static const Color darkDangerSoft = Color(0xFF3A1A18);

  // Elevation / overlays
  static const Color modalScrim = Color(0x4D0F172A);
  static const Color focusHalo = Color(0x260EA5E9);
  static const Color loaderOverlay = Color(0x730F172A);

  // Legacy aliases used by AppConfig / chrome
  static const Color primaryDark = primaryPressed;
  static const Color deepNavy = trustNavy;
  static const Color navySurface = darkSurface;
  static const Color lightBackground = coolIceSlate;
  static const Color lightSurface = surfaceContainerLowest;
  static const Color lightBorder = borderSlate;
  static const Color lightInput = lightSurfaceSlate;
  static const Color lightPrimaryText = trustNavy;
  static const Color lightSecondaryText = slateSecondary;
  static const Color lightPrimarySoft = Color(0xFFE0F2FE);
  static const Color darkPrimaryText = darkOnSurface;
  static const Color darkSecondaryText = darkOnSurfaceVariant;
  static const Color darkInput = darkSurfaceContainer;
}
