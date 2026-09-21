// ─────────────────────────────────────────────────────────────
// settings_conexion_qr_codigo_manual.dart — PART de settings_sheet_new.dart:
// el camino SIN CÁMARA del vínculo (PC, TV, Linux).
//
// Tres cosas, en orden: el aparato de la red al que se le quiere pasar el
// vínculo, el código de 6 dígitos que ese aparato muestra debajo de su QR, y
// el botón de aceptar. El código es lo que prueba que el usuario tuvo esa
// pantalla delante; sin él el vínculo tendría que confirmarse a mano en el
// otro aparato.
//
// Se conecta con: settings_conexion_qr_codigo.dart (la hoja lo monta) +
// settings_conexion_qr_lista.dart.
// Parte del flujo: Ajustes → Conexión → vincular con QR.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Elegir aparato + escribir el código de su pantalla.
class _CaminoCodigo extends StatelessWidget {
  final ServicioLan lan;
  final ParLan? elegido;
  final void Function(ParLan) onElegir;
  final TextEditingController codigo;
  final bool ocupado;
  final VoidCallback onAceptar;
  final Color onBg;
  final Color glowColor;
  final Responsive r;

  const _CaminoCodigo({
    required this.lan,
    required this.elegido,
    required this.onElegir,
    required this.codigo,
    required this.ocupado,
    required this.onAceptar,
    required this.onBg,
    required this.glowColor,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).redConexion;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AyudaSeccion(texto: t.qrSinCamara, onBg: onBg, r: r),
        SizedBox(height: r.spacingS),
        _ListaParesCodigo(
          lan: lan,
          elegido: elegido,
          onElegir: onElegir,
          onBg: onBg,
          glowColor: glowColor,
          r: r,
        ),
        SizedBox(height: r.spacingS),
        TextField(
          controller: codigo,
          keyboardType: TextInputType.number,
          maxLength: 7,
          decoration: InputDecoration(
            labelText: t.qrCodigo,
            counterText: '',
          ),
        ),
        SizedBox(height: r.spacingXS),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: elegido != null && !ocupado ? onAceptar : null,
            child: Text(t.aceptar),
          ),
        ),
      ],
    );
  }
}
