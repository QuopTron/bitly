// ─────────────────────────────────────────────────────────────
// tarjeta_track_deslizar.dart — PART de tarjeta_track.dart: gesto
// de deslizar la tarjeta hacia la derecha para agregar la canción al
// final de la cola (estilo Spotify), con fondo verde e icono de cola
// y un aviso breve. La tarjeta vuelve a su sitio: el gesto nunca
// borra ni descarga, solo encola. Si la tarjeta no trae [item] (casos
// donde no hay datos de canción) el gesto se omite.
// Se conecta con: tarjeta_track.dart (misma library) + cubit_cola +
// haptico.
// Parte del flujo: listas de tracks (búsqueda, feed, mi espacio,
// detalle de álbum/playlist/artista).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_track.dart';

/// Envuelve [hijo] con el gesto de encolar. Devuelve [hijo] intacto si la
/// tarjeta no tiene [TarjetaTrack.item] (no hay canción que encolar).
Widget _conDeslizarCola(
  TarjetaTrack t,
  BuildContext context,
  Responsive r,
  Widget hijo,
) {
  final item = t.item;
  if (item == null) return hijo;

  return Dismissible(
    key: ValueKey('cola_${item.id}_${item.source ?? ''}'),
    direction: DismissDirection.startToEnd,
    dismissThresholds: const {DismissDirection.startToEnd: 0.35},
    confirmDismiss: (_) async {
      Haptico.medio();
      sl<CubitCola>().agregarAlFinal(item);
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Agregado a la cola · ${t.titulo}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      // La tarjeta NO se va: el gesto solo encola.
      return false;
    },
    background: Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: r.spacingL),
      decoration: BoxDecoration(
        color: ColoresApp.verdeBrillante.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        Icons.queue_music_rounded,
        color: ColoresApp.verdeBrillante,
        size: r.footerSize * 1.8,
      ),
    ),
    child: hijo,
  );
}
