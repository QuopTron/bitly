// ─────────────────────────────────────────────────────────────
// settings_estadisticas_detalle_fila.dart — PART de settings_sheet_new
// .dart: cada fila del detalle (posición, carátula real, nombre,
// artista, cuándo fue la última vez y cuántas veces sonó). La lista
// contenedora vive en settings_estadisticas_detalle_lista.dart.
//
// La carátula es la del archivo descargado / caché (ImagenPortada
// funciona con ruta local y con URL) y llega después de pintar la lista:
// la fila se ve al instante y la portada aparece cuando está.
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_estadisticas_detalle_lista.dart (la usa) + filtro_escucha +
// formato_escucha.
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Una fila del detalle: puesto, portada, nombre, artista, última vez y el
/// contador de reproducciones destacado a la derecha.
class _FilaDetalle extends StatelessWidget {
  final int puesto;
  final FilaEscucha fila;
  final String? caratula;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _FilaDetalle({
    required this.puesto,
    required this.fila,
    required this.caratula,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context).estadisticas;
    final lado = r.subtitleSize * 1.9;
    final minutos = textoMinutos(fila.minutos, unidadMin: s.minutos);
    final ultima = textoUltimaVez(fila.ultimaVez, desconocido: s.sinFecha);
    // El subtítulo deja lo importante adelante: artista, cuándo y minutos.
    final subtitulo = [
      if (fila.artista.isNotEmpty) fila.artista,
      ultima,
      if (minutos.isNotEmpty) minutos,
    ].join(' · ');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingS,
        vertical: r.spacingXS * 1.2,
      ),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: r.footerSize * 1.5,
            child: Text(
              '$puesto',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                fontWeight: FontWeight.w700,
                color: glowColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          SizedBox(width: r.spacingXS),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ImagenPortada(
              rutaLocal: caratula,
              ancho: lado,
              alto: lado,
              fallback: Container(
                width: lado,
                height: lado,
                color: onBg.withValues(alpha: 0.08),
                child: Icon(
                  Icons.music_note_rounded,
                  size: lado * 0.5,
                  color: onBg.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fila.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.footerSize,
                    fontWeight: FontWeight.w600,
                    color: onBg,
                  ),
                ),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.footerSize - 2,
                    color: onBg.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.spacingXS),
          // El dato que el usuario viene a ver: cuántas veces sonó.
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.spacingXS * 1.6,
              vertical: r.spacingXS * 0.6,
            ),
            decoration: BoxDecoration(
              color: glowColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${fila.reproducciones}×',
              style: TextStyle(
                fontSize: r.footerSize - 1,
                fontWeight: FontWeight.w700,
                color: glowColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
