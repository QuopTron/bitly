// ─────────────────────────────────────────────────────────────
// settings_conexion_aparato.dart — PART de settings_sheet_new.dart: los
// ayudantes de texto e ícono de Conexión, y la tarjeta del CUPO.
//
// Los motivos se traducen acá: las reglas devuelven un código
// (`MotivoConexion`) y este archivo lo convierte en texto del idioma del
// usuario, así nunca se filtra un mensaje del servicio a la pantalla.
//
// Se conecta con: settings_conexion_tab.dart (la pestaña) +
// settings_conexion_aparato_tarjeta.dart (las tarjetas de aparato) +
// servicio_conexion_reglas.
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// El texto del motivo, en el idioma del usuario.
String _textoConexion(StringsConexion t, MotivoConexion motivo) {
  switch (motivo) {
    case MotivoConexion.noEsDueno:
      return t.motivoNoEsDueno;
    case MotivoConexion.cupoLleno:
      return t.motivoCupoLleno;
    case MotivoConexion.noConectado:
      return t.motivoNoConectado;
    case MotivoConexion.esEste:
      return t.motivoEsEste;
  }
}

/// El nombre por defecto de un tipo ("Celular", "TV"...).
String _nombreTipo(StringsConexion t, TipoDispositivo tipo) {
  switch (tipo) {
    case TipoDispositivo.pc:
      return t.tipoPc;
    case TipoDispositivo.celu:
      return t.tipoCelu;
    case TipoDispositivo.tv:
      return t.tipoTv;
    case TipoDispositivo.extra:
      return t.tipoExtra;
  }
}

/// Ícono de renombrar (lápiz chico) al lado del nombre.
const IconData _iconoRenombrar = Icons.edit_outlined;

/// El icono de cada tipo de aparato.
IconData _iconoTipo(TipoDispositivo tipo) {
  switch (tipo) {
    case TipoDispositivo.pc:
      return Icons.computer_rounded;
    case TipoDispositivo.celu:
      return Icons.smartphone_rounded;
    case TipoDispositivo.tv:
      return Icons.tv_rounded;
    case TipoDispositivo.extra:
      return Icons.devices_other_rounded;
  }
}

/// Tarjeta con el cupo: cuántos aparatos de los que permite el plan.
class _TarjetaCupo extends StatelessWidget {
  final ServicioConexion servicio;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _TarjetaCupo({
    required this.servicio,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).conexion;
    return ContenedorVidrio(
      borderRadius: 14,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      padding: EdgeInsets.all(r.spacingM),
      child: Row(
        children: [
          Icon(Icons.hub_rounded, color: glowColor, size: r.subtitleSize),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Text(
              t.cupo(servicio.dispositivos.length, servicio.cupo),
              style: TextStyle(
                fontSize: r.footerSize,
                fontWeight: FontWeight.w600,
                color: onBg.withValues(alpha: 0.8),
              ),
            ),
          ),
          if (!servicio.esPremium)
            Icon(
              Icons.workspace_premium_outlined,
              size: 16,
              color: onBg.withValues(alpha: 0.35),
            ),
        ],
      ),
    );
  }
}
