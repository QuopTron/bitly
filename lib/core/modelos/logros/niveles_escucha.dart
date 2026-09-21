// ─────────────────────────────────────────────────────────────
// niveles_escucha.dart — Escalera de NIVELES DE ESCUCHA. Modelo puro
// (sin widgets ni I/O): recibe las horas escuchadas y devuelve el
// nivel actual, el progreso y qué premios quedan por descubrir.
//
// Por qué existe: los logros no pueden quedarse en "100 canciones".
// La escalera está armada para que el último nivel exija ~35.000 horas
// de escucha real, o sea escuchar 24 horas por día durante MÁS DE 4
// AÑOS: siempre hay algo por delante, y los premios son cosméticos o de
// función dentro de la app (nunca dinero ni nada que dependa de un
// tercero que pueda caerse).
//
// Los nombres y premios NO viven acá: son texto localizado
// (StringsNiveles en la l10n), indexados por la MISMA posición que esta
// lista. Así el modelo guarda solo el umbral (horas) y el idioma se
// resuelve al pintar.
//
// Se conecta con: progreso_escucha.dart (lo mide) +
// settings_estadisticas_niveles.dart (lo pinta) + StringsNiveles.
// Parte del flujo: Ajustes → Estadísticas (niveles y recompensas).
// ─────────────────────────────────────────────────────────────

/// Un nivel de la escalera: sólo el umbral de horas. El nombre y el
/// premio se resuelven por índice desde `StringsNiveles`.
class NivelEscucha {
  /// Horas de escucha acumuladas necesarias para llegar.
  final int horas;

  const NivelEscucha({required this.horas});
}

/// Escalera completa. Los umbrales van en progresión suave al principio
/// (para que el primer premio llegue pronto) y se estiran después.
const List<NivelEscucha> nivelesEscucha = [
  NivelEscucha(horas: 1),
  NivelEscucha(horas: 10),
  NivelEscucha(horas: 50),
  NivelEscucha(horas: 150),
  NivelEscucha(horas: 400),
  NivelEscucha(horas: 1_000),
  NivelEscucha(horas: 2_500),
  NivelEscucha(horas: 5_000),
  NivelEscucha(horas: 8_000),
  NivelEscucha(horas: 8_760),
  NivelEscucha(horas: 17_520),
  NivelEscucha(horas: 26_280),
  NivelEscucha(horas: 35_040),
];
