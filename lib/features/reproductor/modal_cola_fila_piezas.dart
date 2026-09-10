// PART de modal_cola.dart: sub-piezas de la fila — indicador, miniatura,
// nombre/artista, badge de fuente y botón de quitar.

part of 'modal_cola.dart';

Widget _indicadorFila(FilaTrackCola f) {
  final r = f.r;
  final fg = f.fg;
  return SizedBox(
    width: 24,
    child: f.esActual
        ? Icon(Icons.play_arrow_rounded,
            color: f.colorBrillo, size: r.subtitleSize + 2)
        : Row(
            children: [
              Icon(Icons.drag_indicator,
                  size: r.subtitleSize,
                  color: fg.withValues(alpha: 0.2)),
              Text(
                '${f.index + 1}',
                style: TextStyle(
                  fontSize: r.footerSize,
                  color: f.esReproducida
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
  final fg = f.fg;
  return Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: fg.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imagenDesdeUrl(
        f.track.coverUrl,
        ancho: 38,
        alto: 38,
        ajuste: BoxFit.cover,
        fallback: Icon(Icons.music_note,
            size: 18, color: fg.withValues(alpha: 0.3)),
      ),
    ),
  );
}

Widget _infoFila(FilaTrackCola f) {
  final r = f.r;
  final fg = f.fg;
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(f.track.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.subtitleSize,
              fontWeight: f.esActual ? FontWeight.bold : FontWeight.w500,
              color: f.esReproducida
                  ? fg.withValues(alpha: 0.3)
                  : (f.esActual ? f.colorBrillo : fg),
            )),
        if (f.track.artists != null && f.track.artists!.isNotEmpty)
          Text(f.track.artists!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: f.esReproducida
                    ? fg.withValues(alpha: 0.18)
                    : fg.withValues(alpha: 0.55),
              )),
      ],
    ),
  );
}

Widget _badgeFuenteFila(FilaTrackCola f) {
  final r = f.r;
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
  final r = f.r;
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
    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
  };
  return siglas[fuente] ??
      (fuente.length > 4
          ? fuente.substring(0, 4).toUpperCase()
          : fuente.toUpperCase());
}