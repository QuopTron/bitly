// PART de hoja_letras.dart: build del modal karaoke.

part of 'hoja_letras.dart';

/// Separador del modal karaoke: neutro y explícito (igual que el resto de
/// los divisores de la app, así no hereda un color raro del tema).
Widget _divisorLetras(bool esOscuro) => Divider(
  height: 1,
  color: (esOscuro ? Colors.white : Colors.black).withValues(alpha: 0.10),
);

Widget _construirHoja(
  _HojaLetrasState st,
  BuildContext context,
  EstadoAudioReproductor reproductor,
) {
  final r = Responsive(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final alto = MediaQuery.sizeOf(context).height;
  final caratula = st._resolverCaratula();

  // Posición del karaoke: la del reproductor con el desfase (0.5s) para que el
  // resaltado siga al cantante en vez de anticiparlo (ver _posicionLetras).
  final posicion = _posicionLetras(reproductor.posicion);
  var activa = 0;
  if (st._lineas.isNotEmpty) {
    for (var i = st._lineas.length - 1; i >= 0; i--) {
      if (posicion >= st._lineas[i].tiempo) {
        activa = i;
        break;
      }
    }
  }

  final fondo = esOscuro ? const Color(0xFF141414) : const Color(0xFFF6F6F6);

  return Container(
    // Modal de media pantalla (Spotify-style): no tapa el player.
    height: (alto * 0.5).clamp(340.0, alto * 0.62),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        // Fondo reactivo a la carátula (incluye su propio velo de tema).
        Positioned.fill(
          child: st._memo(
            'fondo|$caratula|$esOscuro',
            () => _fondoCaratula(caratula, esOscuro),
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (esOscuro ? Colors.white : Colors.black).withValues(
                  alpha: 0.25,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.spacingS),
            // Cabecera memoizada: no depende de la posición, así que no tiene
            // por qué reconstruirse ~25 veces por segundo.
            st._memo(
              'cabecera|${r.subtitleSize}|${r.footerSize}|$esOscuro|'
              '${st._traduciendo}|${st._idiomaDestino}|'
              '${st._traducciones != null}',
              () => _cabeceraHoja(st, context, r, esOscuro),
            ),
            const SizedBox(height: 2),
            // Color explícito (como el resto de la app): sin él el Divider
            // hereda el del tema y no queda neutro.
            _divisorLetras(esOscuro),
            Expanded(
              child: FutureBuilder<PaletaPortada?>(
                future: st._paletaFuture,
                builder: (context, snap) {
                  final paleta = snap.data;
                  // Firma de lo que define el aspecto de las líneas NO activas:
                  // activa, tema, tamaños de fuente y acento de la paleta.
                  // Mientras no cambie, el widget de cada línea inactiva se
                  // reutiliza tal cual y Flutter se salta su subárbol: sin esto
                  // el texto de TODAS las líneas visibles se volvía a maquetar
                  // en cada tick de posición (~25/s).
                  final firmaLineas =
                      '$activa|$esOscuro|${r.subtitleSize}|${r.titleSize}|'
                      '${paleta?.vibrante.toARGB32()}';
                  // La letra ocupa todo y el mini karaoke de la traducción queda
                  // pegado abajo; los dos comparten la paleta de la portada.
                  return Column(
                    children: [
                      Expanded(
                        child:
                            st._lineas.isNotEmpty
                                ? LayoutBuilder(
                                  builder: (context, constraints) {
                                    _sincronizarScroll(
                                      st,
                                      activa,
                                      constraints.maxHeight,
                                    );
                                    return ListView.builder(
                                      controller: st._scroll,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: r.spacingXL,
                                      ),
                                      // Sin itemExtent fijo: cada línea mide su
                                      // alto real (las largas envuelven en vez de
                                      // recortarse) y el centrado va por la
                                      // posición real de la línea activa.
                                      itemCount: st._lineas.length,
                                      itemBuilder: (context, i) {
                                        // La activa se reconstruye siempre (su
                                        // relleno sigue la posición); las demás
                                        // se sirven memoizadas.
                                        if (i == activa) {
                                          return KeyedSubtree(
                                            key: st._claveActiva,
                                            child: _lineaKaraoke(
                                              st,
                                              r,
                                              esOscuro,
                                              i,
                                              activa,
                                              paleta,
                                              posicion,
                                            ),
                                          );
                                        }
                                        return st._memoLinea(
                                          '$firmaLineas|$i',
                                          () => _lineaKaraoke(
                                            st,
                                            r,
                                            esOscuro,
                                            i,
                                            activa,
                                            paleta,
                                            posicion,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                )
                                : _letrasPlanas(st, r, esOscuro),
                      ),
                      _miniKaraoke(st, r, esOscuro, paleta, activa, posicion),
                    ],
                  );
                },
              ),
            ),
            _divisorLetras(esOscuro),
            _filaTransporte(context, r, esOscuro, reproductor),
            SizedBox(height: r.spacingS),
          ],
        ),
      ],
    ),
  );
}
