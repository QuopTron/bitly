// ─────────────────────────────────────────────────────────────
// progreso_escucha.dart — Cálculo del progreso en la escalera de
// niveles de escucha (niveles_escucha.dart): nivel alcanzado, tramo
// hacia el siguiente y horas que faltan.
//
// Va aparte del catálogo de niveles para que cada archivo haga una sola
// cosa: uno describe la escalera, el otro la mide.
//
// Se conecta con: niveles_escucha.dart (el catálogo) +
// settings_estadisticas_niveles.dart (lo pinta).
// Parte del flujo: Ajustes → Estadísticas (niveles y recompensas).
// ─────────────────────────────────────────────────────────────

import 'niveles_escucha.dart';

/// Estado de la escalera para un total de horas escuchadas.
class ProgresoEscucha {
  /// Índice del último nivel alcanzado (-1 si todavía no llegó a ninguno).
  final int indice;

  /// Nivel actual (el primero si todavía no llegó a ninguno).
  final NivelEscucha actual;

  /// Nivel siguiente, o null si ya está en el techo de la escalera.
  final NivelEscucha? siguiente;

  /// 0.0–1.0 dentro del tramo hacia [siguiente].
  final double avance;

  /// Horas que faltan para [siguiente] (0 si no hay siguiente).
  final int horasFaltantes;

  const ProgresoEscucha({
    required this.indice,
    required this.actual,
    required this.siguiente,
    required this.avance,
    required this.horasFaltantes,
  });

  /// ¿Ya se desbloqueó el nivel de índice [i]?
  bool desbloqueado(int i) => i <= indice;

  /// ¿Alcanzó al menos el primer nivel? Con 0 horas todavía no hay nivel, y
  /// la interfaz lo dice así en vez de mostrar el nombre del primero.
  bool get tieneNivel => indice >= 0;

  /// Calcula el progreso a partir de milisegundos escuchados.
  ///
  /// Se usa el MISMO dato que ya guarda la app (tiempo reproducido total),
  /// así el nivel no puede mentir ni necesita almacenamiento aparte.
  factory ProgresoEscucha.desdeMs(int milisegundos) {
    final horas = milisegundos <= 0 ? 0 : milisegundos ~/ 3600000;
    var indice = -1;
    for (var i = 0; i < nivelesEscucha.length; i++) {
      if (horas >= nivelesEscucha[i].horas) {
        indice = i;
      } else {
        break;
      }
    }
    final actual = indice >= 0 ? nivelesEscucha[indice] : nivelesEscucha.first;
    final siguiente =
        indice + 1 < nivelesEscucha.length ? nivelesEscucha[indice + 1] : null;
    if (siguiente == null) {
      return ProgresoEscucha(
        indice: indice,
        actual: actual,
        siguiente: null,
        avance: 1,
        horasFaltantes: 0,
      );
    }
    final base = indice >= 0 ? nivelesEscucha[indice].horas : 0;
    final tramo = siguiente.horas - base;
    final avance = tramo <= 0 ? 0.0 : ((horas - base) / tramo).clamp(0.0, 1.0);
    return ProgresoEscucha(
      indice: indice,
      actual: actual,
      siguiente: siguiente,
      avance: avance,
      horasFaltantes: (siguiente.horas - horas).clamp(0, siguiente.horas),
    );
  }
}
