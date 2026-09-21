// ─────────────────────────────────────────────────────────────
// strings_actualizacion.dart — Textos de la actualización y las
// versiones (Ajustes → Más): cabecera, progreso, estado instalada/
// última y el botón Descargar. Español primario, inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `update`) y
// update_sheet_bloques / settings_sheet_version_*.
// Parte del flujo: Ajustes (versiones y actualización).
// ─────────────────────────────────────────────────────────────

class StringsActualizacion {
  final String descargando;
  final String disponible;
  final String preparando;
  final String instalada;
  final String ultima;
  final String descargar;
  final String _versionActual;

  const StringsActualizacion({
    required this.descargando,
    required this.disponible,
    required this.preparando,
    required this.instalada,
    required this.ultima,
    required this.descargar,
    required String versionActual,
  }) : _versionActual = versionActual;

  /// Línea "Versión actual: X".
  String versionActual(String v) => _versionActual.replaceFirst('{v}', v);

  static const es = StringsActualizacion(
    descargando: 'Descargando actualización...',
    disponible: 'Hay una nueva actualización',
    preparando: 'Preparando...',
    instalada: 'Instalada',
    ultima: 'Última',
    descargar: 'Descargar',
    versionActual: 'Versión actual: {v}',
  );

  static const en = StringsActualizacion(
    descargando: 'Downloading update...',
    disponible: 'A new update is available',
    preparando: 'Preparing...',
    instalada: 'Installed',
    ultima: 'Latest',
    descargar: 'Download',
    versionActual: 'Current version: {v}',
  );
}
