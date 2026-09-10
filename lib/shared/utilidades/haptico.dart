// ─────────────────────────────────────────────────────────────
// haptico.dart — Feedback háptico ligero para acciones de la UI
// (like, play/pause, descargas, tabs). Las llamadas son no-op en
// web/desktop donde no hay motor háptico.
// Se conecta con: todas las vistas y widgets con acciones.
// Parte del flujo: presentación (feedback de interacción).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/services.dart';

/// Feedback háptico global (no-op en web/desktop).
class Haptico {
  /// TAP ligero — like, botón normal.
  static void tap() => HapticFeedback.lightImpact();

  /// TAP medio — play/pause, iniciar descarga.
  static void medio() => HapticFeedback.mediumImpact();

  /// TAP fuerte — descarga completada, long-press.
  static void fuerte() => HapticFeedback.heavyImpact();

  /// Cambio de selección — tabs, scroll a un valor.
  static void seleccion() => HapticFeedback.selectionClick();
}