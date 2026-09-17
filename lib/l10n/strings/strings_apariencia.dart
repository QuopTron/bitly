// ─────────────────────────────────────────────────────────────
// strings_apariencia.dart — Textos del bloque "Diseño" de Ajustes →
// Apariencia: borde del reproductor, separación de las grillas y
// redondeo de las cards, con la vista previa.
// Español primario, inglés secundario (se elige por el locale).
// Se conecta con: app_localizations.dart (lo expone como `apariencia`)
// y settings_sheet_appearance_diseno.dart.
// Parte del flujo: Ajustes → Apariencia (diseño personalizable).
// ─────────────────────────────────────────────────────────────

class StringsApariencia {
  final String disenoTitulo;
  final String disenoAyuda;
  final String bordeTitulo;
  final String bordeSin;
  final String bordeSuave;
  final String bordeMarcado;
  final String separacionTitulo;
  final String separacionAyuda;
  final String separacionX;
  final String separacionY;
  final String radioTitulo;
  final String vistaPreviaTitulo;
  final String vistaPreviaAyuda;
  final String restablecer;

  const StringsApariencia({
    required this.disenoTitulo,
    required this.disenoAyuda,
    required this.bordeTitulo,
    required this.bordeSin,
    required this.bordeSuave,
    required this.bordeMarcado,
    required this.separacionTitulo,
    required this.separacionAyuda,
    required this.separacionX,
    required this.separacionY,
    required this.radioTitulo,
    required this.vistaPreviaTitulo,
    required this.vistaPreviaAyuda,
    required this.restablecer,
  });

  /// Textos en español (idioma primario).
  static const es = StringsApariencia(
    disenoTitulo: 'Diseño',
    disenoAyuda: 'Ajustá el borde del reproductor y cómo se acomodan las cards.',
    bordeTitulo: 'Borde del reproductor',
    bordeSin: 'Sin borde',
    bordeSuave: 'Suave',
    bordeMarcado: 'Marcado',
    separacionTitulo: 'Separación de las cards',
    separacionAyuda: 'Con 0 quedan pegadas; el diseño de la app es 1.',
    separacionX: 'Horizontal',
    separacionY: 'Vertical',
    radioTitulo: 'Redondeo de las cards',
    vistaPreviaTitulo: 'Vista previa',
    vistaPreviaAyuda: 'Así se ven tu reproductor y tus cards ahora.',
    restablecer: 'Volver al diseño original',
  );

  /// Textos en inglés.
  static const en = StringsApariencia(
    disenoTitulo: 'Design',
    disenoAyuda: 'Tune the player border and how cards are laid out.',
    bordeTitulo: 'Player border',
    bordeSin: 'No border',
    bordeSuave: 'Soft',
    bordeMarcado: 'Bold',
    separacionTitulo: 'Card spacing',
    separacionAyuda: '0 means touching; the app design is 1.',
    separacionX: 'Horizontal',
    separacionY: 'Vertical',
    radioTitulo: 'Card roundness',
    vistaPreviaTitulo: 'Preview',
    vistaPreviaAyuda: 'This is how your player and cards look now.',
    restablecer: 'Back to the original design',
  );
}
