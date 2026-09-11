// ─────────────────────────────────────────────────────────────
// strings_red.dart — Textos del indicador global de red (barra
// superior) y de su hoja de detalle: nivel de calidad, tipo de
// conexión, latencia y fuentes activas. Español primario, inglés
// secundario (se elige por el locale de la app).
// Se conecta con: app_localizations.dart (lo expone como `red`) +
// shared/widgets/indicador_red.dart.
// Parte del flujo: Home → barra superior (monitoreo de conexión).
// ─────────────────────────────────────────────────────────────

class StringsRed {
  final String title;
  final String measuring;
  final String offline;
  final String excellent;
  final String good;
  final String fair;
  final String poor;
  final String typeWifi;
  final String typeMobile;
  final String typeEthernet;
  final String typeOther;
  final String typeNone;
  final String latencyLabel;
  final String sourcesLabel;
  final String unavailable;
  final String detailHint;
  final String a11yOpen;

  const StringsRed({
    required this.title,
    required this.measuring,
    required this.offline,
    required this.excellent,
    required this.good,
    required this.fair,
    required this.poor,
    required this.typeWifi,
    required this.typeMobile,
    required this.typeEthernet,
    required this.typeOther,
    required this.typeNone,
    required this.latencyLabel,
    required this.sourcesLabel,
    required this.unavailable,
    required this.detailHint,
    required this.a11yOpen,
  });

  static const es = StringsRed(
    title: 'Estado de la red',
    measuring: 'Midiendo…',
    offline: 'Sin conexión',
    excellent: 'Excelente',
    good: 'Buena',
    fair: 'Regular',
    poor: 'Lenta',
    typeWifi: 'WiFi',
    typeMobile: 'Datos móviles',
    typeEthernet: 'Ethernet',
    typeOther: 'Otra red',
    typeNone: 'Sin red',
    latencyLabel: 'Latencia',
    sourcesLabel: 'Fuentes activas',
    unavailable: 'no disponible',
    detailHint: 'Se mide cada 15 segundos mientras la app está abierta.',
    a11yOpen: 'Ver el estado de la red',
  );

  static const en = StringsRed(
    title: 'Network status',
    measuring: 'Measuring…',
    offline: 'Offline',
    excellent: 'Excellent',
    good: 'Good',
    fair: 'Fair',
    poor: 'Slow',
    typeWifi: 'WiFi',
    typeMobile: 'Mobile data',
    typeEthernet: 'Ethernet',
    typeOther: 'Other network',
    typeNone: 'No network',
    latencyLabel: 'Latency',
    sourcesLabel: 'Active sources',
    unavailable: 'unavailable',
    detailHint: 'Measured every 15 seconds while the app is open.',
    a11yOpen: 'See network status',
  );
}
