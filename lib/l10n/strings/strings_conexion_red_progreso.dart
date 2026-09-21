// ─────────────────────────────────────────────────────────────
// strings_conexion_red_progreso.dart — Textos del AVANCE del traspaso entre
// aparatos: cuántas canciones van, cómo se cancela y qué queda dicho.
//
// Va aparte de strings_conexion_red.dart porque el avance y el vínculo son
// dos momentos distintos de la misma pantalla; se expone como
// `traspasoConexion`.
//
// Español primario, inglés secundario. Las frases con números se arman con
// [ingles], igual que el resto de la app.
// Se conecta con: app_localizations.dart + la fila de un aparato de la red.
// Parte del flujo: Ajustes → Conexión → traer lo descargado del otro aparato.
// ─────────────────────────────────────────────────────────────

class StringsTraspaso {
  /// true = textos en inglés (lo necesitan los parametrizados).
  final bool ingles;

  final String cancelar;
  final String alDia;

  const StringsTraspaso({
    required this.ingles,
    required this.cancelar,
    required this.alDia,
  });

  /// "Copiando 3 de 12…"
  String copiando(int hechas, int total) =>
      ingles ? 'Copying $hechas of $total…' : 'Copiando $hechas de $total…';

  /// Lo que queda dicho si el usuario cortó: las que llegaron son suyas.
  String cancelado(int copiadas) =>
      ingles
          ? 'Transfer stopped. $copiadas songs arrived and stayed.'
          : 'Traspaso cancelado. Las $copiadas canciones que llegaron quedaron.';

  /// Sin nada que traer.
  String get todoAlDia => alDia;

  static const es = StringsTraspaso(
    ingles: false,
    cancelar: 'Cancelar',
    alDia: 'Acá ya tenés todo lo que hay allá.',
  );

  static const en = StringsTraspaso(
    ingles: true,
    cancelar: 'Cancel',
    alDia: 'You already have everything that is over there.',
  );
}
