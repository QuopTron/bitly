// ─────────────────────────────────────────────────────────────
// info_cancion_hoja.dart — PART de modal_info_cancion.dart:
// construye la hoja del modal de info de canción (carátula, título,
// artista, filas de datos y botón de compartir) sobre el mismo fondo
// reactivo a la carátula que el resto de los modales.
//
// Las filas son las etiquetas de `loc.infoCancion` (l10n) y los valores
// salen del ítem; si el usuario pidió traducir los datos, cada valor
// pasa por el mapa de traducciones antes de pintarse (ver
// servicio_traduccion_texto.dart). Las fechas y los códigos NO se
// traducen: no son texto de idioma.
//
// Se conecta con: modal_info_cancion.dart (misma library) +
// modal_info_cancion_widgets (_filaInfo/_botonCompartir) + fondo reactivo.
// Parte del flujo: Reproductor → info de canción.
// ─────────────────────────────────────────────────────────────

part of 'modal_info_cancion.dart';

/// Arma el contenido visual de la hoja sobre el fondo reactivo.
Widget _construirHojaInfoCancion({
  required BuildContext context,
  required Responsive r,
  required Color onBg,
  required AppLocalizations loc,
  required ItemFeed item,
  required String duracion,
  required Color fondoModal,
  required bool esOscuro,
  required Map<String, String>? traducciones,
  required bool traduciendo,
  required String? idiomaOrigen,
  required VoidCallback onTraducir,
}) {
  final i = loc.infoCancion;
  // Valor pintado: el traducido si hay, si no el original.
  String v(String original) => traducciones?[original] ?? original;

  // Lado de la carátula: proporcional al ancho pero ACOTADO. Sin tope, en una
  // pantalla ancha o de DPI alto (PC/tablet) la carátula crecía al 50% del
  // ancho y la hoja quedaba deformada — el diseño debe verse igual en
  // cualquier densidad.
  final ladoCaratula = (r.width * 0.5).clamp(120.0, 220.0);
  return Container(
    margin: EdgeInsets.only(top: r.spacingXL * 2),
    decoration: BoxDecoration(
      color: fondoModal,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        // La misma carátula desenfocada (o su color) que usan karaoke,
        // cola, playlist y "agregar a".
        Positioned.fill(
          child: FondoReactivoPortada(
            caratula: item.coverUrl,
            esOscuro: esOscuro,
          ),
        ),
        SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: r.spacingM),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.spacingXL),
              if (item.coverUrl != null && item.coverUrl!.isNotEmpty)
                ImagenPortada(
                  coverUrl: item.coverUrl,
                  ancho: ladoCaratula,
                  alto: ladoCaratula,
                  radioBorde: 16,
                  fallback: Container(
                    width: ladoCaratula,
                    height: ladoCaratula,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.music_note,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              SizedBox(height: r.spacingL),
              Text(
                v(item.name),
                style: TextStyle(
                  fontSize: r.subtitleSize + 2,
                  fontWeight: FontWeight.bold,
                  color: onBg,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: r.spacingXS),
              Text(
                item.artists == null ? '' : v(item.artists!),
                style: TextStyle(
                  fontSize: r.subtitleSize,
                  color: onBg.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: r.spacingL),
              // ── Cabecera de la sección + botón de traducir los datos ──
              _cabeceraInfo(
                context,
                r,
                onBg,
                loc,
                traduciendo,
                traducciones != null,
                onTraducir,
              ),
              _filaInfo(r, onBg, Icons.music_note, i.campoCancion, v(item.name)),
              if (item.artists != null && item.artists!.isNotEmpty)
                _filaInfo(r, onBg, Icons.person_outline, i.campoArtista, v(item.artists!)),
              if (item.albumName != null && item.albumName!.isNotEmpty)
                _filaInfo(r, onBg, Icons.album, i.campoAlbum, v(item.albumName!)),
              _filaInfo(r, onBg, Icons.timer_outlined, i.campoDuracion, duracion),
              if (item.type != 'track')
                _filaInfo(
                  r,
                  onBg,
                  Icons.category_outlined,
                  loc.setup.trackType,
                  item.type,
                ),
              // Fecha e ISRC: son datos del proveedor, no texto de idioma, así
              // que van tal cual (no entran en la traducción).
              if (item.releaseDate != null && item.releaseDate!.isNotEmpty)
                _filaInfo(r, onBg, Icons.event_outlined, i.campoLanzamiento, item.releaseDate!),
              if (item.isrc != null && item.isrc!.isNotEmpty)
                _filaInfo(r, onBg, Icons.fingerprint, i.campoIsrc, item.isrc!),
              if (item.source != null && item.source!.isNotEmpty)
                _filaInfo(r, onBg, Icons.dns_outlined, i.campoOrigen, item.source!),
              if (traducciones != null)
                _pieTraduccion(r, onBg, loc, idiomaOrigen, onTraducir),
              SizedBox(height: r.spacingL),
              _botonCompartir(context, r, onBg, item),
              // + menú de navegación del sistema (la hoja se ancla al borde).
              SizedBox(height: r.spacingXL + insetInferiorSistema(context)),
            ],
          ),
        ),
      ],
    ),
  );
}
