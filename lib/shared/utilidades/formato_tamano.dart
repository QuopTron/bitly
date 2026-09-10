// ─────────────────────────────────────────────────────────────
// formato_tamano.dart — Formatea bytes crudos a texto legible
// (KB / MB). Muestra un decimal para valores MB (p.ej. "3.2 MB").
// Se conecta con: vistas de descargas y caché (shared/widgets).
// Parte del flujo: presentación (tamaños de archivo).
// ─────────────────────────────────────────────────────────────

/// Formatea bytes a un string legible en KB o MB.
String formatearBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  if (mb >= 100) return '${mb.round()} MB';
  return '${mb.toStringAsFixed(1)} MB';
}