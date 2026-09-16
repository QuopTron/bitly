// ─────────────────────────────────────────────────────────────
// formato_escucha.dart — Lógica PURA de formato del detalle de
// estadísticas: cómo se dice "cuándo fue la última vez" en lenguaje
// humano (hoy / ayer / hace 3 días / 12 sep 2026) y cómo se muestra el
// tiempo escuchado (min/h). Se puede testear sin UI ni base de datos.
// Se conecta con: settings_estadisticas_detalle_fila.dart (lo pinta y le
// pasa las unidades localizadas de AppLocalizations).
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

const List<String> _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Texto humano de la última reproducción de un ítem.
/// [desconocido] es lo que se muestra cuando la fila no trae fecha.
String textoUltimaVez(DateTime? cuando, {DateTime? ahora, String desconocido = 'sin fecha'}) {
  if (cuando == null) return desconocido;
  final hoy = ahora ?? DateTime.now();
  final dias = DateTime(hoy.year, hoy.month, hoy.day)
      .difference(DateTime(cuando.year, cuando.month, cuando.day))
      .inDays;

  if (dias <= 0) return 'hoy';
  if (dias == 1) return 'ayer';
  if (dias < 7) return 'hace $dias días';
  if (dias < 14) return 'hace 1 semana';
  if (dias < 31) return 'hace ${dias ~/ 7} semanas';
  if (dias < 60) return 'hace 1 mes';
  if (dias < 365) return 'hace ${dias ~/ 30} meses';
  if (dias < 730) return 'hace 1 año';
  // Más de dos años: la fecha exacta es más útil que "hace 3 años".
  return '${cuando.day} ${_mesesCortos[cuando.month - 1]} ${cuando.year}';
}

/// Texto del tiempo escuchado: minutos y, si pasa la hora, también horas.
/// [unidadMin] permite traducir la unidad ("min" en es/en) sin cambiar las
/// horas, que se abrevian igual en los dos idiomas.
String textoMinutos(int minutos, {String unidadMin = 'min'}) {
  if (minutos <= 0) return '';
  if (minutos < 60) return '$minutos $unidadMin';
  final horas = minutos ~/ 60;
  final resto = minutos % 60;
  return resto == 0 ? '$horas h' : '$horas h $resto $unidadMin';
}

/// Texto de un contador de reproducciones ("1 vez", "12 veces").
/// Singular/plural entran por parámetro para poder localizarlos.
String textoReproducciones(
  int veces, {
  String singular = 'vez',
  String plural = 'veces',
}) =>
    veces == 1 ? '1 $singular' : '$veces $plural';
