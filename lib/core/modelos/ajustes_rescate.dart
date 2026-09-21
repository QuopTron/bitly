// ─────────────────────────────────────────────────────────────
// ajustes_rescate.dart — Valores de los ajustes del RESCATE de audio y su
// traducción a lo que espera el backend de Go.
//
// Qué resuelve: el switch de sitios raspables de FLAC y la instancia propia de
// cobalt se guardan como TEXTO en la caché (`flac-rescue_sitios`,
// `youtube_cobalt`, `youtube_cobalt_token`) porque así viajan al backend. Acá
// vive la traducción, para que la UI no escriba strings sueltos y para poder
// probarla sin levantar un widget.
//
// Los valores de apagado son los mismos que entiende Go (ver
// sitios_flac_ajustes.go y cobalt.go): "off", "0", "no", "false", "apagado".
//
// Se conecta con: cache_ajustes (guardado) + settings_sheet_download_rescate
// (la tarjeta de Ajustes) + servicio_credenciales_proveedor (el push a Go).
// Parte del flujo: Ajustes → Descargas → rescate sin pérdida.
// ─────────────────────────────────────────────────────────────

/// Ajustes del rescate de audio: sitios raspables de FLAC e instancia de
/// cobalt (respaldo de descarga del audio de YouTube).
class AjustesRescate {
  /// Valores que el backend interpreta como "apagado".
  static const Set<String> apagados = {'off', '0', 'no', 'false', 'apagado'};

  static const String claveSitios = 'sitios';
  static const String claveInstancia = 'cobalt';
  static const String claveToken = 'cobalt_token';

  /// El texto con el que se apaga un ajuste.
  static const String valorApagado = 'off';

  /// El id de extensión del canal de sitios (provider nativo de Go).
  static const String idRescate = 'flac-rescue';

  /// El id del provider de YouTube, que es quien tiene el respaldo cobalt.
  static const String idYoutube = 'youtube';

  /// ¿Los sitios raspables están encendidos? Un valor vacío significa "de
  /// fábrica", y de fábrica vienen encendidos: el ajuste solo se guarda
  /// cuando el usuario los apaga.
  static bool sitiosActivos(String? valor) =>
      !apagados.contains((valor ?? '').trim().toLowerCase());

  /// El valor a guardar según el switch.
  static String valorSitios(bool activos) => activos ? '' : valorApagado;

  /// La URL de la instancia sin barras finales: es como la espera Go al
  /// armar `base + "/"`.
  static String normalizarInstancia(String url) =>
      url.trim().replaceAll(RegExp(r'/+$'), '');

  /// ¿Es una URL http(s) con host? Una basura pegada no puede encender el
  /// respaldo (y el campo avisa antes de guardar).
  static bool instanciaValida(String url) {
    final limpia = normalizarInstancia(url);
    if (limpia.isEmpty) return false;
    final uri = Uri.tryParse(limpia);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// ¿Hay una instancia propia configurada? (Sin ella el respaldo no se usa
  /// y no abre ninguna conexión.)
  static bool cobaltActivo(String? url) => instanciaValida(url ?? '');
}
