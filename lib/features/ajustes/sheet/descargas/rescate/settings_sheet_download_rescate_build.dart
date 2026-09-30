// ─────────────────────────────────────────────────────────────
// settings_sheet_download_rescate_build.dart — PART de
// settings_sheet_new.dart: el `build` de la tarjeta "Rescate sin pérdida"
// (encabezado, ayuda, switch de sitios y el desplegable Avanzado).
//
// Recibe TODO por parámetro para que la tarjeta se pueda leer de un vistazo y
// para que el estado no tenga que saber de estilos (mismo criterio que el
// formulario de Soulseek). Las piezas chicas van en
// settings_sheet_download_rescate_piezas.dart.
//
// Se conecta con: settings_sheet_download_rescate.dart (la lógica) y las filas
// compartidas de Descargas (_downloadHeaderRow, _downloadSwitchRow).
// Parte del flujo: Ajustes → Descargas → rescate.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// La tarjeta completa: sitios raspables + (avanzado) instancia de cobalt.
Widget _construirTarjetaRescate({
  required BuildContext context,
  required TextEditingController instancia,
  required TextEditingController clave,
  required TextEditingController proxy,
  required bool sitios,
  required bool relay,
  required bool espejos,
  required bool arcod,
  required List<CanalRescate> canales,
  required String detalleCanales,
  required bool agotado,
  required bool consultandoCanales,
  required bool abierto,
  required bool guardado,
  required Color glowColor,
  required ValueChanged<bool> onSitios,
  required ValueChanged<bool> onRelay,
  required ValueChanged<bool> onEspejos,
  required ValueChanged<bool> onArcod,
  required VoidCallback onProbarCanales,
  required VoidCallback onToggleAvanzado,
  required VoidCallback onGuardar,
  required VoidCallback onCampoCambiado,
}) {
  final r = Responsive(context);
  final onBg = ColoresApp.enSuperficie(
    Theme.of(context).brightness == Brightness.dark,
  );
  final t = AppLocalizations.of(context).rescate;
  return ContenedorVidrio(
    borderRadius: 16,
    borderColor: onBg.withValues(alpha: 0.08),
    bgColor: onBg.withValues(alpha: 0.03),
    padding: EdgeInsets.all(r.spacingM),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _downloadHeaderRow(
          Icons.verified_rounded,
          t.titulo,
          onBg,
          r,
          glowColor,
        ),
        _textoAyuda(t.ayuda, onBg, r, alpha: 0.4),
        SizedBox(height: r.spacingM),
        _downloadSwitchRow(
          context,
          icon: Icons.travel_explore_rounded,
          label: t.sitiosLabel,
          value: sitios,
          onChanged: onSitios,
          glowColor: glowColor,
          onBg: onBg,
        ),
        _textoAyuda(t.sitiosAyuda, onBg, r, alpha: 0.35),
        SizedBox(height: r.spacingS),
        _downloadSwitchRow(
          context,
          icon: Icons.hub_rounded,
          label: t.relayLabel,
          value: relay,
          onChanged: onRelay,
          glowColor: glowColor,
          onBg: onBg,
        ),
        _textoAyuda(t.relayAyuda, onBg, r, alpha: 0.35),
        SizedBox(height: r.spacingS),
        _downloadSwitchRow(
          context,
          icon: Icons.cell_tower_rounded,
          label: t.espejosLabel,
          value: espejos,
          onChanged: onEspejos,
          glowColor: glowColor,
          onBg: onBg,
        ),
        _textoAyuda(t.espejosAyuda, onBg, r, alpha: 0.35),
        SizedBox(height: r.spacingS),
        _downloadSwitchRow(
          context,
          icon: Icons.cloud_download_rounded,
          label: t.arcodLabel,
          value: arcod,
          onChanged: onArcod,
          glowColor: glowColor,
          onBg: onBg,
        ),
        _textoAyuda(t.arcodAyuda, onBg, r, alpha: 0.35),
        SizedBox(height: r.spacingS),
        _FilaAvanzado(
          titulo: t.avanzadoTitulo,
          ayuda: t.avanzadoAyuda,
          abierto: abierto,
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          onTap: onToggleAvanzado,
        ),
        _BotonCanales(
          t: t,
          onBg: onBg,
          r: r,
          glowColor: glowColor,
          consultando: consultandoCanales,
          canales: canales,
          detalle: detalleCanales,
          agotado: agotado,
          onProbar: onProbarCanales,
        ),
        if (abierto)
          ..._cuerpoCobaltRescate(
            instancia: instancia,
            clave: clave,
            proxy: proxy,
            guardado: guardado,
            t: t,
            onBg: onBg,
            r: r,
            glowColor: glowColor,
            onGuardar: onGuardar,
            onCampoCambiado: onCampoCambiado,
          ),
      ],
    ),
  );
}
