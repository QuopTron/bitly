// ─────────────────────────────────────────────────────────────
// strings_fechas.dart — Fechas relativas en lenguaje humano (hoy,
// ayer, hace N días/semanas/meses/año) y los meses cortos, para el
// detalle de Estadísticas. Español primario, inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `fechas`) y
// formato_escucha.dart (lo usa desde la capa de servicio).
// Parte del flujo: Ajustes → Estadísticas (detalle).
// ─────────────────────────────────────────────────────────────

class StringsFechas {
  final String hoy;
  final String ayer;
  final String haceUnaSemana;
  final String haceUnMes;
  final String haceUnAnio;
  final List<String> mesesCortos;
  final String _haceDias;
  final String _haceSemanas;
  final String _haceMeses;

  const StringsFechas({
    required this.hoy,
    required this.ayer,
    required this.haceUnaSemana,
    required this.haceUnMes,
    required this.haceUnAnio,
    required this.mesesCortos,
    required String haceDias,
    required String haceSemanas,
    required String haceMeses,
  }) : _haceDias = haceDias,
       _haceSemanas = haceSemanas,
       _haceMeses = haceMeses;

  /// "hace N días".
  String haceDias(int n) => _haceDias.replaceFirst('{n}', '$n');

  /// "hace N semanas".
  String haceSemanas(int n) => _haceSemanas.replaceFirst('{n}', '$n');

  /// "hace N meses".
  String haceMeses(int n) => _haceMeses.replaceFirst('{n}', '$n');

  /// Mes corto (1–12) para la fecha exacta.
  String mesCorto(int mes) => mesesCortos[mes - 1];

  static const es = StringsFechas(
    hoy: 'hoy',
    ayer: 'ayer',
    haceUnaSemana: 'hace 1 semana',
    haceUnMes: 'hace 1 mes',
    haceUnAnio: 'hace 1 año',
    mesesCortos: [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ],
    haceDias: 'hace {n} días',
    haceSemanas: 'hace {n} semanas',
    haceMeses: 'hace {n} meses',
  );

  static const en = StringsFechas(
    hoy: 'today',
    ayer: 'yesterday',
    haceUnaSemana: '1 week ago',
    haceUnMes: '1 month ago',
    haceUnAnio: '1 year ago',
    mesesCortos: [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ],
    haceDias: '{n} days ago',
    haceSemanas: '{n} weeks ago',
    haceMeses: '{n} months ago',
  );
}
