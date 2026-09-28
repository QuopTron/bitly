// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_build.dart — PART de tarjeta_grilla.dart: el
// `build` de la tarjeta — escucha la intensidad del estilo con cover,
// mide con LayoutBuilder y delega al cuerpo visual, extrayendo el color
// dominante del cover cuando hace falta.
// Se conecta con: tarjeta_grilla.dart (misma library) + inyeccion.
// Parte del flujo: feed, búsqueda, mi espacio (tarjetas de grilla).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_grilla.dart';

/// Construye la tarjeta de grilla reaccionando a las preferencias de estilo.
Widget _construirTarjetaGrilla(TarjetaGrilla t, BuildContext context) {
  // Escucha también la apariencia: la grilla repinta sola su separación y su
  // línea al mover el control, aunque la vista no se reconstruya (Mi Espacio).
  return ValueListenableBuilder<PreferenciasApariencia>(
    valueListenable: sl<ValueNotifier<PreferenciasApariencia>>(),
    builder:
        (context, _, _) => ValueListenableBuilder<PreferenciasEstilo>(
          valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
          builder: (context, prefs, _) {
            final r = Responsive(context);
            final esOscuro = Theme.of(context).brightness == Brightness.dark;
            final fondoFallback = ColoresApp.superficie(esOscuro);
            final fgTema = ColoresApp.enSuperficie(esOscuro);
            final ts = t.escalaTexto;
            // Las sombras con blur son el resto caro que queda en gama baja
            // (un `MaskFilter.blur` por tarjeta y por frame). Se consulta
            // TAMBIÉN `EfectosApp`, que es el interruptor que mueve el monitor
            // de frames midiendo el equipo real: sin esto el monitor apagaba
            // los desenfoques pero cada tarjeta seguía pagando su sombra.
            final efectosPesados =
                sl<ValueNotifier<PerfilRendimiento>>().value.efectosPesados &&
                EfectosApp.desenfoqueActivo;

            // Intensidad del color en las cards (0 = card del tema). Si ESTA
            // vista tiene una paleta del cofre, manda ella y tiene un piso.
            final nivel = TinteVista.nivelDeCards(context, prefs.cardsGrilla);
            // El color que puso la vista (si puso alguno) y el acento final:
            // la paleta MANDA sobre el color del cover.
            final acentoVista = TinteVista.acentoDe(context);
            final acento = TinteVista.acentoDeCards(context, t.colorDominante);

            // Líneas del modo "unido" (tipo Spotify): aparecen solas cuando la
            // separación llega al extremo (0). La de abajo separa filas; la de la
            // derecha, columnas (sólo si la grilla la pide, para no marcar el
            // borde externo). De fábrica no agregan nada.
            Widget conLineas(Widget child) {
              final opY = AparienciaEspacios.opacidadLineaYGrilla(context);
              final opX =
                  t.lineaDerecha
                      ? AparienciaEspacios.opacidadLineaXGrilla(context)
                      : 0.0;
              if (opY <= 0.001 && opX <= 0.001) return child;
              final linea = ColoresApp.borde(esOscuro);
              // Las líneas se meten el radio de la card a cada lado: caen sobre la
              // parte RECTA y acompañan las esquinas redondeadas (con radio 0 cruzan
              // de lado a lado). Curvado o recto, siempre queda parejo.
              final radio = AparienciaEspacios.radioCards(context);
              return Stack(
                children: [
                  child,
                  if (opY > 0.001)
                    Positioned(
                      left: radio,
                      right: radio,
                      bottom: 0,
                      child: Container(
                        key: const ValueKey('linea-separacion-y'),
                        // Hairline sutil: se siente sin ser una línea blanca dura.
                        height: 0.5,
                        color: linea.withValues(alpha: opY * 0.45),
                      ),
                    ),
                  if (opX > 0.001)
                    Positioned(
                      top: radio,
                      bottom: radio,
                      right: 0,
                      child: Container(
                        key: const ValueKey('linea-separacion-x'),
                        width: 0.5,
                        color: linea.withValues(alpha: opX * 0.45),
                      ),
                    ),
                ],
              );
            }

            return RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  /// El acento entra como capa de tinte con la opacidad de la
                  /// intensidad (la portada de fondo nunca se borra).
                  Widget cuerpo(Color? dominante) {
                    // Las letras van CON el color ya resuelto, y contra la base
                    // REAL de la card (`baseBajoCover`, el velo oscuro que
                    // existe en los dos temas): la superficie del tema es
                    // blanca en tema claro, y con ella el cálculo daba un fondo
                    // claro inexistente y las letras pasaban a negro sobre ese
                    // velo.
                    //
                    // Ojo: es el `fg` del BORDE y del piso de la card. El
                    // bloque de info sigue en blanco a propósito
                    // (tarjeta_grilla_info): el degradado inferior es opaco y
                    // le garantiza un fondo oscuro en cualquier tema.
                    final fg = EstiloHelper.textoDeTinte(
                      dominante,
                      ColoresApp.baseBajoCover(esOscuro),
                      nivel,
                      fgTema: fgTema,
                    );
                    return _cuerpoTarjeta(
                      t,
                      context,
                      constraints,
                      r,
                      esOscuro,
                      fondoFallback,
                      fg,
                      ts,
                      efectosPesados,
                      colorDominante: EstiloHelper.acentoDeTinte(
                        dominante,
                        nivel,
                      ),
                      nivel: nivel,
                    );
                  }

                  // Con paleta de vista NO se extrae el dominante del cover: ya
                  // sabemos el color.
                  if (nivel > 0 &&
                      t.colorDominante == null &&
                      acentoVista == null &&
                      t.coverUrl != null) {
                    return conLineas(
                      _TarjetaGrillaColorWrapper(
                        coverUrl: t.coverUrl!,
                        builder: cuerpo,
                      ),
                    );
                  }
                  return conLineas(cuerpo(acento));
                },
              ),
            );
          },
        ),
  );
}
