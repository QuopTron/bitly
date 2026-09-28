// ─────────────────────────────────────────────────────────────
// fuente_app.dart — Modelo de una TIPOGRAFÍA de la app (Ajustes →
// Apariencia → Tipografía).
//
// Modelo puro: sin widgets, sin I/O y sin red. Acá sólo se describe la fuente;
// bajarla y registrarla es trabajo de servicio_fuentes.dart.
//
// Igual que en el cofre de las barras, esta app trae UNA de fábrica y las demás
// se consiguen usándola:
//   libre   → ya está (la empaquetada o las que se regalan)
//   horas   → por horas de escucha acumuladas (misma escalera que los niveles)
//   version → llega con una versión concreta de la app
//
// Los NOMBRES que ve el usuario no viven acá: son texto localizado, como en el
// cofre. Este archivo sólo sabe de familias, URLs y condiciones.
//
// Se conecta con: catalogo_fuentes.dart (la lista, que resuelve cuándo se abre
// cada una) + servicio_fuentes.dart (bajarla y registrarla) +
// preferencias_apariencia.dart (cuál está elegida).
// Parte del flujo: Ajustes → Apariencia → Tipografía.
// ─────────────────────────────────────────────────────────────

/// Cómo se consigue una tipografía.
enum DesbloqueoFuente {
  /// Ya disponible (la empaquetada, o una que la app regala).
  libre('libre'),

  /// Por horas de escucha acumuladas.
  horas('horas'),

  /// Llega con una versión de la app.
  version('version');

  final String clave;

  const DesbloqueoFuente(this.clave);
}

/// Una tipografía que la app puede usar.
class FuenteApp {
  /// Identificador estable. Se guarda en las preferencias, viaja al backend y
  /// es el nombre del archivo en disco (el backend lo valida por eso).
  final String id;

  /// Familia con la que Flutter la registra.
  ///
  /// La empaquetada es EXACTAMENTE la que declara pubspec.yaml; las bajadas se
  /// registran al vuelo con este nombre.
  final String familia;

  /// De dónde bajarla. '' = viene empaquetada en la app.
  final String url;

  /// Huella esperada del archivo. '' = no se verifica (el backend igual valida
  /// la firma sfnt, que es lo que descarta una página de error guardada como
  /// si fuera una tipografía).
  final String sha256;

  /// Cómo se consigue.
  final DesbloqueoFuente desbloqueo;

  /// Horas de escucha requeridas (si [desbloqueo] es `horas`) o versión en
  /// número (si es `version`, ver versionEnNumero).
  final int valor;

  const FuenteApp({
    required this.id,
    required this.familia,
    this.url = '',
    this.sha256 = '',
    this.desbloqueo = DesbloqueoFuente.libre,
    this.valor = 0,
  });

  /// ¿Viene con la app? Entonces funciona sin red y sin descargar nada.
  bool get empaquetada => url.isEmpty;

  /// ¿Hay que bajarla del espejo?
  bool get descargable => !empaquetada;
}
