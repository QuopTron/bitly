// ─────────────────────────────────────────────────────────────
// settings_conexion_red_fila.dart — PART de settings_sheet_new.dart: la fila
// de UN aparato de la red local.
//
// Muestra su nombre y si ya está vinculado, y ofrece lo que corresponde:
// vincularse (todavía no hay confianza), traer lo que falta o olvidarlo (ya
// hay vínculo). Mientras hay algo en curso muestra el avance y no deja
// apretar de nuevo.
//
// Se conecta con: settings_conexion_red.dart (la sección) + servicio_lan.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Un aparato de la red, con lo que se puede hacer con él.
class _FilaPar extends StatelessWidget {
  final ParLan par;
  final bool ocupado;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onVincular;
  final VoidCallback onTraer;
  final VoidCallback onOlvidar;

  const _FilaPar({
    required this.par,
    required this.ocupado,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onVincular,
    required this.onTraer,
    required this.onOlvidar,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context).redConexion;
    return ContenedorVidrio(
      borderRadius: 14,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.devices_rounded,
                color: glowColor,
                size: r.subtitleSize,
              ),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Text(
                  par.nombre.isEmpty ? par.host : par.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.footerSize + 1,
                    fontWeight: FontWeight.w600,
                    color: onBg,
                  ),
                ),
              ),
            ],
          ),
          if (ocupado) ...[SizedBox(height: r.spacingS), _avance(context)],
          SizedBox(height: r.spacingXS),
          Row(
            children: [
              if (par.vinculado) ...[
                FilledButton.tonal(
                  onPressed: ocupado ? null : onTraer,
                  child: Text(loc.traer),
                ),
                SizedBox(width: r.spacingXS),
                TextButton(
                  onPressed: ocupado ? null : onOlvidar,
                  child: Text(loc.olvidar),
                ),
              ] else
                FilledButton.tonal(
                  onPressed: ocupado ? null : onVincular,
                  child: Text(loc.vincular),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Qué está pasando: esperando al otro aparato (barra que va y viene) o
  /// copiando (barra con el avance real). Mientras copia se puede cancelar, y
  /// lo que ya llegó se queda.
  Widget _avance(BuildContext context) {
    final loc = AppLocalizations.of(context).redConexion;
    final prog = AppLocalizations.of(context).traspasoConexion;
    final lan = sl<ServicioLan>();
    return ValueListenableBuilder<(int, int)>(
      valueListenable: lan.traspaso,
      builder: (context, avance, _) {
        final copiando = avance.$2 > 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                // Sin total todavía es la espera: la barra va y viene.
                value: copiando ? avance.$1 / avance.$2 : null,
                minHeight: 4,
                color: glowColor,
                backgroundColor: onBg.withValues(alpha: 0.08),
              ),
            ),
            SizedBox(height: r.spacingXS),
            Row(
              children: [
                Expanded(
                  child: Text(
                    copiando
                        ? prog.copiando(avance.$1, avance.$2)
                        : loc.esperando,
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: onBg.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                if (copiando)
                  TextButton(
                    onPressed: lan.cancelarTraspaso,
                    child: Text(prog.cancelar),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
