// ─────────────────────────────────────────────────────────────
// settings_sheet_download_pool_qobuz.dart — PART de settings_sheet_new.dart:
// la tarjeta "Sesiones de Qobuz" de Ajustes → Descargas.
//
// Qué muestra: el ESTADO del pool de Qobuz, que el backend sabe calcular
// (endpoint caído vs. sin tokens vivos vs. con sesiones), en vez de dejar que
// la descarga directa se apague en silencio. Y deja pegar la URL del pool
// propio (una sola), que reemplaza al origen de fábrica.
//
// La URL viaja al backend con el mismo servicio que usa el resto de la app
// (persiste en la caché y empuja a Go), así que no hay guardado a mano. El
// árbol visual vive en settings_sheet_download_pool_qobuz_build.dart.
//
// Se conecta con: ajustes_pool_qobuz (claves/estado) + ServicioCredenciales-
// Proveedor (el push) + strings_pool_qobuz (los textos).
// Parte del flujo: Ajustes → Descargas → sesiones de Qobuz.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Estado del pool de Qobuz + la URL de la fuente que lo sirve.
class _DownloadPoolQobuzCard extends StatefulWidget {
  final Color glowColor;

  const _DownloadPoolQobuzCard({required this.glowColor});

  @override
  State<_DownloadPoolQobuzCard> createState() => _DownloadPoolQobuzCardState();
}

class _DownloadPoolQobuzCardState extends State<_DownloadPoolQobuzCard> {
  final TextEditingController _url = TextEditingController();

  String _estado = AjustesPoolQobuz.estadoConsultando;
  String _detalle = '';
  bool _cargado = false;
  bool _consultando = false;
  bool _guardado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  /// Lee la URL guardada (vacía = origen de fábrica) y consulta el estado.
  Future<void> _cargar() async {
    final cache = sl<CacheAjustes>();
    final url =
        await cache.getAjuste(
          '${AjustesPoolQobuz.id}_${AjustesPoolQobuz.claveUrls}',
        ) ??
        '';
    if (!mounted) return;
    setState(() {
      _url.text = url;
      _cargado = true;
    });
    await _consultar();
  }

  /// Pregunta al backend por qué el pool quedó como quedó. Nunca lanza: una
  /// respuesta rota se pinta como estado de error, no como un "todo bien".
  Future<void> _consultar() async {
    if (!mounted) return;
    setState(() => _consultando = true);
    final respuesta = await sl<BackendService>().invokeExtensionAction(
      AjustesPoolQobuz.id,
      AjustesPoolQobuz.accionEstado,
    );
    if (!mounted) return;
    setState(() {
      _estado = AjustesPoolQobuz.estadoDeRespuesta(respuesta);
      _detalle = AjustesPoolQobuz.detalleDeRespuesta(respuesta);
      _consultando = false;
    });
  }

  /// El mismo camino que usan las extensiones: guarda y empuja a Go. Después
  /// se vuelve a consultar, porque el estado depende de la URL recién puesta.
  Future<void> _guardar() async {
    final url = AjustesPoolQobuz.normalizarUrl(_url.text);
    if (url.isNotEmpty && !AjustesPoolQobuz.urlValida(url)) return;
    await ServicioCredencialesProveedor(
      sl<BackendService>(),
      sl<CacheAjustes>(),
    ).guardarYReinicializar(AjustesPoolQobuz.id, {
      AjustesPoolQobuz.claveUrls: url,
    });
    if (!mounted) return;
    setState(() => _guardado = true);
    await _consultar();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _guardado = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_cargado) return SizedBox.shrink();
    return _construirTarjetaPoolQobuz(
      context: context,
      url: _url,
      estado: _estado,
      detalle: _detalle,
      consultando: _consultando,
      guardado: _guardado,
      glowColor: widget.glowColor,
      onGuardar: _guardar,
      onRevisar: _consultar,
      onCampoCambiado: () => setState(() {}),
    );
  }
}
