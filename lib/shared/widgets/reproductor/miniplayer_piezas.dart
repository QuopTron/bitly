// miniplayer_piezas.dart — PART de miniplayer.dart: fila superior del
// miniplayer (carátula + info + controles) y el icono genérico. El botón
// play y el progreso viven en miniplayer_controles.dart.

part of 'miniplayer.dart';

/// Fila superior: carátula + info + shuffle/prev/play/next/repeat.
Widget _filaTrackMini(
  _MiniplayerState st,
  Responsive r,
  Color fg,
  bool esOscuro,
  EstadoCola cola,
  EstadoAudioReproductor player,
  ItemFeed track,
  String? caratula,
  bool buffering,
) {
  return Row(
    children: [
      GestureDetector(
        onTap: st._abrirCompleto,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: ColoresApp.sombra(esOscuro).withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ImagenPortada(coverUrl: caratula, ancho: 36, alto: 36),
          ),
        ),
      ),
      SizedBox(width: r.spacingXS),
      // La info del track (nombre + artista) también abre el reproductor
      // completo al tocarla, igual que la carátula.
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: st._abrirCompleto,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.footerSize,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              if (track.artists != null && track.artists!.isNotEmpty)
                Text(
                  track.artists!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.footerSize - 2,
                    color: fg.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
      SizedBox(width: r.spacingXS),
      _iconoControlMini(
        st,
        r,
        fg,
        cola.shuffle ? Icons.shuffle_rounded : Icons.shuffle,
        activo: cola.shuffle,
        onTap: () => st.context.read<CubitCola>().alternarShuffle(),
      ),
      _iconoControlMini(st, r, fg, Icons.skip_previous_rounded,
          tamanoExtra: 3,
          atenuado: true,
          onTap: () => st.context.read<CubitReproductor>().anterior()),
      _botonPlayMini(st, r, fg, player, buffering),
      _iconoControlMini(st, r, fg, Icons.skip_next_rounded,
          tamanoExtra: 3,
          atenuado: true,
          onTap: () => st.context.read<CubitReproductor>().siguiente()),
      _iconoControlMini(
        st,
        r,
        fg,
        cola.modoRepeticion == ModoRepeticion.uno
            ? Icons.repeat_one_rounded
            : Icons.repeat_rounded,
        activo: cola.modoRepeticion != ModoRepeticion.ninguno,
        onTap: () => st.context.read<CubitCola>().ciclarModoRepeticion(),
      ),
    ],
  );
}

/// Icono de control genérico con estados activo/atenuado.
Widget _iconoControlMini(
  _MiniplayerState st,
  Responsive r,
  Color fg,
  IconData icono, {
  bool activo = false,
  bool atenuado = false,
  double? tamanoExtra,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Icon(
        icono,
        size: r.footerSize + 8 + (tamanoExtra ?? 0),
        color: activo
            ? fg
            : atenuado
                ? fg.withValues(alpha: 0.5)
                : fg.withValues(alpha: 0.3),
      ),
    ),
  );
}