// ─────────────────────────────────────────────────────────────
// settings_conexion_aparato_cabecera.dart — PART de settings_sheet_new.dart:
// la cabecera de la tarjeta de un aparato.
//
// Muestra el ícono de su tipo, su nombre (renombrable por el dueño con el
// lápiz) y su estado real: EN LÍNEA (vinculado y visto hace poco), VINCULADO
// (emparejado, pero no ahora) o SIN VINCULAR (declarado, todavía sin
// emparejar). El aparato que controla la cuenta lleva su marca.
//
// Se conecta con: settings_conexion_aparato_tarjeta.dart (la tarjeta) +
// settings_conexion_aparato.dart (los ayudantes de texto e ícono).
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Ícono de tipo, nombre (renombrable por el dueño) y la marca de quién manda.
class _CabeceraAparato extends StatelessWidget {
  final DispositivoConectado dispositivo;
  final bool esEste;
  final bool enLinea;
  final ServicioConexion servicio;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onCambio;

  const _CabeceraAparato({
    required this.dispositivo,
    required this.esEste,
    required this.enLinea,
    required this.servicio,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).conexion;
    return Row(
      children: [
        Icon(
          _iconoTipo(dispositivo.tipo),
          color: glowColor,
          size: r.subtitleSize,
        ),
        SizedBox(width: r.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      dispositivo.nombre.isEmpty
                          ? _nombreTipo(t, dispositivo.tipo)
                          : dispositivo.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.footerSize + 1,
                        fontWeight: FontWeight.w700,
                        color: onBg,
                      ),
                    ),
                  ),
                  // Renombrar: solo el dueño, y nunca a sí mismo por acá.
                  if (!esEste && servicio.puedeQuitar(dispositivo))
                    InkWell(
                      onTap:
                          () => _pedirNombreAparato(
                            context,
                            servicio,
                            dispositivo,
                            onCambio,
                          ),
                      child: Padding(
                        padding: EdgeInsets.only(left: r.spacingXS),
                        child: Icon(
                          _iconoRenombrar,
                          size: 13,
                          color: onBg.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                _estado(t, enLinea),
                style: TextStyle(
                  fontSize: r.footerSize - 2,
                  color: onBg.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        if (dispositivo.esDueno || esEste)
          Padding(
            padding: EdgeInsets.only(left: r.spacingXS),
            child: _ChipPersonalizado(
              texto: esEste ? t.esteAparato : t.controla,
              glowColor: glowColor,
              r: r,
            ),
          ),
      ],
    );
  }

  /// El estado en palabras: en línea, vinculado o todavía sin vincular.
  String _estado(StringsConexion t, bool enLinea) {
    if (enLinea) return t.enLinea;
    return dispositivo.vinculado ? t.vinculado : t.sinVincular;
  }
}
