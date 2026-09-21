// ─────────────────────────────────────────────────────────────
// hoja_opciones_descarga_cuerpo.dart — PART de
// hoja_opciones_descarga.dart: arma el cuerpo de la hoja — tirador,
// cabecera del ítem, secciones LOSSLESS/LOSSY con sus opciones,
// banner de video/letras y el botón de descargar, sobre el mismo fondo
// reactivo a la carátula que el resto de los modales.
// Se conecta con: hoja_opciones_descarga.dart (misma library) +
// colores_app + fondo reactivo + l10n.
// Parte del flujo: descargar (selección de calidad).
// ─────────────────────────────────────────────────────────────

part of 'hoja_opciones_descarga.dart';

/// Cuerpo completo de la hoja con el fondo reactivo a la carátula.
Widget _cuerpoHoja(_HojaOpcionesDescargaState st) {
  final r = Responsive(st.context);
  final loc = AppLocalizations.of(st.context);
  final onBg = st.widget.esOscuro ? Colors.white : Colors.black;
  final brillo =
      st.widget.esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
  final baseBg =
      st.widget.esOscuro ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

  return Container(
    margin: EdgeInsets.only(top: r.spacingXL * 2),
    decoration: BoxDecoration(
      color: baseBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        // El mismo fondo que karaoke, cola, playlist e info de canción.
        Positioned.fill(
          child: FondoReactivoPortada(
            caratula: st.widget.item.coverUrl,
            esOscuro: st.widget.esOscuro,
          ),
        ),
        SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: r.spacingM),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.spacingL),
              _cabeceraItem(st, r, onBg, brillo),
              SizedBox(height: r.spacingM),
              _cabeceraSeccion(r, 'LOSSLESS', onBg),
              ..._HojaOpcionesDescargaState._clavesLossless.map(
                (q) => _construirOpcion(st, r, q, brillo, onBg),
              ),
              _cabeceraSeccion(r, 'LOSSY', onBg),
              ..._HojaOpcionesDescargaState._clavesLossy.map(
                (q) => _construirOpcion(st, r, q, brillo, onBg),
              ),
              SizedBox(height: r.spacingM),
              if (st.widget.ajustes.videoHabilitado ||
                  st.widget.ajustes.letrasHabilitadas)
                _bannerInfo(st, r, loc, onBg, brillo),
              SizedBox(height: r.spacingM),
              _botonDescargar(st, r, loc, onBg, brillo),
              // + menú de navegación del sistema: el botón Descargar vive al
              // pie de la hoja, que se ancla al borde físico de la pantalla.
              SizedBox(height: r.spacingXL + insetInferiorSistema(st.context)),
            ],
          ),
        ),
      ],
    ),
  );
}
