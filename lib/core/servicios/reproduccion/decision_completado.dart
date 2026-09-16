// ─────────────────────────────────────────────────────────────
// decision_completado.dart — Lógica PURA de qué hacer cuando el
// player emite `completed` (fin de media). Antes esta decisión vivía
// dentro del cubit y tenía un agujero serio: cuando la completación
// llegaba SIN duración conocida (o con la posición lejos del final)
// devolvía "no avances" SIN reabrir nada → la canción terminaba y la
// cola quedaba en pausa aunque hubiera más canciones.
//
// Acá las tres salidas posibles se deciden una sola vez y se pueden
// testear sin player:
//   avanzar       → fin real: seguir con la próxima canción.
//   reabrirMismo  → completación FALSA recuperable (preview o stream
//                   truncado): re-resolver el MISMO track una vez.
//   ignorar       → `completed` espurio de media_kit justo tras open:
//                   el audio sigue sonando, no tocar nada.
// Se conecta con: reproductor_completado_guards.dart (usa esta decisión).
// Parte del flujo: reproducción (fin de canción → siguiente).
// ─────────────────────────────────────────────────────────────

/// Qué hacer con una completación del player.
enum DecisionCompletado {
  /// Fin real del track: avanzar la cola (o terminar si no hay repeat).
  avanzar,

  /// Completación falsa recuperable: reabrir el MISMO track una vez.
  reabrirMismo,

  /// Evento espurio con el audio todavía sonando: no hacer nada.
  ignorar,
}

/// Un stream http que dura menos de esta fracción de la duración del catálogo
/// es, casi con seguridad, un preview/clip ajeno a la canción completa.
const double fraccionPreviewCompletado = 0.55;

/// Margen (ms) con el que se considera que la posición llegó al final.
const int margenFinCompletadoMs = 1500;

/// Ventana (ms) tras un open en la que un `completed` sin duración y en la
/// posición 0 se considera el evento espurio que emite media_kit antes de
/// parsear la duración real.
const int ventanaEventoEspurioMs = 3000;

/// Decide qué hacer con la completación. Todos los datos entran por parámetro
/// para poder testear cada caso sin player ni red.
DecisionCompletado decidirCompletado({
  /// ¿La URI abierta era http(s)? Los archivos locales no sufren estos falsos
  /// positivos (su EOF es siempre real).
  required bool desdeHttp,

  /// Duración REAL que reportó el media (0 = todavía no la conoce).
  required int durMs,

  /// Posición del media en el momento del `completed`.
  required int posMs,

  /// Duración de la canción en el catálogo (feed). Sirve para detectar clips.
  required int duracionCatalogoMs,

  /// ms desde que el media terminó de abrir (-1 = desconocido).
  required int msDesdeOpen,

  /// ¿Ya se intentó recuperar este track por preview?
  required bool yaSeIntentoPreview,

  /// ¿Ya se intentó recuperar este track por stream muerto/truncado?
  required bool yaSeIntentoStreamMuerto,
}) {
  if (!desdeHttp) return DecisionCompletado.avanzar;

  // ── 1) Clip corto: el media dura mucho menos que la canción ────────────
  final esPreview = durMs > 0 &&
      duracionCatalogoMs >= 60000 &&
      durMs <= duracionCatalogoMs * fraccionPreviewCompletado;
  if (esPreview) {
    return yaSeIntentoPreview
        ? DecisionCompletado.avanzar
        : DecisionCompletado.reabrirMismo;
  }

  // ── 2) Stream truncado: murió antes del final ──────────────────────────
  if (durMs > 0 && posMs < durMs - margenFinCompletadoMs) {
    return yaSeIntentoStreamMuerto
        ? DecisionCompletado.avanzar
        : DecisionCompletado.reabrirMismo;
  }

  // ── 3) Completación SIN duración conocida ──────────────────────────────
  // Nunca se devuelve "ignorar" sin poder descartar un fin real: dejar la
  // cola muda es peor que reabrir una vez.
  if (durMs <= 0) {
    final espurio = posMs <= 0 &&
        msDesdeOpen >= 0 &&
        msDesdeOpen < ventanaEventoEspurioMs;
    if (espurio) return DecisionCompletado.ignorar;
    // Murió en el arranque sin duración: reabrir una vez por el respaldo.
    if (posMs <= 0) {
      return yaSeIntentoStreamMuerto
          ? DecisionCompletado.avanzar
          : DecisionCompletado.reabrirMismo;
    }
    // Sonó algo y no reportó duración (radio/live): es un fin real.
    return DecisionCompletado.avanzar;
  }

  return DecisionCompletado.avanzar;
}
