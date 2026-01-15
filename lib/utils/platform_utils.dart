import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform detection utilities for web/mobile conditional logic.
class PlatformUtils {
  /// Whether running on web platform.
  static bool get isWeb => kIsWeb;

  /// Whether running on a mobile platform (iOS or Android).
  /// Always false on web.
  static bool get isMobile => !kIsWeb;
}
