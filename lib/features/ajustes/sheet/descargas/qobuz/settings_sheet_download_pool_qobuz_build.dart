// ─────────────────────────────────────────────────────────────
// settings_sheet_download_pool_qobuz_build.dart — PART de
// settings_sheet_new.dart: el `build` de la tarjeta "Sesiones de Qobuz"
// (encabezado, fila de estado, botón de revisar y el campo de URL).
//
// Recibe TODO por parámetro para que la tarjeta se lea de un vistazo y el
// estado no tenga que saber de estilos (mismo criterio que la tarjeta del
// rescate). Las piezas chicas van en
// settings_sheet_download_pool_qobuz_piezas.dart.
//
// Se conecta con: settings_sheet_download_pool_qobuz.dart (la lógica), las
// filas compartidas de Descargas (_downloadHeaderRow), el texto de ayuda del
// rescate (_textoAyuda, _campoRescate) y strings_pool_qobuz (los textos).
// Parte del flujo: Ajustes → Descargas → sesiones de Qobuz.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// La tarjeta completa: estado del pool + URL de la fuente.
Widget _construirTarjetaPoolQobuz({
  required BuildContext context,
  required TextEditingController url,
  required String estado,
  required String detalle,
  required bool consultando,
  required bool guardado,
  required Color glowColor,
  required VoidCallback onGuardar,
  required VoidCallback onRevisar,
  required VoidCallback onCampoCambiado,
}) {
  final r = Responsive(context);
  final onBg = ColoresApp.enSuperficie(
    Theme.of(context).brightness == Brightness.dark,
  );
  final t = AppLocalizations.of(context).poolQobuz;
  final color = _colorEstadoPoolQobuz(estado, onBg);
  // El texto del backend manda si vino: ya explica el matiz real.
  final texto = detalle.isNotEmpty ? detalle : t.detalleEstado(estado);
  final invalida =
      url.text.trim().isNotEmpty && !AjustesPoolQobuz.urlValida(url.text);
  return ContenedorVidrio(
    borderRadius: 16,
    borderColor: onBg.withValues(alpha: 0.08),
    bgColor: onBg.withValues(alpha: 0.03),
    padding: EdgeInsets.all(r.spacingM),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _downloadHeaderRow(
          Icons.cloud_sync_rounded,
          t.titulo,
          onBg,
          r,
          glowColor,
        ),
        _textoAyuda(t.ayuda, onBg, r, alpha: 0.4),
        SizedBox(height: r.spacingM),
        _filaEstadoPoolQobuz(
          t: t,
          estado: estado,
          color: color,
          texto: texto,
          onBg: onBg,
          r: r,
        ),
        SizedBox(height: r.spacingXS),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: consultando ? null : onRevisar,
            // Revisando: el hueco del ícono de refrescar se vuelve un bloque
            // del mismo tamaño (el texto de al lado ya dice "Revisando…").
            icon: consultando
                ? const EsqueletoMarca(lado: 16, radioBorde: 4)
                : const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              consultando ? t.revisando : t.revisar,
              style: TextStyle(fontSize: r.footerSize - 1),
            ),
          ),
        ),
        SizedBox(height: r.spacingS),
        _campoRescate(
          url,
          t.urlLabel,
          t.urlHint,
          onBg,
          r,
          onChanged: onCampoCambiado,
          onGuardar: onGuardar,
        ),
        // Aviso inline: nada de modales encima del sheet de Ajustes.
        if (invalida) ...[
          SizedBox(height: r.spacingXS),
          Text(
            t.urlInvalida,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: Colors.red.shade400,
            ),
          ),
        ],
        SizedBox(height: r.spacingXS),
        _textoAyuda(t.urlAyuda, onBg, r, alpha: 0.35),
        SizedBox(height: r.spacingS),
        Row(
          children: [
            FilledButton(
              onPressed: onGuardar,
              style: FilledButton.styleFrom(
                backgroundColor: glowColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                t.guardar,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (guardado) ...[
              SizedBox(width: r.spacingS),
              const Icon(Icons.check_rounded, size: 18, color: Colors.green),
              SizedBox(width: r.spacingXS),
              Text(
                t.guardado,
                style: TextStyle(fontSize: r.footerSize - 1, color: onBg),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
