// ─────────────────────────────────────────────────────────────
// strings_cache.dart — Textos de la caché de streaming (Ajustes →
// Rendimiento): cabecera y botón Limpiar, confirmación, estadísticas
// y límite de tamaño. Español primario, inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `cache`) y
// settings_cache_section / _bloques / _stats / _selector.
// Parte del flujo: Ajustes (caché de streaming).
// ─────────────────────────────────────────────────────────────

class StringsCache {
  final String titulo;
  final String limpiar;
  final String limpiarTitulo;
  final String cancelar;
  final String limpiado;
  final String cargando;
  final String noDisponible;
  final String usados;
  final String enCache;
  final String deAudio;
  final String limiteTitulo;
  final String limitePlan;
  final String max;
  final String _limpiarCuerpo;
  final String _planPermite;
  final String _archivos;

  const StringsCache({
    required this.titulo,
    required this.limpiar,
    required this.limpiarTitulo,
    required this.cancelar,
    required this.limpiado,
    required this.cargando,
    required this.noDisponible,
    required this.usados,
    required this.enCache,
    required this.deAudio,
    required this.limiteTitulo,
    required this.limitePlan,
    required this.max,
    required String limpiarCuerpo,
    required String planPermite,
    required String archivos,
  }) : _limpiarCuerpo = limpiarCuerpo,
       _planPermite = planPermite,
       _archivos = archivos;

  /// Cuerpo de la confirmación con el tamaño ya formateado.
  String limpiarCuerpo(String tamano) =>
      _limpiarCuerpo.replaceFirst('{tamano}', tamano);

  /// Aviso del límite del plan con MB y nivel de cuenta.
  String planPermite(String mb, String nivel) =>
      _planPermite.replaceFirst('{mb}', mb).replaceFirst('{nivel}', nivel);

  /// Cantidad de archivos cacheados.
  String archivos(int n) => _archivos.replaceFirst('{n}', '$n');

  static const es = StringsCache(
    titulo: 'Caché de streaming',
    limpiar: 'Limpiar',
    limpiarTitulo: 'Limpiar caché',
    cancelar: 'Cancelar',
    limpiado: 'Caché de streaming limpiado',
    cargando: 'Cargando...',
    noDisponible: 'Caché no disponible',
    usados: 'usados',
    enCache: 'en caché',
    deAudio: 'de audio cacheados',
    limiteTitulo: 'Límite de tamaño',
    limitePlan: 'límite del plan',
    max: 'máx',
    limpiarCuerpo:
        'Se borrarán los archivos temporales de streaming.\n\n'
        '{tamano} serán liberados.',
    planPermite: 'Tu plan permite hasta {mb} MB ({nivel})',
    archivos: '{n} archivos',
  );

  static const en = StringsCache(
    titulo: 'Streaming cache',
    limpiar: 'Clean',
    limpiarTitulo: 'Clear cache',
    cancelar: 'Cancel',
    limpiado: 'Streaming cache cleared',
    cargando: 'Loading...',
    noDisponible: 'Cache not available',
    usados: 'used',
    enCache: 'cached',
    deAudio: 'of cached audio',
    limiteTitulo: 'Size limit',
    limitePlan: 'plan limit',
    max: 'max',
    limpiarCuerpo:
        'Temporary streaming files will be deleted.\n\n'
        '{tamano} will be freed.',
    planPermite: 'Your plan allows up to {mb} MB ({nivel})',
    archivos: '{n} files',
  );
}
