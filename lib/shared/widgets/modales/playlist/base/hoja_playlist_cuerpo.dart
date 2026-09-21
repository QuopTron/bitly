// ─────────────────────────────────────────────────────────────
// hoja_playlist_cuerpo.dart — PART de hoja_playlist.dart: arma el
// panel de la hoja (alto, esquinas redondeadas, fondo reactivo a la
// carátula y el orden de las piezas: tirador, cabecera, portada+nombre,
// atajos y lista).
// Se conecta con: hoja_playlist.dart (misma library) + fondo reactivo.
// Parte del flujo: Mi Espacio / detalle → playlists (crear y editar).
// ─────────────────────────────────────────────────────────────

part of 'hoja_playlist.dart';

/// Alto de una fila de canción (la lista se mide con esto para no usar
/// `shrinkWrap`, que construiría TODAS las filas de una biblioteca grande).
double _altoFilaCancion(Responsive r) => 46 + r.spacingS * 2;

Widget _construirHojaPlaylist(_HojaPlaylistState st, BuildContext context) {
  final r = Responsive(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final onBg = ColoresApp.enSuperficie(esOscuro);
  final bg = ColoresApp.superficie(esOscuro);
  final loc = AppLocalizations.of(context);
  // 86% de la pantalla: entra el teclado y la lista sigue teniendo aire.
  final altoMax = MediaQuery.sizeOf(context).height * 0.86;
  // Mínimo 120: el estado vacío necesita aire; el techo evita que la lista
  // se coma el resto de la hoja. Con 0 canciones no se mide por filas.
  final altoLista =
      st._canciones.isEmpty
          ? 120.0
          : (st._canciones.length * _altoFilaCancion(r)).clamp(
            120.0,
            altoMax * 0.5,
          );

  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: altoMax),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // El mismo fondo reactivo a la carátula que el karaoke y la cola.
            Positioned.fill(
              child: FondoReactivoPortada(
                caratula: st.caratulaFondo,
                esOscuro: esOscuro,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tiradorHoja(r, onBg),
                _cabeceraHoja(st, r, loc, onBg, esOscuro),
                _portadaYNombre(st, r, loc, onBg, esOscuro),
                _atajosCanciones(st, r, loc, onBg, esOscuro),
                Divider(height: 1, color: onBg.withValues(alpha: 0.06)),
                SizedBox(
                  height: altoLista,
                  child: _listaCanciones(st, r, loc, onBg),
                ),
                SizedBox(
                  height:
                      r.spacingM +
                      r.bottomPadding +
                      insetInferiorSistema(context),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
