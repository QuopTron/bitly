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
  return AnimatedBuilder(
    animation: AparienciaHelper.notifier(),
    builder:
        (_, _) => LayoutBuilder(
          builder: (context, constraints) {
            final disponible = constraints.maxWidth - 2 * r.spacingS * 0.5;
            // En pantallas anchas (escritorio) 6 columnas, en tablet 4 y en
            // móvil 3/2 — el box de PC se estira más que antes (1120px).
            final columnas =
                disponible > 1000
                    ? 6
                    : disponible > 700
                    ? 4
                    : disponible > 340
                    ? 3
                    : 2;
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
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                padH * factorX,
                r.spacingS * factorY,
                padH * factorX,
                r.spacingS * factorY + r.val(120, 100, 150),
              ),
              child: Column(
                children: [
                  if (tipo == 'playlist')
                    Padding(
                      padding: EdgeInsets.only(bottom: r.spacingS),
                      child: Row(
                        children: [
                          _botonCrear(c, context, r, onBg),
                          if (c.onCreateDesdeAmados != null) ...[
                            SizedBox(width: r.spacingXS),
                            _botonMini(
                              c,
                              context,
                              r,
                              Icons.favorite,
                              AppLocalizations.of(context).setup.likedSongs,
                              c.onCreateDesdeAmados!,
                              onBg,
                              Colors.redAccent,
                            ),
                          ],
                          if (c.onCreateDesdeDescargados != null) ...[
                            SizedBox(width: r.spacingXS),
                            _botonMini(
                              c,
                              context,
                              r,
                              Icons.download_done,
                              AppLocalizations.of(context).setup.downloaded,
                              c.onCreateDesdeDescargados!,
                              onBg,
                              const Color(0xFF4CAF50),
                            ),
                          ],
                        ],
                      ),
                    ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                  ),
                ],
              ),
            );
          },
        ),
  );
}
