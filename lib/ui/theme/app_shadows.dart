import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Custom shadow definitions for Boardroom Journal.
///
/// Uses colored shadows to add depth and atmosphere.
class AppShadows {
  AppShadows._();

  /// Subtle elevation shadow for cards.
  static List<BoxShadow> cardShadow(Brightness brightness) {
    if (brightness == Brightness.light) {
      return [
        BoxShadow(
          color: AppColors.primaryNavy.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: AppColors.primaryNavy.withOpacity(0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
    } else {
      return [
        const BoxShadow(
          color: Colors.black26,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
        const BoxShadow(
          color: Colors.black38,
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ];
    }
  }

  /// Elevated shadow for modal/dialog elements.
  static List<BoxShadow> elevatedShadow(Brightness brightness) {
    if (brightness == Brightness.light) {
      return [
        BoxShadow(
          color: AppColors.primaryNavy.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: AppColors.primaryNavy.withOpacity(0.12),
          blurRadius: 48,
          offset: const Offset(0, 16),
        ),
      ];
    } else {
      return [
        const BoxShadow(
          color: Colors.black45,
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
        const BoxShadow(
          color: Colors.black54,
          blurRadius: 48,
          offset: Offset(0, 16),
        ),
      ];
    }
  }

  /// Soft glow effect for highlighted elements.
  static List<BoxShadow> glowShadow(Color color, {double intensity = 0.3}) {
    return [
      BoxShadow(
        color: color.withOpacity(intensity * 0.5),
        blurRadius: 8,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: color.withOpacity(intensity),
        blurRadius: 24,
        spreadRadius: -4,
      ),
    ];
  }

  /// Accent glow for call-to-action buttons.
  static List<BoxShadow> ctaGlow(Brightness brightness) {
    final color = brightness == Brightness.light
        ? AppColors.accentGold
        : AppColors.accentGoldLight;
    return glowShadow(color, intensity: 0.25);
  }

  /// Recording button glow effect.
  static List<BoxShadow> recordingGlow({double amplitude = 1.0}) {
    return [
      BoxShadow(
        color: Colors.red.withOpacity(0.3 * amplitude),
        blurRadius: 16 * amplitude,
        spreadRadius: 4 * amplitude,
      ),
      BoxShadow(
        color: Colors.red.withOpacity(0.5 * amplitude),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ];
  }

  /// Inner shadow for inset elements.
  static BoxDecoration insetDecoration(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    return BoxDecoration(
      color: isLight
          ? AppColors.surfaceLightMuted
          : AppColors.surfaceDarkMuted,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isLight ? 0.06 : 0.2),
          blurRadius: 4,
          offset: const Offset(0, 2),
          // Inset shadow effect simulated with inner positioning
        ),
      ],
    );
  }

  /// Signal type colored shadow.
  static List<BoxShadow> signalShadow(Color signalColor) {
    return [
      BoxShadow(
        color: signalColor.withOpacity(0.15),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: signalColor.withOpacity(0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
