// ─────────────────────────────────────────────────────────────
// formato_escucha.dart — Lógica PURA de formato del detalle de
// estadísticas: cómo se dice "cuándo fue la última vez" en lenguaje
// humano (hoy / ayer / hace 3 días / 12 sep 2026) y cómo se muestra el
// tiempo escuchado (min/h). Se puede testear sin UI ni base de datos.
//
// Los textos de fecha llegan por parámetro ([fechas]): si no se pasa,
// cae a español. Así sigue siendo pura y el idioma lo decide quien pinta.
// Se conecta con: settings_estadisticas_detalle_fila.dart (lo pinta y le
// pasa las unidades y las fechas localizadas de AppLocalizations).
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

import '../../../l10n/strings/comun/strings_fechas.dart';

/// Texto humano de la última reproducción de un ítem.
/// [desconocido] es lo que se muestra cuando la fila no trae fecha.
/// [fechas] aporta los textos relativos (hoy/ayer/hace N…); sin él, español.
String textoUltimaVez(
  DateTime? cuando, {
  DateTime? ahora,
  String desconocido = 'sin fecha',
  StringsFechas? fechas,
}) {
  if (cuando == null) return desconocido;
  final f = fechas ?? StringsFechas.es;
  final hoy = ahora ?? DateTime.now();
  final dias =
      DateTime(
        hoy.year,
        hoy.month,
        hoy.day,
      ).difference(DateTime(cuando.year, cuando.month, cuando.day)).inDays;

  if (dias <= 0) return f.hoy;
  if (dias == 1) return f.ayer;
  if (dias < 7) return f.haceDias(dias);
  if (dias < 14) return f.haceUnaSemana;
  if (dias < 31) return f.haceSemanas(dias ~/ 7);
  if (dias < 60) return f.haceUnMes;
  if (dias < 365) return f.haceMeses(dias ~/ 30);
  if (dias < 730) return f.haceUnAnio;
  // Más de dos años: la fecha exacta es más útil que "hace 3 años".
  return '${cuando.day} ${f.mesCorto(cuando.month)} ${cuando.year}';
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
