// ─────────────────────────────────────────────────────────────
// settings_conexion_qr_camara.dart — PART de settings_sheet_new.dart: la
// cámara que lee el QR del vínculo.
//
// Está aparte para que el plugin de cámara viva en UN solo archivo: solo se
// instancia cuando la plataforma lo soporta (ver camaraDeVinculoDisponible),
// así en PC/TV/Linux nunca se enciende nada y la hoja usa el código a mano.
//
// Si la cámara no está (sin permiso, ocupada por otra app), en vez del visor
// queda un aviso: la hoja sigue usable con el código de 6 dígitos.
//
// Se conecta con: settings_conexion_qr_escanear.dart (lo monta).
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
  final MobileScannerController _control = MobileScannerController(
    // Solo QR: cualquier otro código se ignora en el origen.
    formats: const [BarcodeFormat.qrCode],
    // Un mismo QR repetido no vuelve a disparar el vínculo.
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// El QR ya se entregó: no se procesa otro mientras se cierra la hoja.
  bool _entregado = false;

  @override
  void dispose() {
    unawaited(_control.dispose());
    super.dispose();
  }

  void _alLeer(BarcodeCapture captura) {
    if (_entregado) return;
    for (final codigo in captura.barcodes) {
      final texto = codigo.rawValue;
      if (texto == null || texto.isEmpty) continue;
      _entregado = true;
      widget.onLeido(texto);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).redConexion;
    final r = widget.r;
    final lado = r.val(200, 160, 280);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: lado,
        height: lado,
        child: MobileScanner(
          controller: _control,
          onDetect: _alLeer,
          errorBuilder:
              (_, error) => ColoredBox(
                color: Colors.black26,
                child: Padding(
                  padding: EdgeInsets.all(r.spacingM),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.no_photography_outlined),
                      SizedBox(height: r.spacingXS),
                      Text(
                        t.qrSinCamara,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: r.footerSize),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
