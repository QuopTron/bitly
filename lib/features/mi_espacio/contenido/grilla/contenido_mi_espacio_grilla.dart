// ─────────────────────────────────────────────────────────────
// contenido_mi_espacio_grilla.dart — PART de contenido_mi_espacio
// .dart: grilla de playlists/álbumes/artistas de Mi Espacio con
// TarjetaGrilla (columnas responsivas 2/3/4), botones de crear y
// mini-acciones en la pestaña Playlists, e insignia de origen en
// la esquina. Resuelve el estado de descarga del lote por clave
// exacta o escaneo source-agnostic con validación de proveedor.
// Se conecta con: contenido_mi_espacio.dart (misma library) +
// tarjeta_grilla + estrategia_descarga + cubits (vía callbacks).
// Parte del flujo: Home → Mi Espacio → grilla por pestaña.
// ─────────────────────────────────────────────────────────────

part of '../base/contenido_mi_espacio.dart';

/// Grilla de ítems (playlist/álbum/artista) con acciones de lote.
Widget _vistaGrilla(
  ContenidoMiEspacio c,
  BuildContext parentCtx,
  Responsive r,
  String tipo,
  Color onBg,
) {
  // Con la grilla cargada de color del cover, las cards se separan menos:
  // el espacio se cierra de a poco mientras crece la intensidad.
  final nivelGrilla = EstiloHelper.cardsGrilla(parentCtx);
  // La grilla escucha la apariencia: recalcula su separación al mover el
  // control aunque la vista no se reconstruya (era justo el caso de Mi
  // Espacio: había que salir y volver a entrar para ver el cambio).
  final gap = r.spacingXS * (1 - 0.5 * nivelGrilla);
  // El margen lateral también se cierra con la intensidad: la grilla con
  // color del cover aprovecha casi todo el ancho.
  final padH = r.spacingS * 0.5 * (1 - nivelGrilla) + 2 * nivelGrilla;
  // Separación personalizable (Ajustes → Apariencia → Diseño): el eje X
  // mueve el hueco entre columnas Y el margen izq/der; el eje Y, el hueco
  // entre filas Y el margen de arriba/abajo de la grilla. El multiplicador
  // de fábrica (1) reproduce el diseño de siempre.
  final factorX = AparienciaEspacios.espacioXGrilla(parentCtx);
  final factorY = AparienciaEspacios.espacioYGrilla(parentCtx);
  final sepX = gap * factorX;
  final sepY = gap * factorY;

  // SLIVERS en vez de `SingleChildScrollView` + `GridView(shrinkWrap: true)`.
  // Aquel combo era lo más caro de Mi Espacio: el scroll view construía el
  // contenido entero y, encima, `shrinkWrap` obliga a la grilla a medir TODOS
  // sus hijos para saber cuánto mide. Con una biblioteca grande eso son
  // cientos de tarjetas armadas al entrar a la pestaña, aunque el usuario vea
  // seis. Con slivers, cada celda se construye cuando entra en pantalla.
  return AnimatedBuilder(
    animation: AparienciaHelper.notifier(),
    builder:
        (_, _) => CustomScrollView(
          slivers: [
            if (tipo == 'playlist')
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  padH * factorX,
                  r.spacingS * factorY,
                  padH * factorX,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: r.spacingS),
                    child: Row(
                      children: [
                        _botonCrear(c, parentCtx, r, onBg),
                        if (c.onCreateDesdeAmados != null) ...[
                          SizedBox(width: r.spacingXS),
                          _botonMini(
                            c,
                            parentCtx,
                            r,
                            Icons.favorite,
                            AppLocalizations.of(parentCtx).setup.likedSongs,
                            c.onCreateDesdeAmados!,
                            onBg,
                            Colors.redAccent,
                          ),
                        ],
                        if (c.onCreateDesdeDescargados != null) ...[
                          SizedBox(width: r.spacingXS),
                          _botonMini(
                            c,
                            parentCtx,
                            r,
                            Icons.download_done,
                            AppLocalizations.of(
                              parentCtx,
                            ).setup.downloaded,
                            c.onCreateDesdeDescargados!,
                            onBg,
                            const Color(0xFF4CAF50),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                padH * factorX,
                tipo == 'playlist' ? 0 : r.spacingS * factorY,
                padH * factorX,
                r.spacingS * factorY + r.val(120, 100, 150),
              ),
              sliver: SliverLayoutBuilder(
                builder: (context, restricciones) {
                  // `crossAxisExtent` es el ancho REAL del hueco de la grilla
                  // (ya descontado el padding), así la cuenta de columnas sigue
                  // al ancho del box y no al de la pantalla. La cuenta vive en
                  // `columnasDeGrilla`, que además respeta el tope que el
                  // usuario le puso a ESTA vista (Ajustes → Apariencia → Vistas).
                  final columnas = columnasDeGrilla(
                    context,
                    restricciones.crossAxisExtent,
                  );
                  return SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnas,
                      mainAxisSpacing: sepY,
                      crossAxisSpacing: sepX,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: c.items.length,
                    itemBuilder:
                        (context, i) => _tarjetaDeItem(
                          c,
                          context,
                          tipo,
                          c.items[i],
                          // Línea divisoria del modo "unido" (todas menos la última).
                          lineaDerecha: i % columnas != columnas - 1,
                        ),
                  );
                },
              ),
            ),
          ],
        ),
  );
}
