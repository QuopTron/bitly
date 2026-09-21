// ─────────────────────────────────────────────────────────────
// settings_conexion_red.dart — PART de settings_sheet_new.dart: la sección
// "En tu red" de la pestaña Conexión.
//
// Lista los aparatos de la MISMA red y deja vincularse y traerse lo que ya
// está descargado allá. El cupo del plan se respeta: con free y sin prueba no
// hay lugar. Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Sección de aparatos en la red local.
class _RedConexion extends StatefulWidget {
  final ServicioConexion servicio;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _RedConexion({
    required this.servicio,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  State<_RedConexion> createState() => _RedConexionState();
}

class _RedConexionState extends State<_RedConexion> {
  ServicioLan? _lan;

  /// Id del aparato con una operación en curso (vincular o copiar).
  String? _ocupado;

  /// Aviso al pie de la sección (resultado o el motivo por el que no se pudo).
  String? _aviso;

  @override
  void initState() {
    super.initState();
    try {
      _lan = sl<ServicioLan>();
    } catch (e) {
      debugPrint('[Conexion] no hay vínculo de red: $e');
    }
    _lan?.solicitudVinculo.addListener(_verSolicitud);
  }

  @override
  void dispose() {
    _lan?.solicitudVinculo.removeListener(_verSolicitud);
    super.dispose();
  }

  /// Alguien de la red pide vincularse: se le pregunta al usuario.
  Future<void> _verSolicitud() async {
    final lan = _lan;
    final pedido = lan?.solicitudVinculo.value;
    if (lan == null || pedido == null || !mounted) return;
    final resultado = await atenderPedidoVinculo(
      context,
      lan,
      pedido,
      hayLugar: widget.servicio.puedeAgregar || _yaVinculado(pedido.id),
    );
    if (!mounted) return;
    setState(() {
      if (resultado == ResultadoPedidoVinculo.sinLugar) {
        _aviso = AppLocalizations.of(context).redConexion.sinLugar;
      }
    });
  }

  bool _yaVinculado(String id) =>
      widget.servicio.dispositivos.any((d) => d.id == id && d.vinculado);

  /// Corre [accion] sobre un aparato mostrando que está en curso y, al
  /// terminar, el resultado que devuelva (null = no hay nada que decir).
  Future<void> _correr(ParLan par, Future<String?> Function() accion) async {
    setState(() {
      _ocupado = par.id;
      _aviso = null;
    });
    final aviso = await accion();
    if (!mounted) return;
    setState(() {
      _ocupado = null;
      _aviso = aviso;
    });
  }

  Future<void> _vincular(ParLan par) {
    final lan = _lan;
    if (lan == null) return Future<void>.value();
    final loc = AppLocalizations.of(context).redConexion;
    return _correr(par, () => vincularParRed(lan, par, loc));
  }

  /// Copia lo que falte de ese aparato (se puede cancelar a mitad).
  Future<void> _traer(ParLan par) {
    final lan = _lan;
    if (lan == null) return Future<void>.value();
    final prog = AppLocalizations.of(context).traspasoConexion;
    return _correr(par, () => traerParRed(lan, par, prog));
  }

  Future<void> _olvidar(ParLan par) async {
    await _lan?.olvidarPar(par.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context).redConexion;
    final lan = _lan;
    final r = widget.r;
    if (lan == null || !lan.activo) {
      return _AyudaSeccion(texto: loc.vacio, onBg: widget.onBg, r: r);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.titulo,
          style: TextStyle(
            fontSize: r.footerSize + 1,
            fontWeight: FontWeight.w700,
            color: widget.onBg,
          ),
        ),
        SizedBox(height: r.spacingXS),
        _AyudaSeccion(texto: loc.ayuda, onBg: widget.onBg, r: r),
        SizedBox(height: r.spacingS),
        _ListaPares(
          lan: lan,
          ocupado: _ocupado,
          glowColor: widget.glowColor,
          onBg: widget.onBg,
          r: r,
          onVincular: _vincular,
          onTraer: _traer,
          onOlvidar: _olvidar,
        ),
        SizedBox(height: r.spacingS),
        // Vincular con QR: el otro aparato muestra su QR, este lo lee (o se
        // escribe el código si no hay cámara).
        Wrap(
          spacing: r.spacingXS,
          runSpacing: r.spacingXS,
          children: [
            _BotonQrMostrar(
              lan: lan,
              servicio: widget.servicio,
              glowColor: widget.glowColor,
              onBg: widget.onBg,
              r: r,
              onCambio: () => setState(() {}),
            ),
            _BotonQrEscanear(
              lan: lan,
              servicio: widget.servicio,
              glowColor: widget.glowColor,
              onBg: widget.onBg,
              r: r,
              onCambio: () => setState(() {}),
            ),
          ],
        ),
        if (_aviso != null)
          _AyudaSeccion(texto: _aviso!, onBg: widget.onBg, r: r),
      ],
    );
  }
}
