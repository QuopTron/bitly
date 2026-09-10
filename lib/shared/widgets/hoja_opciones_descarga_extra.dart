// ─────────────────────────────────────────────────────────────
// hoja_opciones_descarga_extra.dart — PART de
// hoja_opciones_descarga.dart: piezas complementarias de la hoja —
// cabecera del ítem a descargar, banner de video/letras, botón de
// descargar con la calidad elegida, separador fino y badges
// (LOSSLESS / por defecto).
// Se conecta con: hoja_opciones_descarga.dart (misma library) +
// l10n + contenedor_vidrio.
// Parte del flujo: descargar (selección de calidad).
// ─────────────────────────────────────────────────────────────

part of 'hoja_opciones_descarga.dart';

/// Cabecera del ítem a descargar (nombre + artista + icono).
Widget _cabeceraItem(_HojaOpcionesDescargaState st, Responsive r,
    Color onBg, Color brillo) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                st.widget.item.name,
                style: TextStyle(
                  fontSize: r.subtitleSize + 1,
                  fontWeight: FontWeight.bold,
                  color: onBg,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (st.widget.item.artists != null &&
                  st.widget.item.artists!.isNotEmpty)
                Text(
                  st.widget.item.artists!,
                  style: TextStyle(
                    fontSize: r.footerSize,
                    color: onBg.withValues(alpha: 0.4),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        SizedBox(width: r.spacingM),
        Icon(Icons.download, size: r.subtitleSize + 4, color: brillo),
      ],
    ),
  );
}

/// Banner de info cuando hay video/letras activadas en ajustes.
Widget _bannerInfo(_HojaOpcionesDescargaState st, Responsive r,
    AppLocalizations loc, Color onBg, Color brillo) {
  final conVideo = st.widget.ajustes.videoHabilitado;
  final conLetras = st.widget.ajustes.letrasHabilitadas;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingM),
    child: ContenedorVidrio(
      borderRadius: 12,
      borderColor: brillo.withValues(alpha: 0.2),
      bgColor: brillo.withValues(alpha: 0.06),
      padding: EdgeInsets.all(r.spacingS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: r.footerSize, color: brillo),
          SizedBox(width: r.spacingXS),
          Expanded(
            child: Text(
              conVideo && conLetras
                  ? '${loc.setup.videoDownload} + ${loc.setup.lyricsDownload} (${loc.setup.settings})'
                  : conVideo
                      ? '${loc.setup.videoDownload} (${loc.setup.settings})'
                      : '${loc.setup.lyricsDownload} (${loc.setup.settings})',
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: onBg.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Botón principal de descargar con la calidad elegida.
Widget _botonDescargar(_HojaOpcionesDescargaState st, Responsive r,
    AppLocalizations loc, Color onBg, Color brillo) {
  final etiqueta = st._seleccionada != null
      ? '${loc.setup.downloaded}  ${_HojaOpcionesDescargaState._calidades[st._seleccionada]!.etiqueta}'
      : loc.setup.downloaded;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
    child: SizedBox(
      width: double.infinity,
      height: r.continueButtonHeight,
      child: ElevatedButton(
        onPressed: st._iniciar,
        style: ElevatedButton.styleFrom(
          backgroundColor: brillo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download, size: r.subtitleSize),
            SizedBox(width: r.spacingXS),
            Text(
              etiqueta,
              style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Separador vertical fino de la fila de detalles.
Widget _separador(Responsive r, Color onBg) {
  return Container(width: 1, height: 10, color: onBg.withValues(alpha: 0.08));
}

/// Badge pequeño (LOSSLESS / por defecto).
Widget _badge(Responsive r, Color fondo, String texto, Color colorTexto,
    {bool oscuro = false}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: oscuro ? 5 : 4, vertical: 1),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: r.footerSize - 2,
        fontWeight: FontWeight.w700,
        color: colorTexto,
        letterSpacing: 0.5,
      ),
    ),
  );
}