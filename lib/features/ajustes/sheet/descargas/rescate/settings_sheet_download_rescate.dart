// ─────────────────────────────────────────────────────────────
// settings_sheet_download_rescate.dart — PART de settings_sheet_new.dart: la
// tarjeta "Rescate sin pérdida" de Ajustes → Descargas.
//
// Qué deja tocar:
//   · el switch de SITIOS raspables de FLAC (superflac/arcod y compañía):
//     apagados, el rescate queda solo con los espejos y las claves firmadas;
//   · en "Avanzado", la instancia propia de COBALT y su clave, que es una
//     segunda vía de descarga del audio de YouTube cuando yt-dlp falla.
//
// Los dos ajustes viajan al backend con el mismo servicio que usa el resto de
// la app (persiste en la caché y empuja a Go), así que no hay guardado a mano
// ni pantalla de credenciales de por medio. El árbol visual vive en
// settings_sheet_download_rescate_build.dart.
//
// Se conecta con: ajustes_rescate (los valores) + servicio_credenciales_
// proveedor (el push) + strings_rescate (los textos).
// Parte del flujo: Ajustes → Descargas → rescate.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Rescate de audio: sitios raspables de FLAC e instancia propia de cobalt.
class _DownloadRescateCard extends StatefulWidget {
  final Color glowColor;

  const _DownloadRescateCard({required this.glowColor});

  @override
  State<_DownloadRescateCard> createState() => _DownloadRescateCardState();
}

class _DownloadRescateCardState extends State<_DownloadRescateCard> {
  final TextEditingController _instancia = TextEditingController();
  final TextEditingController _clave = TextEditingController();
  final TextEditingController _proxy = TextEditingController();

  bool _sitios = true;
  bool _relay = true;
  bool _espejos = true;
  bool _arcod = true;
  bool _cargado = false;
  bool _abierto = false;
  bool _guardado = false;

