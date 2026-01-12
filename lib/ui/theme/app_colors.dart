import 'package:flutter/material.dart';
import '../../data/enums/signal_type.dart';

/// Custom color palette for Boardroom Journal.
///
/// "Boardroom Executive" theme - Deep navy with warm gold accents
/// to convey professional authority with warmth.
class AppColors {
  AppColors._();

  // Primary palette - Deep navy
  static const Color primaryNavy = Color(0xFF1a2b4a);
  static const Color primaryNavyLight = Color(0xFF2d4166);
  static const Color primaryNavyDark = Color(0xFF0f1a2d);

  // Secondary palette - Warm gold accents
  static const Color accentGold = Color(0xFFc9a227);
  static const Color accentGoldLight = Color(0xFFe5c65a);
  static const Color accentGoldDark = Color(0xFF9a7a1a);

  // Tertiary palette - Leather brown
  static const Color tertiaryBrown = Color(0xFF8b5e3c);
  static const Color tertiaryBrownLight = Color(0xFFa77b56);
  static const Color tertiaryBrownDark = Color(0xFF6a4629);

  // Surface colors - Warm off-white (paper feel)
  static const Color surfaceLight = Color(0xFFFAF8F5);
  static const Color surfaceLightAlt = Color(0xFFF5F2ED);
  static const Color surfaceLightMuted = Color(0xFFEFEBE4);

  // Surface colors - Dark mode
  static const Color surfaceDark = Color(0xFF121820);
  static const Color surfaceDarkAlt = Color(0xFF1a2230);
  static const Color surfaceDarkMuted = Color(0xFF242d3d);

  // Text colors
  static const Color textOnLight = Color(0xFF1a2b4a);
  static const Color textOnLightMuted = Color(0xFF4a5568);
  static const Color textOnLightSubtle = Color(0xFF718096);

  static const Color textOnDark = Color(0xFFF7FAFC);
  static const Color textOnDarkMuted = Color(0xFFCBD5E0);
  static const Color textOnDarkSubtle = Color(0xFF718096);

  // Error/Warning/Success
  static const Color error = Color(0xFFb44d4d);
  static const Color errorDark = Color(0xFFe57373);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF2E7D32);

  /// Signal-specific semantic colors for the 7 signal types.
  /// Each signal type has a distinctive color for easy identification.
  static const Map<SignalType, Color> signalColors = {
    SignalType.wins: Color(0xFF2E7D32),        // Forest green - accomplishments
    SignalType.blockers: Color(0xFFD84315),    // Burnt orange - obstacles
    SignalType.risks: Color(0xFFC62828),       // Deep red - potential problems
    SignalType.avoidedDecision: Color(0xFF7B1FA2), // Purple - deferred choices
    SignalType.comfortWork: Color(0xFFFFA000), // Amber - false productivity
    SignalType.actions: Color(0xFF1565C0),     // Blue - forward commitments
    SignalType.learnings: Color(0xFF00838F),   // Teal - insights
  };

  /// Signal background colors (lighter variants for cards)
  static Map<SignalType, Color> signalBackgroundColors(Brightness brightness) {
    if (brightness == Brightness.light) {
      return {
        SignalType.wins: const Color(0xFFE8F5E9),
        SignalType.blockers: const Color(0xFFFBE9E7),
        SignalType.risks: const Color(0xFFFFEBEE),
        SignalType.avoidedDecision: const Color(0xFFF3E5F5),
        SignalType.comfortWork: const Color(0xFFFFF8E1),
        SignalType.actions: const Color(0xFFE3F2FD),
        SignalType.learnings: const Color(0xFFE0F7FA),
      };
    } else {
      return {
        SignalType.wins: const Color(0xFF1B3B2F),
        SignalType.blockers: const Color(0xFF3D2420),
        SignalType.risks: const Color(0xFF3D2022),
        SignalType.avoidedDecision: const Color(0xFF2D1F36),
        SignalType.comfortWork: const Color(0xFF3D3520),
        SignalType.actions: const Color(0xFF1A2D45),
        SignalType.learnings: const Color(0xFF1A3D40),
      };
    }
  }

  /// Get the color for a specific signal type.
  static Color forSignal(SignalType type) => signalColors[type]!;

  /// Light theme color scheme.
  static ColorScheme get lightScheme => const ColorScheme(
    brightness: Brightness.light,
    primary: primaryNavy,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFe8edf5),
    onPrimaryContainer: primaryNavyDark,
    secondary: accentGold,
    onSecondary: primaryNavy,
    secondaryContainer: Color(0xFFFFF3D6),
    onSecondaryContainer: accentGoldDark,
    tertiary: tertiaryBrown,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFF5E6D8),
    onTertiaryContainer: tertiaryBrownDark,
    error: error,
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: surfaceLight,
    onSurface: textOnLight,
    surfaceContainerHighest: surfaceLightMuted,
    onSurfaceVariant: textOnLightMuted,
    outline: Color(0xFFD4D4D4),
    outlineVariant: Color(0xFFE8E8E8),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: primaryNavy,
    onInverseSurface: Colors.white,
    inversePrimary: accentGoldLight,
  );

  /// Dark theme color scheme.
  static ColorScheme get darkScheme => const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF7B9FCC),
    onPrimary: primaryNavyDark,
    primaryContainer: Color(0xFF2d4166),
    onPrimaryContainer: Color(0xFFD6E3F7),
    secondary: accentGoldLight,
    onSecondary: Color(0xFF3D2F00),
    secondaryContainer: Color(0xFF594400),
    onSecondaryContainer: Color(0xFFFFE08C),
    tertiary: tertiaryBrownLight,
    onTertiary: Color(0xFF3D2515),
    tertiaryContainer: Color(0xFF5A3F2A),
    onTertiaryContainer: Color(0xFFF5DCC8),
    error: errorDark,
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: surfaceDark,
    onSurface: textOnDark,
    surfaceContainerHighest: surfaceDarkMuted,
    onSurfaceVariant: textOnDarkMuted,
    outline: Color(0xFF4A5568),
    outlineVariant: Color(0xFF2D3748),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: surfaceLight,
    onInverseSurface: textOnLight,
    inversePrimary: primaryNavy,
  );
}
