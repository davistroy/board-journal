import 'package:flutter/material.dart';

/// Consistent spacing values for Boardroom Journal.
///
/// Uses a 4px base unit with semantic naming for common spacings.
class AppSpacing {
  AppSpacing._();

  // Base unit
  static const double unit = 4.0;

  // Spacing scale
  static const double xs = unit;           // 4px
  static const double sm = unit * 2;       // 8px
  static const double md = unit * 4;       // 16px
  static const double lg = unit * 6;       // 24px
  static const double xl = unit * 8;       // 32px
  static const double xxl = unit * 12;     // 48px
  static const double xxxl = unit * 16;    // 64px

  // Semantic spacing
  static const double cardPadding = md;           // 16px
  static const double cardPaddingLarge = lg;      // 24px
  static const double screenPadding = md;         // 16px
  static const double screenPaddingLarge = lg;    // 24px
  static const double sectionGap = xl;            // 32px
  static const double itemGap = sm;               // 8px
  static const double buttonPadding = md;         // 16px
  static const double iconPadding = sm;           // 8px

  // Edge insets helpers
  static const EdgeInsets screenInsets = EdgeInsets.all(screenPadding);
  static const EdgeInsets screenInsetsLarge = EdgeInsets.all(screenPaddingLarge);
  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);
  static const EdgeInsets cardInsetsLarge = EdgeInsets.all(cardPaddingLarge);

  static const EdgeInsets horizontalScreenInsets = EdgeInsets.symmetric(
    horizontal: screenPadding,
  );
  static const EdgeInsets verticalScreenInsets = EdgeInsets.symmetric(
    vertical: screenPadding,
  );

  // Border radius values
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusXxl = 24.0;
  static const double radiusRound = 9999.0;

  // BorderRadius helpers
  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius borderRadiusXxl = BorderRadius.all(Radius.circular(radiusXxl));
  static const BorderRadius borderRadiusRound = BorderRadius.all(Radius.circular(radiusRound));

  // Card-specific
  static const BorderRadius cardRadius = borderRadiusLg;
  static const BorderRadius buttonRadius = borderRadiusMd;
  static const BorderRadius chipRadius = borderRadiusRound;
}
