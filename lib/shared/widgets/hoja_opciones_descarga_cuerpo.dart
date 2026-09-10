// ─────────────────────────────────────────────────────────────
// hoja_opciones_descarga_cuerpo.dart — PART de
// hoja_opciones_descarga.dart: arma el cuerpo de la hoja — tirador,
// cabecera del ítem, secciones LOSSLESS/LOSSY con sus opciones,
// banner de video/letras y el botón de descargar. Aplica el fondo
// desenfocado cuando hay un track reproduciéndose.
// Se conecta con: hoja_opciones_descarga.dart (misma library) +
// colores_app + cubit_cola + l10n.
// Parte del flujo: descargar (selección de calidad).
// ─────────────────────────────────────────────────────────────

part of 'hoja_opciones_descarga.dart';

/// Cuerpo completo de la hoja con fondo vidrio si hay track activo.
Widget _cuerpoHoja(_HojaOpcionesDescargaState st) {
  final r = Responsive(st.context);
  final loc = AppLocalizations.of(st.context);
  final onBg = st.widget.esOscuro ? Colors.white : Colors.black;
  final brillo =
      st.widget.esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
  final hayTrack = sl<CubitCola>().state.tieneActual;
  final baseBg = st.widget.esOscuro
      ? const Color(0xFF1A1A1A)
      : const Color(0xFFF5F5F5);
  final fondoHoja = hayTrack ? baseBg.withValues(alpha: 0.70) : baseBg;

  Widget hoja = Container(
    margin: EdgeInsets.only(top: r.spacingXL * 2),
    decoration: BoxDecoration(
      color: fondoHoja,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      child: SingleChildScrollView(
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
            ..._HojaOpcionesDescargaState._clavesLossless
                .map((q) => _construirOpcion(st, r, q, brillo, onBg)),
            _cabeceraSeccion(r, 'LOSSY', onBg),
            ..._HojaOpcionesDescargaState._clavesLossy
                .map((q) => _construirOpcion(st, r, q, brillo, onBg)),
            SizedBox(height: r.spacingM),
            if (st.widget.ajustes.videoHabilitado ||
                st.widget.ajustes.letrasHabilitadas)
              _bannerInfo(st, r, loc, onBg, brillo),
            SizedBox(height: r.spacingM),
            _botonDescargar(st, r, loc, onBg, brillo),
            SizedBox(height: r.spacingXL),
          ],
        ),
      ),
    ),
  );
  if (hayTrack) {
    hoja = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: hoja,
      ),
    );
  }
  return hoja;
}