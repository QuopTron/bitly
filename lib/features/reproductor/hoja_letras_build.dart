// PART de hoja_letras.dart: build del modal karaoke.

part of 'hoja_letras.dart';

Widget _construirHoja(
  _HojaLetrasState st,
  BuildContext context,
  EstadoAudioReproductor reproductor,
) {
  final r = Responsive(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final alto = MediaQuery.sizeOf(context).height;
  final caratula = st._resolverCaratula();

  var activa = 0;
  if (st._lineas.isNotEmpty) {
    for (var i = st._lineas.length - 1; i >= 0; i--) {
      if (reproductor.posicion >= st._lineas[i].tiempo) {
        activa = i;
        break;
      }
    }
  }

  final fondo =
      esOscuro ? const Color(0xFF141414) : const Color(0xFFF6F6F6);

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
        Positioned.fill(child: _fondoCaratula(caratula, esOscuro)),
        Positioned.fill(
          child: Container(
            color: (esOscuro ? Colors.black : Colors.white)
                .withValues(alpha: esOscuro ? 0.68 : 0.5),
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (esOscuro ? Colors.white : Colors.black)
                    .withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.spacingS),
            _cabeceraHoja(st, context, r, esOscuro),
            const SizedBox(height: 2),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<PaletaPortada?>(
                future: st._paletaFuture,
                builder: (context, snap) {
                  final paleta = snap.data;
                  return st._lineas.isNotEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            _sincronizarScroll(
                                st, activa, constraints.maxHeight);
                            return ListView.builder(
                              controller: st._scroll,
                              padding: EdgeInsets.symmetric(
                                horizontal: r.spacingXL,
                              ),
                              itemExtent: 56,
                              itemCount: st._lineas.length,
                              itemBuilder: (context, i) => _lineaKaraoke(
                                st,
                                r,
                                esOscuro,
                                i,
                                activa,
                                paleta,
                                reproductor.posicion,
                              ),
                            );
                          },
                        )
                      : _letrasPlanas(st, r, esOscuro);
                },
              ),
            ),
            const Divider(height: 1),
            _filaTransporte(context, r, esOscuro, reproductor),
            SizedBox(height: r.spacingS),
          ],
        ),
      ],
    ),
  );
}

Widget _cabeceraHoja(
  _HojaLetrasState st,
  BuildContext context,
  Responsive r,
  bool esOscuro,
) {
  final fg = esOscuro ? Colors.white : Colors.black;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingL),
    child: Row(
      children: [
        Icon(Icons.lyrics_rounded, size: r.subtitleSize + 2, color: fg),
        SizedBox(width: r.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                st.widget.track.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: r.subtitleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                st.widget.track.artists ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.5),
                  fontSize: r.footerSize,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: fg),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}