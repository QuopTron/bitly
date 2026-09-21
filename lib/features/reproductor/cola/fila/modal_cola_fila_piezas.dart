// PART de modal_cola.dart: sub-piezas de la fila — indicador, miniatura,
// nombre/artista, badge de fuente y botón de quitar.

part of '../base/hoja/modal_cola.dart';

Widget _indicadorFila(FilaTrackCola f) {
  // El `Responsive` viene del padre: declararlo con su tipo deja claro que
  // esta fila mide por APARATO (en la tele el índice y su hueco crecen).
  final Responsive r = f.r;
  final fg = f.fg;
  return SizedBox(
    width: r.sobre(24, 34),
    child:
        f.esActual
            ? Icon(
              Icons.play_arrow_rounded,
              color: f.colorBrillo,
              size: r.subtitleSize + 2,
            )
            : Row(
              children: [
                Icon(
                  Icons.drag_indicator,
                  size: r.subtitleSize,
                  color: fg.withValues(alpha: 0.2),
                ),
                Text(
                  '${f.index + 1}',
                  style: TextStyle(
                    fontSize: r.footerSize,
                    color:
                        f.esReproducida
                            ? fg.withValues(alpha: 0.2)
                            : fg.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
  );
}

Widget _miniaturaFila(FilaTrackCola f) {
  final Responsive r = f.r;
  final esp = EspecificacionesPlataforma.de(f.r.context);
  final fg = f.fg;
  final lado = r.sobre(38, 56);
  final radius = BorderRadius.circular(r.spacingM);
  return Container(
    width: lado,
    height: lado,
    decoration: BoxDecoration(
      color: fg.withValues(alpha: 0.1),
      borderRadius: radius,
    ),
    child: ClipRRect(
      borderRadius: radius,
      child: imagenDesdeUrl(
        f.track.coverUrl,
        ancho: lado,
        alto: lado,
        ajuste: BoxFit.cover,
        fallback: Icon(
          Icons.music_note,
          size: esp.iconoBoton,
          color: fg.withValues(alpha: 0.3),
        ),
      ),
    ),
  );
}

Widget _infoFila(FilaTrackCola f) {
  final Responsive r = f.r;
  final fg = f.fg;
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          f.track.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.subtitleSize,
            fontWeight: f.esActual ? FontWeight.bold : FontWeight.w500,
            color:
                f.esReproducida
                    ? fg.withValues(alpha: 0.3)
                    : (f.esActual ? f.colorBrillo : fg),
          ),
        ),
        if (f.track.artists != null && f.track.artists!.isNotEmpty)
          Text(
            f.track.artists!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.footerSize - 1,
              color:
                  f.esReproducida
                      ? fg.withValues(alpha: 0.18)
                      : fg.withValues(alpha: 0.55),
            ),
          ),
      ],
    ),
  );
}

Widget _badgeFuenteFila(FilaTrackCola f) {
  final Responsive r = f.r;
  final fg = f.fg;
  if (f.track.source == null || f.track.source!.isEmpty || f.esActual) {
    return const SizedBox.shrink();
  }
  return Container(
    margin: EdgeInsets.only(right: r.spacingXS),
    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: fg.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      _fuenteCorta(f.track.source!),
      style: TextStyle(
        fontSize: r.footerSize - 2,
        color: fg.withValues(alpha: 0.4),
      ),
    ),
  );
}

Widget _botonQuitarFila(FilaTrackCola f) {
  final Responsive r = f.r;
  final fg = f.fg;
  if (f.onQuitar == null || f.esActual) {
    return const SizedBox.shrink();
  }
  return IconButton(
    icon: Icon(
      Icons.close,
      size: r.subtitleSize,
      color: fg.withValues(alpha: 0.35),
    ),
    padding: EdgeInsets.zero,
    constraints: BoxConstraints(
      minWidth: r.sobre(28, 40),
      minHeight: r.sobre(28, 40),
    ),
    onPressed: () {
      Haptico.tap();
      f.onQuitar?.call();
    },
  );
}

String _fuenteCorta(String fuente) {
  const siglas = {
    'spotify-web': 'SP',
    'ytmusic-spotiflac': 'YT',
    'tidal-web': 'TD',
    'qobuz-web': 'QZ',
    'deezer': 'DZ',
    'apple-music': 'AM',
    'amazon': 'AZ',
    'soundcloud': 'SC',
    'internetarchive': 'IA',
  };
  return siglas[fuente] ??
      (fuente.length > 4
          ? fuente.substring(0, 4).toUpperCase()
          : fuente.toUpperCase());
}
