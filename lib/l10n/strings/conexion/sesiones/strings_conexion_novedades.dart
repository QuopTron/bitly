// ─────────────────────────────────────────────────────────────
// strings_conexion_novedades.dart — Textos del AVISO de novedades de la
// burbuja CONEXIÓN: el regalo de la prueba y los aparatos sin vincular.
//
// Va aparte de strings_conexion.dart para que cada archivo de textos quede
// chico y con una sola idea; se expone como `novedadesConexion`.
//
// Español primario, inglés secundario (se elige por el locale). El texto que
// lleva un nombre adentro se arma con [ingles], igual que las otras frases
// parametrizadas de la app.
// Se conecta con: app_localizations.dart + el aviso de la pestaña Conexión.
// Parte del flujo: Ajustes → Conexión (novedades).
// ─────────────────────────────────────────────────────────────

class StringsConexionNovedades {
  /// true = textos en inglés (los parametrizados lo necesitan).
  final bool ingles;

  final String titulo;

  /// El regalo: la prueba de 9 horas disponible y sin usar.
  final String prueba;

  const StringsConexionNovedades({
    required this.ingles,
    required this.titulo,
    required this.prueba,
  });

  /// "«TV del cuarto» está sin vincular: cuenta cuando se conecte."
  String aparatoPendiente(String nombre) =>
      ingles
          ? '“$nombre” is not linked yet: it counts once it connects.'
          : '«$nombre» está sin vincular: cuenta cuando se conecte.';

  static const es = StringsConexionNovedades(
    ingles: false,
    titulo: 'Novedades',
    prueba: 'Tenés un regalo: la prueba de 9 horas de la conexión multi.',
  );

  static const en = StringsConexionNovedades(
    ingles: true,
    titulo: 'What is new',
    prueba: 'You have a gift: the 9-hour multi-connection trial.',
  );
}
