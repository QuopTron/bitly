// ─────────────────────────────────────────────────────────────
// strings_ajustes.dart — Textos del menú de Ajustes: las 7 burbujas
// (y su título en el riel lateral), la bajada de los apartados Cuenta y
// Proveedores, y las ayudas cortas de las tarjetas de Cuenta y Más
// (Google, caché, versiones, Premium y prueba gratis).
// Español primario, inglés secundario (se elige por el locale).
// Se conecta con: app_localizations.dart (lo expone como `ajustes`)
// y settings_sheet_entry.dart / settings_sheet_nav.dart.
// Parte del flujo: Ajustes (navegación entre pestañas).
// ─────────────────────────────────────────────────────────────

class StringsAjustes {
  final String apariencia;
  final String descargas;
  final String rendimiento;
  final String estadisticas;
  final String cuenta;
  final String proveedores;
  final String conexion;
  final String mas;
  final String cuentaAyuda;
  final String proveedoresAyuda;
  final String masAyuda;
  final String googleTitulo;
  final String googleAyuda;
  final String cacheTitulo;
  final String cacheAyuda;
  final String versiones;
  final String premiumCuentaTitulo;
  final String premiumActivoDesc;
  final String freeDesc;
  final String premiumActivo;
  final String planFree;
  final String trialExpirado;
  final String premiumBeneficios;
  final String premiumActivar;
  final String premiumActivarExpirado;

  /// Aviso del carrusel de ajustes: que se puede girar para ver el siguiente.
  final String girar;

  /// Plantilla del contador del carrusel: lleva %a (el que se está viendo) y
  /// %n (cuántos hay).
  final String _tplDeTotal;

  const StringsAjustes({
    required this.apariencia,
    required this.descargas,
    required this.rendimiento,
    required this.estadisticas,
    required this.cuenta,
    required this.proveedores,
    required this.conexion,
    required this.mas,
    required this.cuentaAyuda,
    required this.proveedoresAyuda,
    required this.masAyuda,
    required this.googleTitulo,
    required this.googleAyuda,
    required this.cacheTitulo,
    required this.cacheAyuda,
    required this.versiones,
    required this.premiumCuentaTitulo,
    required this.premiumActivoDesc,
    required this.freeDesc,
    required this.premiumActivo,
    required this.planFree,
    required this.trialExpirado,
    required this.premiumBeneficios,
    required this.premiumActivar,
    required this.premiumActivarExpirado,
    required this.girar,
    required String tplDeTotal,
  }) : _tplDeTotal = tplDeTotal;

  /// "2 de 8": en qué ajuste está y cuántos hay, para saber si falta girar.
  String deTotal(int actual, int total) =>
      _tplDeTotal.replaceFirst('%a', '$actual').replaceFirst('%n', '$total');

  /// Etiquetas en el MISMO orden que `_bubbleTabs`: el índice de la burbuja
  /// es el índice de esta lista y el de la pestaña.
  List<String> get pestanas => [
    apariencia,
    descargas,
    rendimiento,
    estadisticas,
    cuenta,
    proveedores,
    conexion,
    mas,
  ];

  /// Horas y minutos que le quedan a la prueba gratis, ya redactado.
  String trialRestante(int horas, int minutos, {required bool en}) =>
      en ? '${horas}h ${minutos}m left' : '${horas}h ${minutos}m restantes';

  /// Textos en español (idioma primario).
  static const es = StringsAjustes(
    apariencia: 'Apariencia',
    descargas: 'Descargas',
    rendimiento: 'Rendimiento',
    estadisticas: 'Estadísticas',
    cuenta: 'Cuenta',
    proveedores: 'Proveedores',
    conexion: 'Conexión',
    mas: 'Más',
    cuentaAyuda: 'Tu plan, la prueba y la conexión con Google.',
    proveedoresAyuda: 'De dónde sale la música: tu catálogo y tu biblioteca.',
    masAyuda: 'Reportar un problema, entender la caché y ver las versiones.',
    googleTitulo: 'Google',
    googleAyuda:
        'Conectá tu cuenta de Google para mejorar la calidad del streaming y el contenido personalizado.',
    cacheTitulo: 'Caché de streaming',
    cacheAyuda:
        'Guarda temporalmente las canciones que reproducís para que las que repetís suenen al instante y sin gastar datos.',
    versiones: 'Versiones',
    premiumCuentaTitulo: 'Cuenta',
    premiumActivoDesc: 'Tenés Premium: descargas ilimitadas para siempre.',
    freeDesc:
        'Modo Free: descargas gratis por 8 horas desde tu primera activación.',
    premiumActivo: 'Premium activo',
    planFree: 'Free',
    trialExpirado: 'Expirada',
    premiumBeneficios: 'Tu cuenta con todos los beneficios',
    premiumActivar: 'Tocá para activar un código premium',
    premiumActivarExpirado: 'Activá Premium para descargar sin límite',
    girar: 'Deslizá para girar',
    tplDeTotal: '%a de %n',
  );

  /// Textos en inglés.
  static const en = StringsAjustes(
    apariencia: 'Appearance',
    descargas: 'Downloads',
    rendimiento: 'Performance',
    estadisticas: 'Stats',
    cuenta: 'Account',
    proveedores: 'Sources',
    conexion: 'Connection',
    mas: 'More',
    cuentaAyuda: 'Your plan, the trial and the Google connection.',
    proveedoresAyuda: 'Where music comes from: catalog and your library.',
    masAyuda: 'Report a problem, understand the cache and see the versions.',
    googleTitulo: 'Google',
    googleAyuda:
        'Connect your Google account to improve streaming quality and personalized content.',
    cacheTitulo: 'Streaming cache',
    cacheAyuda:
        'Temporarily stores the songs you play so the ones you repeat start instantly and without using data.',
    versiones: 'Versions',
    premiumCuentaTitulo: 'Account',
    premiumActivoDesc: 'You have Premium: unlimited downloads forever.',
    freeDesc:
        'Free mode: free downloads for 8 hours after your first activation.',
    premiumActivo: 'Premium active',
    planFree: 'Free',
    trialExpirado: 'Expired',
    premiumBeneficios: 'Your account with every benefit',
    premiumActivar: 'Tap to activate a premium code',
    premiumActivarExpirado: 'Activate Premium to download without a limit',
    girar: 'Swipe to turn',
    tplDeTotal: '%a of %n',
  );
}