  // Informe de canales (acción probarCanales). No sale a la red: refleja lo
  // que cada canal ya publicó.
  List<CanalRescate> _canales = const [];
  String _detalleCanales = '';
  bool _agotado = false;
  bool _consultandoCanales = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _instancia.dispose();
    _clave.dispose();
    _proxy.dispose();
    super.dispose();
  }

  /// Lee lo guardado: los sitios solo se apagan a pedido, así que un valor
  /// vacío (o ausente) significa "encendidos".
  Future<void> _cargar() async {
    final cache = sl<CacheAjustes>();
    final sitios = await cache.getAjuste(
      '${AjustesRescate.idRescate}_${AjustesRescate.claveSitios}',
    );
    final relay = await cache.getAjuste(
      '${AjustesRescate.idRescate}_${AjustesRescate.claveStashRelay}',
    );
    final espejos = await cache.getAjuste(
      '${AjustesRescate.idRescate}_${AjustesRescate.claveEspejos}',
    );
    final arcod = await cache.getAjuste(
      '${AjustesRescate.idRescate}_${AjustesRescate.claveArcod}',
    );
    final url =
        await cache.getAjuste(
          '${AjustesRescate.idYoutube}_${AjustesRescate.claveInstancia}',
        ) ??
        '';
    final clave =
        await cache.getAjuste(
          '${AjustesRescate.idYoutube}_${AjustesRescate.claveToken}',
        ) ??
        '';
    final proxy =
        await cache.getAjuste(
          '${AjustesRescate.idRescate}_${AjustesRescate.claveProxy}',
        ) ??
        '';
    if (!mounted) return;
    setState(() {
      _sitios = AjustesRescate.sitiosActivos(sitios);
      _relay = AjustesRescate.relayActivo(relay);
      _espejos = AjustesRescate.espejosActivos(espejos);
      _arcod = AjustesRescate.arcodActivo(arcod);
      _instancia.text = url;
      _clave.text = clave;
      _proxy.text = proxy;
      _cargado = true;
    });
  }

  /// El mismo camino que usan las extensiones: guarda y empuja a Go.
  ServicioCredencialesProveedor _servicio() =>
      ServicioCredencialesProveedor(sl<BackendService>(), sl<CacheAjustes>());

  Future<void> _cambiarSitios(bool activos) async {
    setState(() => _sitios = activos);
    await _servicio().guardarYReinicializar(AjustesRescate.idRescate, {
      AjustesRescate.claveSitios: AjustesRescate.valorSitios(activos),
    });
  }

  /// El relay sin pérdida: mismo camino que los sitios. Apagado, el backend no
  /// le hace ni una petición (ver stash_relay_ajustes.go).
  Future<void> _cambiarRelay(bool activo) async {
    setState(() => _relay = activo);
    await _servicio().guardarYReinicializar(AjustesRescate.idRescate, {
      AjustesRescate.claveStashRelay: AjustesRescate.valorRelay(activo),
    });
  }

  /// Los espejos por ISRC: apagados no se les hace ni una petición. Es el
  /// interruptor para los espejos públicos que quedaron sin ARLs vivos.
  Future<void> _cambiarEspejos(bool activos) async {
    setState(() => _espejos = activos);
    await _servicio().guardarYReinicializar(AjustesRescate.idRescate, {
      AjustesRescate.claveEspejos: AjustesRescate.valorEspejos(activos),
    });
  }

  /// El canal arcod: apagado no se le hace ni una petición.
  Future<void> _cambiarArcod(bool activo) async {
    setState(() => _arcod = activo);
    await _servicio().guardarYReinicializar(AjustesRescate.idRescate, {
      AjustesRescate.claveArcod: AjustesRescate.valorArcod(activo),
    });
  }

  /// Pide el informe de canales. Nunca lanza: una respuesta rota queda como
  /// lista vacía (no miente con un "todo bien").
  Future<void> _probarCanales() async {
    if (!mounted) return;
    setState(() => _consultandoCanales = true);
    Map<String, dynamic>? respuesta;
    try {
      respuesta = await sl<BackendService>().invokeExtensionAction(
        AjustesRescate.idRescate,
        DiagnosticoCanalesRescate.accion,
      );
    } catch (_) {
      respuesta = null;
    }
    if (!mounted) return;
    setState(() {
      _canales = DiagnosticoCanalesRescate.canalesDeRespuesta(respuesta);
      _detalleCanales = DiagnosticoCanalesRescate.detalleDeRespuesta(respuesta);
      _agotado = DiagnosticoCanalesRescate.agotadoDeRespuesta(respuesta);
      _consultandoCanales = false;
    });
  }

  /// Guarda la sección avanzada: la instancia de cobalt (youtube) y el proxy
  /// del rescate (flac-rescue) en un solo toque de Guardar.
  Future<void> _guardarAvanzado() async {
    final url = AjustesRescate.normalizarInstancia(_instancia.text);
    // Una URL a medio pegar no se guarda: el campo ya lo está avisando.
    if (url.isNotEmpty && !AjustesRescate.instanciaValida(url)) return;
    final proxy = AjustesRescate.normalizarProxy(_proxy.text);
    if (proxy.isNotEmpty && !AjustesRescate.proxyValido(proxy)) return;
    await _servicio().guardarYReinicializar(AjustesRescate.idYoutube, {
      AjustesRescate.claveInstancia: url,
      AjustesRescate.claveToken: _clave.text.trim(),
    });
    await _servicio().guardarYReinicializar(AjustesRescate.idRescate, {
      AjustesRescate.claveProxy: proxy,
    });
    if (!mounted) return;
    setState(() => _guardado = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _guardado = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_cargado) return SizedBox.shrink();
    return _construirTarjetaRescate(
      context: context,
      instancia: _instancia,
      clave: _clave,
      proxy: _proxy,
      sitios: _sitios,
      relay: _relay,
      espejos: _espejos,
      arcod: _arcod,
      canales: _canales,
      detalleCanales: _detalleCanales,
      agotado: _agotado,
      consultandoCanales: _consultandoCanales,
      abierto: _abierto,
      guardado: _guardado,
      glowColor: widget.glowColor,
      onSitios: _cambiarSitios,
      onRelay: _cambiarRelay,
      onEspejos: _cambiarEspejos,
      onArcod: _cambiarArcod,
      onProbarCanales: _probarCanales,
      onToggleAvanzado: () => setState(() => _abierto = !_abierto),
      onGuardar: _guardarAvanzado,
      onCampoCambiado: () => setState(() {}),
    );
  }
}
