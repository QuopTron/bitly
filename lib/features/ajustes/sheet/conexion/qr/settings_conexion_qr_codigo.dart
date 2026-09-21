// ─────────────────────────────────────────────────────────────
// settings_conexion_qr_codigo.dart — PART de settings_sheet_new.dart: la HOJA
// que abre el aparato dueño para leer el QR del que quiere entrar.
//
// Adentro decide por dónde: con cámara monta el visor (que lee el QR y cierra
// el vínculo solo); sin cámara muestra el camino del código (elegir el aparato
// que ya se ve en la red y escribir los 6 dígitos de su pantalla). El que lee
// SIEMPRE es el dueño: el código prueba que tuvo esa pantalla delante.
//
// Se conecta con: settings_conexion_qr_escanear.dart (el botón lo abre) +
// servicio_lan + payload_vinculo.  Parte del flujo: Ajustes → Conexión → QR.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Hoja del aparato dueño: lee el QR (o el código) del que quiere entrar.
class _HojaEscanearQr extends StatefulWidget {
  final ServicioLan lan;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onVinculado;

  const _HojaEscanearQr({
    required this.lan,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onVinculado,
  });

  @override
  State<_HojaEscanearQr> createState() => _HojaEscanearQrState();
}

class _HojaEscanearQrState extends State<_HojaEscanearQr> {
  final TextEditingController _codigo = TextEditingController();
  ParLan? _elegido;
  bool _ocupado = false;
  String? _aviso;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  /// Cerró un vínculo: se avisa a la sección y se cierra la hoja.
  void _listo(ParLan par) {
    widget.onVinculado();
    if (mounted) Navigator.of(context).pop();
    debugPrint('[Conexion] vinculado con ${par.nombre}');
  }

  /// El QR leído (de la cámara): se valida y se vincula.
  Future<void> _porQr(String crudo) async {
    if (_ocupado) return;
    final dato = PayloadVinculo.leer(
      crudo,
      ahoraMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (dato == null) {
      setState(() => _aviso = AppLocalizations.of(context).redConexion.qrInvalido);
      return;
    }
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    final par = await widget.lan.vincularConInvitacion(dato);
    if (!mounted) return;
    if (par == null) {
      setState(() {
        _ocupado = false;
        _aviso = AppLocalizations.of(context).redConexion.fallo;
      });
      return;
    }
    _listo(par);
  }

  /// El camino sin cámara: aparato detectado + código de su pantalla.
  Future<void> _porCodigo() async {
    final par = _elegido;
    final codigo = _codigo.text.replaceAll(' ', '');
    if (par == null || codigo.length != 6 || _ocupado) return;
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    final vinculado = await widget.lan.pedirVinculo(par, codigo: codigo);
    if (!mounted) return;
    if (vinculado == null) {
      setState(() {
        _ocupado = false;
        _aviso = AppLocalizations.of(context).redConexion.qrInvalido;
        _codigo.clear();
      });
      return;
    }
    _listo(vinculado);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).redConexion;
    final r = widget.r;
    final conCamara = camaraDeVinculoDisponible();
    return AlertDialog(
      title: Text(t.qrTitulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AyudaSeccion(texto: t.qrEscanearAyuda, onBg: widget.onBg, r: r),
            SizedBox(height: r.spacingS),
            if (conCamara)
              _CamaraVinculo(onLeido: _porQr, r: r)
            else
              _CaminoCodigo(
                lan: widget.lan,
                elegido: _elegido,
                onElegir: (p) => setState(() => _elegido = p),
                codigo: _codigo,
                ocupado: _ocupado,
                onAceptar: _porCodigo,
                onBg: widget.onBg,
                glowColor: widget.glowColor,
                r: r,
              ),
            if (_aviso != null) ...[
              SizedBox(height: r.spacingS),
              _AyudaSeccion(texto: _aviso!, onBg: widget.onBg, r: r),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cerrar),
        ),
      ],
    );
  }
}

