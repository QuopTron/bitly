// ─────────────────────────────────────────────────────────────
// settings_conexion_qr_camara.dart — PART de settings_sheet_new.dart: la
// cámara que lee el QR del vínculo.
//
// Está aparte para que el plugin de cámara viva en UN solo archivo: solo se
// instancia cuando la plataforma lo soporta (ver camaraDeVinculoDisponible),
// así en PC/TV/Linux nunca se enciende nada y la hoja usa el código a mano.
//
// El QR lo decodifica `zxing2` (Dart puro) sobre la capa Y del fotograma, no
// ML Kit: el paquete completo de ML Kit eran ~3 MB de APK para esta única
// pantalla. El motor está en base/lector_qr.dart (y ahí está lo que se prueba
// en los tests: acá sólo queda encender la cámara y pasarle fotogramas).
//
// Si la cámara no está (sin permiso, ocupada por otra app), en vez del visor
// queda un aviso: la hoja sigue usable con el código de 6 dígitos.
//
// Se conecta con: settings_conexion_qr_escanear.dart (lo monta) + lector_qr.
// Parte del flujo: Ajustes → Conexión → vincular con QR.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Visor de cámara que entrega el primer QR que lee.
class _CamaraVinculo extends StatefulWidget {
  final void Function(String) onLeido;
  final Responsive r;

  const _CamaraVinculo({required this.onLeido, required this.r});

  @override
  State<_CamaraVinculo> createState() => _CamaraVinculoState();
}

class _CamaraVinculoState extends State<_CamaraVinculo> {
  CameraController? _camara;
  final LectorQr _lector = LectorQr();

  /// El QR ya se entregó: no se procesa otro mientras se cierra la hoja.
  bool _entregado = false;

  /// Hay un fotograma decodificándose. Los cuadros llegan más rápido de lo que
  /// cuesta decodificar uno, así que se saltean: sin esto se encolan cientos de
  /// cuadros y la cámara se siente trabada en un teléfono lento.
  bool _ocupado = false;

  /// Cuándo se intentó por última vez. Aun con la CPU libre no tiene sentido
  /// decodificar 30 veces por segundo: un QR se sostiene quieto en la pantalla.
  DateTime _ultimoIntento = DateTime.fromMillisecondsSinceEpoch(0);
  static const _pausaEntreLecturas = Duration(milliseconds: 250);

  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_abrir());
  }

  Future<void> _abrir() async {
    try {
      final disponibles = await availableCameras();
      if (disponibles.isEmpty) throw Exception('sin cámaras');
      // `medium` (640x480) y no la resolución máxima: un QR se lee igual y en
      // la gama baja decodificar 1080p por fotograma no da abasto. Sin audio,
      // que acá no se usa y pedirlo complica el permiso.
      final camara = CameraController(
        _camaraTrasera(disponibles),
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await camara.initialize();
      if (!mounted) {
        await camara.dispose();
        return;
      }
      setState(() => _camara = camara);
      await camara.startImageStream(_mirar);
    } catch (e) {
      debugPrint('[QR] no se pudo abrir la cámara: $e');
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// La cámara de atrás: la de adelante apunta al dueño, no al otro aparato.
  CameraDescription _camaraTrasera(List<CameraDescription> camaras) {
    for (final c in camaras) {
      if (c.lensDirection == CameraLensDirection.back) return c;
    }
    return camaras.first;
  }

  void _mirar(CameraImage foto) {
    if (_entregado || _ocupado) return;
    final ahora = DateTime.now();
    if (ahora.difference(_ultimoIntento) < _pausaEntreLecturas) return;
    _ultimoIntento = ahora;

    // La capa 0 de YUV420 es la luminancia: exactamente lo que el lector
    // necesita (no hay que convertir nada a color).
    final capa = foto.planes.first;
    // Ojo: en camera 0.12 el ancho/alto del plano son nullables (algunas
    // cámaras no los informan). Un cuadro sin medidas no sirve: se descarta.
    final ancho = capa.width;
    final alto = capa.height;
    if (ancho == null || alto == null || ancho < 16 || alto < 16) return;
    _ocupado = true;
    final texto = _lector.leer(
      bytes: capa.bytes,
      ancho: ancho,
      alto: alto,
      bytesPorFila: capa.bytesPerRow,
    );
    _ocupado = false;
    if (texto != null && !_entregado) {
      _entregado = true;
      widget.onLeido(texto);
    }
  }

  @override
  void dispose() {
    // Detener el stream antes de liberar: si no, el plugin sigue entregando
    // fotogramas a un State que ya no existe.
    final camara = _camara;
    _camara = null;
    unawaited(
      (camara?.stopImageStream() ?? Future<void>.value()).then((_) {
        camara?.dispose();
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).redConexion;
    final r = widget.r;
    final lado = r.val(200, 160, 280);
    final camara = _camara;
    final listo = camara != null && camara.value.isInitialized && _error == null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: lado,
        height: lado,
        child: listo ? _visor(camara, lado) : _sinCamara(t.qrSinCamara, r),
      ),
    );
  }

  /// La vista previa, recortada a CUADRADO: el marco del escáner es cuadrado y
  /// una franja ancha obligaría a buscar el QR fuera de la zona que se mira.
  Widget _visor(CameraController camara, double lado) {
    // En vertical, la vista previa llega "acostada" (el sensor es horizontal),
    // así que sus lados se cruzan respecto del cuadro.
    final previa = camara.value.previewSize;
    final ancho = previa?.height ?? lado;
    final alto = previa?.width ?? lado;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: ancho,
        height: alto,
        child: CameraPreview(camara),
      ),
    );
  }

  /// El aviso de que acá no hay cámara: la hoja sigue usable con el código a
  /// mano, así que no es un callejón sin salida.
  Widget _sinCamara(String texto, Responsive r) => ColoredBox(
    color: Colors.black26,
    child: Padding(
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined),
          SizedBox(height: r.spacingXS),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: r.footerSize),
          ),
        ],
      ),
    ),
  );
}
