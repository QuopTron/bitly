// ─────────────────────────────────────────────────────────────
// settings_conexion_aparato_tarjeta.dart — PART de settings_sheet_new.dart:
// la tarjeta de UN aparato: el vidrio y el apilado de sus dos partes.
//
// La cabecera (ícono, nombre, marca de quién manda) vive en
// _conexion_aparato_cabecera y las acciones (sacar / motivo) en
// _conexion_aparato_acciones: así cada archivo hace una sola cosa.
//
// Se conecta con: settings_conexion_tab.dart (la pestaña) +
// settings_conexion_aparato.dart (los ayudantes de texto e ícono).
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Tarjeta de UN aparato con su estado y (si sos el dueño) el botón de sacar.
class _TarjetaAparato extends StatelessWidget {
  final DispositivoConectado dispositivo;
  final ServicioConexion servicio;
  final int ahoraMs;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onCambio;

  const _TarjetaAparato({
    required this.dispositivo,
    required this.servicio,
    required this.ahoraMs,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final esEste = dispositivo.id == servicio.idPropio;

    return ContenedorVidrio(
      borderRadius: 14,
      // El propio se destaca: es el que el usuario está usando.
      borderColor: onBg.withValues(alpha: esEste ? 0.18 : 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CabeceraAparato(
            dispositivo: dispositivo,
            esEste: esEste,
            enLinea: dispositivo.enLineaEn(ahoraMs),
            servicio: servicio,
            glowColor: glowColor,
            onBg: onBg,
            r: r,
            onCambio: onCambio,
          ),
          _AccionesAparato(
            dispositivo: dispositivo,
            esEste: esEste,
            servicio: servicio,
            onBg: onBg,
            r: r,
            onCambio: onCambio,
          ),
        ],
      ),
    );
  }
}
