// ─────────────────────────────────────────────────────────────
// modal_info_cancion_widgets.dart — PART de
// modal_info_cancion.dart: piezas visuales del modal — el botón de
// compartir con el texto del ítem (track + álbum) y la fila de
// detalle con icono, etiqueta y valor.
// Se conecta con: modal_info_cancion.dart (misma library) +
// share_plus + l10n.
// Parte del flujo: acciones de ítem (info del track).
// ─────────────────────────────────────────────────────────────

part of 'modal_info_cancion.dart';

/// Formatea milisegundos como mm:ss.
String _formatearDuracion(int ms) {
  final minutos = (ms ~/ 60000).toString().padLeft(2, '0');
  final segundos = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
  return '$minutos:$segundos';
}

/// Botón de compartir con el texto del ítem.
Widget _botonCompartir(
    BuildContext context, Responsive r, Color onBg, ItemFeed item) {
  return GestureDetector(
    onTap: () {
      final texto = item.albumName != null
          ? '🎵 ${item.name} — ${item.artists ?? ''}\n💿 ${item.albumName}'
          : '🎵 ${item.name} — ${item.artists ?? ''}';
      SharePlus.instance.share(ShareParams(text: texto));
    },
    child: Container(
      margin: EdgeInsets.symmetric(horizontal: r.spacingXL),
      padding: EdgeInsets.symmetric(vertical: r.spacingM),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.share, size: r.subtitleSize, color: onBg.withValues(alpha: 0.7)),
          SizedBox(width: r.spacingS),
          Text(
            AppLocalizations.of(context).setup.share,
            style: TextStyle(
              fontSize: r.subtitleSize,
              color: onBg.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Fila de detalle del modal: icono + etiqueta + valor.
Widget _filaInfo(
    Responsive r, Color onBg, IconData icono, String etiqueta, String valor) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXL, vertical: r.spacingXS),
    child: Row(
      children: [
        Icon(icono, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.4)),
        SizedBox(width: r.spacingM),
        Text(etiqueta,
            style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5))),
        const Spacer(),
        Flexible(
          child: Text(
            valor,
            style: TextStyle(
              fontSize: r.footerSize,
              fontWeight: FontWeight.w500,
              color: onBg,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}