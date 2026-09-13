// ─────────────────────────────────────────────────────────────
// hoja_opciones_descarga_opcion.dart — PART de
// hoja_opciones_descarga.dart: fila de opción de calidad — radio,
// etiqueta con badge LOSSLESS/por defecto, tamaño estimado y
// bitrate. También la cabecera del ítem, el banner de video/letras
// y el botón de descargar.
// Se conecta con: hoja_opciones_descarga.dart (misma library) +
// l10n + contenedor_vidrio + colores_app.
// Parte del flujo: descargar (selección de calidad).
// ─────────────────────────────────────────────────────────────

part of 'hoja_opciones_descarga.dart';

/// Fila de opción de calidad con radio, badges y detalles.
Widget _construirOpcion(_HojaOpcionesDescargaState st, Responsive r,
    String q, Color brillo, Color onBg) {
  final meta = _HojaOpcionesDescargaState._calidades[q]!;
  final seleccionada = st._seleccionada == q;
  final esPorDefecto = q == st.widget.ajustes.calidadAudio;
  final tamanoStr = st._tieneDuracion ? (st._tamanos[q] ?? '') : null;
  final loc = AppLocalizations.of(st.context);

  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: 3),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => st._aplicar(() => st._seleccionada = q),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionada ? brillo : onBg.withValues(alpha: 0.07),
            width: seleccionada ? 1.2 : 0.5,
          ),
          color: seleccionada
              ? brillo.withValues(alpha: 0.08)
              : onBg.withValues(alpha: 0.02),
        ),
        padding: EdgeInsets.all(r.spacingM),
        child: Row(
          children: [
            _BotonRadio<String>(
              valor: q,
              grupoValor: st._seleccionada,
              colorActivo: brillo,
              alCambiar: (v) => st._aplicar(() => st._seleccionada = v),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        meta.etiqueta,
                        style: TextStyle(
                          fontSize: r.subtitleSize,
                          fontWeight:
                              seleccionada ? FontWeight.w700 : FontWeight.w500,
                          color: onBg,
                        ),
                      ),
                      if (meta.nivel == 'lossless') ...[
                        SizedBox(width: 6),
                        _badge(r, brillo, 'LOSSLESS', brillo, oscuro: true),
                      ],
                      if (esPorDefecto) ...[
                        SizedBox(width: 6),
                        _badge(
                          r,
                          onBg.withValues(alpha: 0.06),
                          loc.setup.calidadPorDefecto,
                          onBg.withValues(alpha: 0.35),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      if (tamanoStr != null && tamanoStr.isNotEmpty)
                        Text(
                          tamanoStr,
                          style: TextStyle(
                            fontSize: r.footerSize - 1,
                            fontWeight: FontWeight.w500,
                            color: onBg.withValues(alpha: 0.5),
                          ),
                        ),
                      if (tamanoStr != null && tamanoStr.isNotEmpty) ...[
                        SizedBox(width: 8),
                        _separador(r, onBg),
                        SizedBox(width: 8),
                      ],
                      Text(
                        '${meta.bitrate} kbps',
                        style: TextStyle(
                          fontSize: r.footerSize - 1,
                          color: onBg.withValues(alpha: 0.35),
                        ),
                      ),
                      if (!st._tieneDuracion) ...[
                        SizedBox(width: 8),
                        _separador(r, onBg),
                        SizedBox(width: 8),
                        Icon(
                          Icons.hourglass_bottom,
                          size: r.footerSize - 2,
                          color: onBg.withValues(alpha: 0.2),
                        ),
                        SizedBox(width: 4),
                        Text(
                          loc.setup.unknownSize,
                          style: TextStyle(
                            fontSize: r.footerSize - 1,
                            fontStyle: FontStyle.italic,
                            color: onBg.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

