// ─────────────────────────────────────────────────────────────
// settings_conexion_qr_escanear.dart — PART de settings_sheet_new.dart: el
// BOTÓN de leer el QR del otro aparato, más la pregunta de si esta plataforma
// tiene cámara para hacerlo.
//
// El botón vive solo: la hoja que abre está en settings_conexion_qr_codigo
// (que adentro decide entre la cámara y el código escrito a mano).
//
// El que lee SIEMPRE es el dueño: es el único que mete aparatos en la cuenta,
// y el código prueba que tuvo esa pantalla delante. Por eso el botón se apaga
// cuando este aparato no controla la cuenta.
//
// Se conecta con: settings_conexion_qr_codigo.dart (la hoja) +
// servicio_conexion (las reglas del dueño).
// Parte del flujo: Ajustes → Conexión → vincular con QR.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// ¿Esta plataforma puede abrir la cámara para leer un QR? La TV queda afuera
/// (no tiene cámara y se maneja con el control remoto).
bool camaraDeVinculoDisponible() {
  if (kIsWeb || esTelevisor) return false;
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

/// El botón que abre la hoja de lectura (solo el aparato dueño).
class _BotonQrEscanear extends StatelessWidget {
  final ServicioLan lan;
  final ServicioConexion servicio;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onCambio;

  const _BotonQrEscanear({
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
    return OutlinedButton.icon(
      onPressed:
          servicio.esteDispositivo?.esDueno == true
              ? () => mostrarDialogo<void>(
                context: context,
                builder:
                    (ctx) => _HojaEscanearQr(
                      lan: lan,
                      glowColor: glowColor,
                      onBg: onBg,
                      r: r,
                      onVinculado: onCambio,
                    ),
              )
              : null,
      icon: Icon(Icons.qr_code_scanner_rounded, size: r.sobre(18)),
      label: Text(t.qrEscanear),
    );
  }
}

