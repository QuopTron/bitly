// ─────────────────────────────────────────────────────────────
// settings_conexion_qr_mostrar.dart — PART de settings_sheet_new.dart: la HOJA
// del aparato que QUIERE ENTRAR (el que muestra su QR).
//
// Pinta el QR y, debajo, el código de 6 dígitos: el dueño lee uno u otro y el
// vínculo se cierra solo. Mientras está abierta, la hoja revisa cada segundo
// si el otro ya se vinculó, y renueva el código cuando vence, así lo que se ve
// en pantalla siempre sirve.
//
// Se conecta con: settings_conexion_red.dart (la sección la abre) +
// servicio_lan (abrirInvitacion) + payload_vinculo.
// Parte del flujo: Ajustes → Conexión → vincular con QR.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Hoja del aparato que muestra su QR para que el otro lo lea.
class _HojaMostrarQr extends StatefulWidget {
  final ServicioLan lan;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onVinculado;

  const _HojaMostrarQr({
    required this.lan,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onVinculado,
  });

  @override
  State<_HojaMostrarQr> createState() => _HojaMostrarQrState();
}

class _HojaMostrarQrState extends State<_HojaMostrarQr> {
  PayloadVinculo? _dato;
  bool _listo = false;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _abrir();
    // Cada segundo: si el otro ya se vinculó se avisa, y si el código venció
    // se renueva (el que se ve en pantalla siempre vale).
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _revisar());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    widget.lan.cerrarInvitacion();
    super.dispose();
  }

  Future<void> _abrir() async {
    try {
      final dato = await widget.lan.abrirInvitacion();
      if (mounted) setState(() => _dato = dato);
    } catch (e) {
      debugPrint('[Conexion] no se pudo abrir la invitación: $e');
    }
  }

  void _revisar() {
    final dato = _dato;
    if (dato == null || !mounted) return;
    final vinculado = widget.lan.lista.any(
      (p) => p.id == dato.id && p.vinculado,
    );
    if (vinculado && !_listo) {
      setState(() => _listo = true);
      widget.onVinculado();
      return;
    }
    final ahora = DateTime.now().millisecondsSinceEpoch;
    if (!dato.vigenteEn(ahora)) unawaited(_abrir());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).redConexion;
    final r = widget.r;
    final dato = _dato;
    // Sin mini-servidor abierto no hay a dónde llegar: mejor decirlo que
    // mostrar un QR que no funciona.
    final sinRed = widget.lan.puerto <= 0;
    return AlertDialog(
      title: Text(t.qrTitulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AyudaSeccion(texto: t.qrAyuda, onBg: widget.onBg, r: r),
            SizedBox(height: r.spacingS),
            if (sinRed)
              _AyudaSeccion(texto: t.fallo, onBg: widget.onBg, r: r)
            else if (dato == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              _CuadroQr(dato: dato, r: r),
              SizedBox(height: r.spacingS),
              _CodigoGrande(codigo: dato.codigo, onBg: widget.onBg, r: r),
              SizedBox(height: r.spacingXS),
              _AyudaSeccion(texto: t.qrCodigo, onBg: widget.onBg, r: r),
              SizedBox(height: r.spacingXS),
              _AyudaSeccion(
                texto: _listo ? t.qrListo : t.qrEsperando,
                onBg: widget.onBg,
                r: r,
              ),
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
