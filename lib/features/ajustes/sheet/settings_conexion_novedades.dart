// ─────────────────────────────────────────────────────────────
// settings_conexion_novedades.dart — PART de settings_sheet_new.dart: el
// AVISO de novedades de la pestaña Conexión.
//
// Es el espejo del cofre de Apariencia: arriba de todo la pestaña lista lo
// que hay de nuevo (el regalo de la prueba de 9 h y los aparatos declarados
// pero sin vincular) y el mininumerito de la burbuja cuenta esas mismas
// novedades. La lista se apaga al abrirla: son avisos, no reclamos.
//
// Se conecta con: settings_conexion_tab.dart (la pestaña lo muestra) +
// conexion_novedades (el modelo) + settings_conexion_aparato (los nombres).
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Tarjeta con lo que hay de nuevo en la conexión.
class _AvisoNovedades extends StatelessWidget {
  /// Lo que había al abrir la pestaña (ya marcado como visto, por eso se
  /// recibe como lista y no se vuelve a leer del servicio).
  final List<NovedadConexion> novedades;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _AvisoNovedades({
    required this.novedades,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    if (novedades.isEmpty) return const SizedBox.shrink();
    final t = AppLocalizations.of(context).conexion;
    final nov = AppLocalizations.of(context).novedadesConexion;
    return ContenedorVidrio(
      borderRadius: 14,
      borderColor: glowColor.withValues(alpha: 0.25),
      bgColor: glowColor.withValues(alpha: 0.06),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nov.titulo,
            style: TextStyle(
              fontSize: r.footerSize + 1,
              fontWeight: FontWeight.w700,
              color: glowColor,
            ),
          ),
          SizedBox(height: r.spacingXS),
          for (final n in novedades)
            Padding(
              padding: EdgeInsets.only(top: r.spacingXS),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconoNovedad(n), size: 15, color: glowColor),
                  SizedBox(width: r.spacingXS),
                  Expanded(
                    child: Text(
                      _textoNovedad(n, t, nov),
                      style: TextStyle(
                        fontSize: r.footerSize - 1,
                        color: onBg.withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Ícono de la novedad: regalo o aparato esperando vínculo.
  IconData _iconoNovedad(NovedadConexion n) =>
      n.tipo == TipoNovedadConexion.prueba
          ? Icons.card_giftcard_rounded
          : Icons.link_off_rounded;

  /// El texto: el regalo es genérico; el aparato lleva su nombre (y si el
  /// nombre quedó vacío, el de su tipo, para no mostrar «»).
  String _textoNovedad(
    NovedadConexion n,
    StringsConexion t,
    StringsConexionNovedades nov,
  ) {
    if (n.tipo == TipoNovedadConexion.prueba) return nov.prueba;
    final tipo = n.tipoAparato;
    final nombre =
        n.aparato.isNotEmpty
            ? n.aparato
            : (tipo == null ? t.tipoExtra : _nombreTipo(t, tipo));
    return nov.aparatoPendiente(nombre);
  }
}
