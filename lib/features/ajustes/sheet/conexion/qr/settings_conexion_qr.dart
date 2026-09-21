// ─────────────────────────────────────────────────────────────
// settings_conexion_qr.dart — PART de settings_sheet_new.dart: el BOTÓN que
// abre el QR del aparato que quiere entrar, y las dos hojas del vínculo (la
// que muestra y la que lee) viven en los archivos de al lado.
//
// El botón se apaga cuando el plan ya está lleno: al vínculo hay que poder
// guardarlo, y sin lugar la invitación sería un QR que no lleva a nada.
//
// Se conecta con: settings_conexion_red.dart (la sección lo monta) +
// settings_conexion_qr_mostrar.dart (la hoja que abre).
// Parte del flujo: Ajustes → Conexión → vincular con QR.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// El botón que abre la hoja del QR (el aparato muestra su invitación).
///
/// Se apaga cuando el plan ya está lleno: al vínculo hay que poder guardarlo,
/// y sin lugar la invitación sería un QR que no lleva a nada.
class _BotonQrMostrar extends StatelessWidget {
  final ServicioLan lan;
  final ServicioConexion servicio;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onCambio;

  const _BotonQrMostrar({
    required this.lan,
    required this.servicio,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).redConexion;
    return FilledButton.tonalIcon(
      onPressed:
          servicio.puedeAgregar
              ? () => mostrarDialogo<void>(
                context: context,
                builder:
                    (ctx) => _HojaMostrarQr(
                      lan: lan,
                      glowColor: glowColor,
                      onBg: onBg,
                      r: r,
                      onVinculado: onCambio,
                    ),
              )
              : null,
      icon: Icon(Icons.qr_code_2_rounded, size: r.sobre(18)),
      label: Text(t.qrBoton),
    );
  }
}
