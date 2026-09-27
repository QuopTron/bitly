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

  // ── Descarga en segundo plano (ver actualizacion_servicio.dart) ──
  //
  // `notificacion*`, `toca*`, `canal*` viajan a la notificación de Android,
  // que la dibuja el sistema: por eso son palabras sueltas y cortas.
  final String notificacionLista;
  final String notificacionFallo;
  final String tocaInstalar;
  final String tocaReintentar;
  final String canal;
  final String canalDescripcion;
  final String cancelar;
  final String instalar;
  final String descargarDeNuevo;
  final String ahoraNo;
  final String enSegundoPlano;
  final String instalalaCuandoQuieras;
  final String _limpiarAntiguas;
  final String _limpiezaHecha;
  final String _nuevaVersion;

  const StringsActualizacion({
    required this.descargando,
    required this.disponible,
    required this.preparando,
    required this.instalada,
    required this.ultima,
    required this.descargar,
    required this.notificacionLista,
    required this.notificacionFallo,
    required this.tocaInstalar,
    required this.tocaReintentar,
    required this.canal,
    required this.canalDescripcion,
    required this.cancelar,
    required this.instalar,
    required this.descargarDeNuevo,
    required this.ahoraNo,
    required this.enSegundoPlano,
    required this.instalalaCuandoQuieras,
    required String limpiarAntiguas,
    required String limpiezaHecha,
    required String nuevaVersion,
    required String versionActual,
  }) : _limpiarAntiguas = limpiarAntiguas,
       _limpiezaHecha = limpiezaHecha,
       _nuevaVersion = nuevaVersion,
       _versionActual = versionActual;

  /// Línea "Versión actual: X".
  String versionActual(String v) => _versionActual.replaceFirst('{v}', v);

  /// Botón que borra los APKs de versiones viejas.
  String get limpiarAntiguas => _limpiarAntiguas;

  /// Aviso "Se borraron N archivos".
  String limpiezaHecha(int n) => _limpiezaHecha.replaceFirst('{n}', '$n');

  /// Cuerpo de la notificación "Bitly X ya está disponible".
  String nuevaVersion(String v) => _nuevaVersion.replaceFirst('{v}', v);

  static const es = StringsActualizacion(
    descargando: 'Descargando actualización...',
    disponible: 'Hay una nueva actualización',
    preparando: 'Preparando...',
    instalada: 'Instalada',
    ultima: 'Última',
    descargar: 'Descargar',
    notificacionLista: 'Actualización lista',
    notificacionFallo: 'No se pudo descargar la actualización',
    tocaInstalar: 'tocá para instalar',
    tocaReintentar: 'tocá para reintentar',
    canal: 'Actualizaciones',
    canalDescripcion: 'Descargas de versiones nuevas de la app',
    cancelar: 'Cancelar',
    instalar: 'Instalar',
    descargarDeNuevo: 'Descargar de nuevo',
    ahoraNo: 'Ahora no',
    enSegundoPlano: 'Se descarga en segundo plano',
    instalalaCuandoQuieras: 'Podés instalarla cuando quieras',
    limpiarAntiguas: 'Borrar versiones anteriores',
    limpiezaHecha: 'Se borraron {n} archivos',
    nuevaVersion: 'Bitly {v} ya está disponible',
    versionActual: 'Versión actual: {v}',
  );

  static const en = StringsActualizacion(
    descargando: 'Downloading update...',
    disponible: 'A new update is available',
    preparando: 'Preparing...',
    instalada: 'Installed',
    ultima: 'Latest',
    descargar: 'Download',
    notificacionLista: 'Update ready',
    notificacionFallo: 'Could not download the update',
    tocaInstalar: 'tap to install',
    tocaReintentar: 'tap to retry',
    canal: 'Updates',
    canalDescripcion: 'Downloads of new app versions',
    cancelar: 'Cancel',
    instalar: 'Install',
    descargarDeNuevo: 'Download again',
    ahoraNo: 'Not now',
    enSegundoPlano: 'Downloads in the background',
    instalalaCuandoQuieras: 'You can install it whenever you want',
    limpiarAntiguas: 'Delete older versions',
    limpiezaHecha: 'Removed {n} files',
    nuevaVersion: 'Bitly {v} is available',
    versionActual: 'Current version: {v}',
  );
}
