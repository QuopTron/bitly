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

  bool _sitios = true;
  bool _cargado = false;
  bool _abierto = false;
  bool _guardado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _instancia.dispose();
    _clave.dispose();
    super.dispose();
  }

  /// Lee lo guardado: los sitios solo se apagan a pedido, así que un valor
  /// vacío (o ausente) significa "encendidos".
  Future<void> _cargar() async {
    final cache = sl<CacheAjustes>();
    final sitios = await cache.getAjuste(
      '${AjustesRescate.idRescate}_${AjustesRescate.claveSitios}',
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
    if (!mounted) return;
    setState(() {
      _sitios = AjustesRescate.sitiosActivos(sitios);
      _instancia.text = url;
      _clave.text = clave;
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

  Future<void> _guardarCobalt() async {
    final url = AjustesRescate.normalizarInstancia(_instancia.text);
    // Una URL a medio pegar no se guarda: el campo ya lo está avisando.
    if (url.isNotEmpty && !AjustesRescate.instanciaValida(url)) return;
    await _servicio().guardarYReinicializar(AjustesRescate.idYoutube, {
      AjustesRescate.claveInstancia: url,
      AjustesRescate.claveToken: _clave.text.trim(),
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
      sitios: _sitios,
      abierto: _abierto,
      guardado: _guardado,
      glowColor: widget.glowColor,
      onSitios: _cambiarSitios,
      onToggleAvanzado: () => setState(() => _abierto = !_abierto),
      onGuardar: _guardarCobalt,
      onCampoCambiado: () => setState(() {}),
    );
  }
}
