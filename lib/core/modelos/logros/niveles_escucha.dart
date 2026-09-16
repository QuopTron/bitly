// ─────────────────────────────────────────────────────────────
// niveles_escucha.dart — Escalera de NIVELES DE ESCUCHA y sus
// recompensas. Modelo puro (sin widgets ni I/O): recibe las horas
// escuchadas y devuelve el nivel actual, el progreso y qué premios
// quedan por descubrir.
//
// Por qué existe: los logros no pueden quedarse en "100 canciones".
// La escalera está armada para que el último nivel exija ~35.000 horas
// de escucha real, o sea escuchar 24 horas por día durante MÁS DE 4
// AÑOS: siempre hay algo por delante, y los premios son cosméticos o de
// función dentro de la app (nunca dinero ni nada que dependa de un
// tercero que pueda caerse).
//
// Los premios NO se muestran hasta que se desbloquean: el nivel
// siguiente aparece como "???" con su umbral, y al alcanzarlo se revela
// el nombre del premio. Es lo que hace que el siguiente nivel valga la
// pena.
//
// Se conecta con: settings_estadisticas_niveles.dart (lo pinta en la
// pestaña Estadísticas de Ajustes).
// Parte del flujo: Ajustes → Estadísticas (niveles y recompensas).
// ─────────────────────────────────────────────────────────────

/// Un nivel de la escalera: umbral de horas y recompensa que se revela
/// al alcanzarlo.
class NivelEscucha {
  /// Nombre visible del nivel.
  final String nombre;

  /// Horas de escucha acumuladas necesarias para llegar.
  final int horas;

  /// Recompensa (oculta hasta desbloquearla).
  final String premio;

  const NivelEscucha({
    required this.nombre,
    required this.horas,
    required this.premio,
  });
}

/// Escalera completa. Los umbrales van en progresión suave al principio
/// (para que el primer premio llegue pronto) y se estiran después.
const List<NivelEscucha> nivelesEscucha = [
  NivelEscucha(
    nombre: 'Primer tema',
    horas: 1,
    premio: 'Marco de perfil en tono del tema que más escuchaste',
  ),
  NivelEscucha(
    nombre: 'Oyente',
    horas: 10,
    premio: 'Etiqueta "Oyente" junto a tu nombre al compartir',
  ),
  NivelEscucha(
    nombre: 'De madrugada',
    horas: 50,
    premio: 'Tema oscuro extra para el reproductor (medianoche)',
  ),
  NivelEscucha(
    nombre: 'Coleccionista',
    horas: 150,
    premio: 'Cola de 200 temas en vez de 100',
  ),
  NivelEscucha(
    nombre: 'Curado',
    horas: 400,
    premio: 'Filtro "solo sin pérdida" en todas las búsquedas',
  ),
  NivelEscucha(
    nombre: 'Fiel',
    horas: 1_000,
    premio: 'Tus 10 temas más escuchados en un álbum automático',
  ),
  NivelEscucha(
    nombre: 'Incansable',
    horas: 2_500,
    premio: 'Descargas en paralelo dobles (más rápido)',
  ),
  NivelEscucha(
    nombre: 'Maestro de sesión',
    horas: 5_000,
    premio: 'Etiqueta dorada en las tarjetas que compartís',
  ),
  NivelEscucha(
    nombre: 'Archivo vivo',
    horas: 8_000,
    premio: 'Respaldo de tu biblioteca en un archivo propio',
  ),
  NivelEscucha(
    nombre: 'Un año sin parar',
    horas: 8_760,
    premio: 'Insignia "365×24" y fondo animado exclusivo',
  ),
  NivelEscucha(
    nombre: 'Dos años',
    horas: 17_520,
    premio: 'Tu historial completo exportable por año',
  ),
  NivelEscucha(
    nombre: 'Tres años',
    horas: 26_280,
    premio: 'Tema visual completo hecho a mano (uno de tres)',
  ),
  NivelEscucha(
    nombre: 'Cuatro años non-stop',
    horas: 35_040,
    premio: 'Insignia definitiva: "Escuchó cuatro años sin cortar"',
  ),
];
