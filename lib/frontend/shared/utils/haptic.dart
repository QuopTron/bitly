import 'package:flutter/services.dart';

/// Lightweight helper for haptic feedback. Calls are no-ops on web/desktop.
class Haptic {
  /// Light tap — like toggling a like, pressing a button.
  static void tap() => HapticFeedback.lightImpact();

  /// Medium tap — like play/pause, starting a download.
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy tap — like completing a download, long-press action.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Selection changed — like switching tabs, scrolling to a value.
  static void selection() => HapticFeedback.selectionClick();
}
