// ─────────────────────────────────────────────────────────────
// hoja_opciones_descarga_estado.dart — PART de
// hoja_opciones_descarga.dart: el State de la hoja — carga los
// tamaños estimados por calidad (RPC estimateTrackFileSize a Go),
// inicia la descarga (individual o delega batch) y delega el
// cuerpo visual en hoja_opciones_descarga_cuerpo.dart.
// Se conecta con: hoja_opciones_descarga.dart (misma library) +
// backend Go + estrategia_descarga + cubit_descargas.
// Parte del flujo: descargar (selección de calidad).
// ─────────────────────────────────────────────────────────────

part of 'hoja_opciones_descarga.dart';

class _HojaOpcionesDescargaState extends State<HojaOpcionesDescarga> {
  Map<String, String> _tamanos = {};
  String? _seleccionada;
  bool _tieneDuracion = true;

  static const _calidades = {
    'flac': _QMeta('FLAC', 1411, 'lossless'),
    'hifi': _QMeta('HiFi', 320, 'lossless'),
    'high': _QMeta('High', 192, 'lossy'),
    'medium': _QMeta('Medium', 128, 'lossy'),
    'low': _QMeta('Low', 64, 'lossy'),
  };

  static const _clavesLossless = ['flac', 'hifi'];
  static const _clavesLossy = ['high', 'medium', 'low'];

  /// Wrapper público para que los parts puedan llamar setState.
  void _aplicar(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _seleccionada = widget.ajustes.calidadAudio;
    _cargarTamanos();
  }

  /// Pide el tamaño estimado de cada calidad al backend (solo con duración).
  Future<void> _cargarTamanos() async {
    final duracion = widget.item.durationMs;
    final tiene = duracion != null && duracion > 0;
    final tamanos = <String, String>{};
    if (tiene) {
      final backend = sl<BackendService>();
      for (final q in AjustesDescarga.opcionesCalidadAudio) {
        try {
          final crudo = await backend.estimateTrackFileSize(duracion, q);
          final mapa = jsonDecode(crudo) as Map?;
          final bytes = (mapa?['size_bytes'] as num?)?.toInt() ?? 0;
          tamanos[q] = formatearBytes(bytes);
        } catch (_) {
          tamanos[q] = '';
        }
      }
    }
    if (mounted) {
      setState(() {
        _tamanos = tamanos;
        _tieneDuracion = tiene;
      });
    }
  }

  /// Inicia la descarga con la calidad elegida (o delega al batch).
  void _iniciar() {
    final calidad = _seleccionada ?? widget.ajustes.calidadAudio;

    if (widget.onCalidadSeleccionada != null) {
      widget.onCalidadSeleccionada!(calidad);
      Navigator.pop(context);
      return;
    }

    final cubit = sl<CubitDescargas>();
    final item = widget.item;
    final baseId = '${item.type}_${normalizarIdTrack(item.id)}_${item.source}';
    final metaComun = construirMetaTrack(
      trackId: item.id,
      trackTitle: item.name,
      artistName: item.artists ?? '',
      albumName: item.albumName ?? '',
      source: item.source ?? '',
      isrc: item.isrc ?? '',
      durationMs: item.durationMs ?? 0,
      coverUrl: item.coverUrl,
    );
    despacharDescargas(
      cubit: cubit,
      metaComun: metaComun,
      ajustes: widget.ajustes,
      baseId: baseId,
      calidadForzada: calidad,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _cuerpoHoja(this);
}