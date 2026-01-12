import 'package:flutter/material.dart';
import '../../data/enums/signal_type.dart';

/// Semantic color definitions for the 7 signal types.
///
/// Each signal type has:
/// - A primary color for icons and accents
/// - A background color for cards
/// - An icon to represent the signal type
class SignalColors {
  SignalColors._();

  /// Primary colors for each signal type.
  static const Map<SignalType, Color> primary = {
    SignalType.wins: Color(0xFF2E7D32),        // Forest green
    SignalType.blockers: Color(0xFFD84315),    // Burnt orange
    SignalType.risks: Color(0xFFC62828),       // Deep red
    SignalType.avoidedDecision: Color(0xFF7B1FA2), // Purple
    SignalType.comfortWork: Color(0xFFFFA000), // Amber
    SignalType.actions: Color(0xFF1565C0),     // Blue
    SignalType.learnings: Color(0xFF00838F),   // Teal
  };

  /// Light background colors for signal cards.
  static const Map<SignalType, Color> backgroundLight = {
    SignalType.wins: Color(0xFFE8F5E9),
    SignalType.blockers: Color(0xFFFBE9E7),
    SignalType.risks: Color(0xFFFFEBEE),
    SignalType.avoidedDecision: Color(0xFFF3E5F5),
    SignalType.comfortWork: Color(0xFFFFF8E1),
    SignalType.actions: Color(0xFFE3F2FD),
    SignalType.learnings: Color(0xFFE0F7FA),
  };

  /// Dark background colors for signal cards.
  static const Map<SignalType, Color> backgroundDark = {
    SignalType.wins: Color(0xFF1B3B2F),
    SignalType.blockers: Color(0xFF3D2420),
    SignalType.risks: Color(0xFF3D2022),
    SignalType.avoidedDecision: Color(0xFF2D1F36),
    SignalType.comfortWork: Color(0xFF3D3520),
    SignalType.actions: Color(0xFF1A2D45),
    SignalType.learnings: Color(0xFF1A3D40),
  };

  /// Icon data for each signal type.
  static const Map<SignalType, IconData> icons = {
    SignalType.wins: Icons.emoji_events_outlined,
    SignalType.blockers: Icons.block_outlined,
    SignalType.risks: Icons.warning_amber_outlined,
    SignalType.avoidedDecision: Icons.call_split_outlined,
    SignalType.comfortWork: Icons.loop_outlined,
    SignalType.actions: Icons.rocket_launch_outlined,
    SignalType.learnings: Icons.lightbulb_outline,
  };

  /// Get the primary color for a signal type.
  static Color getPrimary(SignalType type) => primary[type]!;

  /// Get the background color for a signal type based on brightness.
  static Color getBackground(SignalType type, Brightness brightness) {
    return brightness == Brightness.light
        ? backgroundLight[type]!
        : backgroundDark[type]!;
  }

  /// Get the icon for a signal type.
  static IconData getIcon(SignalType type) => icons[type]!;

  /// Get the display name for a signal type.
  static String getDisplayName(SignalType type) {
    switch (type) {
      case SignalType.wins:
        return 'Wins';
      case SignalType.blockers:
        return 'Blockers';
      case SignalType.risks:
        return 'Risks';
      case SignalType.avoidedDecision:
        return 'Avoided Decisions';
      case SignalType.comfortWork:
        return 'Comfort Work';
      case SignalType.actions:
        return 'Actions';
      case SignalType.learnings:
        return 'Learnings';
    }
  }

  /// Get a short label for compact displays.
  static String getShortLabel(SignalType type) {
    switch (type) {
      case SignalType.wins:
        return 'WIN';
      case SignalType.blockers:
        return 'BLOCK';
      case SignalType.risks:
        return 'RISK';
      case SignalType.avoidedDecision:
        return 'AVOID';
      case SignalType.comfortWork:
        return 'COMFORT';
      case SignalType.actions:
        return 'ACTION';
      case SignalType.learnings:
        return 'LEARN';
    }
  }
}
