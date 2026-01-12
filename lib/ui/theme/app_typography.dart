import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom typography for Boardroom Journal.
///
/// Uses a distinctive font pairing:
/// - Display/Headlines: Fraunces (editorial, warm serif)
/// - Body/UI: Inter (professional, readable sans-serif)
/// - Monospace: JetBrains Mono (for data, signals)
class AppTypography {
  AppTypography._();

  /// Creates the light theme text theme.
  static TextTheme lightTextTheme() => _buildTextTheme(Brightness.light);

  /// Creates the dark theme text theme.
  static TextTheme darkTextTheme() => _buildTextTheme(Brightness.dark);

  /// Builds a text theme for the given brightness.
  static TextTheme _buildTextTheme(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    final Color textColor = isLight ? const Color(0xFF1a2b4a) : const Color(0xFFF7FAFC);
    final Color textMuted = isLight ? const Color(0xFF4a5568) : const Color(0xFFCBD5E0);
    final Color textSubtle = isLight ? const Color(0xFF718096) : const Color(0xFF718096);

    return TextTheme(
      // Display styles - large headlines with Fraunces
      displayLarge: GoogleFonts.fraunces(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        height: 1.12,
        color: textColor,
      ),
      displayMedium: GoogleFonts.fraunces(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.16,
        color: textColor,
      ),
      displaySmall: GoogleFonts.fraunces(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.22,
        color: textColor,
      ),

      // Headline styles - section headers with Fraunces
      headlineLarge: GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.25,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.29,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.33,
        color: textColor,
      ),

      // Title styles - card titles with Inter
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.27,
        color: textColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        height: 1.5,
        color: textColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.43,
        color: textColor,
      ),

      // Body styles - main content with Inter
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.6,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.57,
        color: textColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.5,
        color: textMuted,
      ),

      // Label styles - buttons, chips with Inter
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.43,
        color: textColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.33,
        color: textColor,
      ),
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.45,
        color: textSubtle,
      ),
    );
  }

  /// Monospace text style for signals, data, and code elements.
  static TextStyle monoStyle({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 0,
      color: color,
    );
  }

  /// Editorial quote style for weekly briefs.
  static TextStyle quoteStyle({
    double fontSize = 18,
    Color? color,
  }) {
    return GoogleFonts.fraunces(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      letterSpacing: 0,
      height: 1.6,
      color: color,
    );
  }

  /// Large display number style for stats.
  static TextStyle statNumberStyle({
    double fontSize = 48,
    Color? color,
  }) {
    return GoogleFonts.fraunces(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
      height: 1,
      color: color,
    );
  }
}
