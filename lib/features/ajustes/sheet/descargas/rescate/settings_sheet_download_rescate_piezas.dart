// ─────────────────────────────────────────────────────────────
// settings_sheet_download_rescate_piezas.dart — PART de
// settings_sheet_new.dart: las piezas chicas de la tarjeta "Rescate sin
// pérdida": el texto de ayuda, un campo de la sección avanzada y el cuerpo
// avanzado completo (instancia propia de cobalt + guardado).
//
// Va aparte para que el árbol principal de la tarjeta se lea de un vistazo.
//
// Se conecta con: settings_sheet_download_rescate_build.dart (las usa) y
// ajustes_rescate (la validación de la URL).
// Parte del flujo: Ajustes → Descargas → rescate.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Texto de ayuda corto, con el mismo tono que el resto de Ajustes.
Widget _textoAyuda(
  String texto,
  Color onBg,
  Responsive r, {
  double alpha = 0.4,
}) => Text(
  texto,
  style: TextStyle(
    fontSize: r.footerSize - 2,
    color: onBg.withValues(alpha: alpha),
    height: 1.3,
  ),
);

/// Un campo de la sección avanzada (URL de la instancia o su clave).
Widget _campoRescate(
  TextEditingController ctrl,
  String label,
  String hint,
  Color onBg,
  Responsive r, {
  bool oculto = false,
  required VoidCallback onChanged,
  required VoidCallback onGuardar,
}) => TextField(
  controller: ctrl,
  obscureText: oculto,
  textInputAction: TextInputAction.done,
  autocorrect: false,
  onChanged: (_) => onChanged(),
  onSubmitted: (_) => onGuardar(),
  decoration: InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
  style: TextStyle(color: onBg, fontSize: r.subtitleSize - 1),
);

/// Los dos campos de la instancia propia + el guardado.
List<Widget> _cuerpoCobaltRescate({
  required TextEditingController instancia,
  required TextEditingController clave,
  required bool guardado,
  required StringsRescate t,
  required Color onBg,
  required Responsive r,
  required Color glowColor,
  required VoidCallback onGuardar,
  required VoidCallback onCampoCambiado,
}) {
  final url = AjustesRescate.normalizarInstancia(instancia.text);
  final invalida = url.isNotEmpty && !AjustesRescate.instanciaValida(url);
  return [
    SizedBox(height: r.spacingS),
    _campoRescate(
      instancia,
      t.instanciaLabel,
      t.instanciaHint,
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
    SizedBox(height: r.spacingS),
    _campoRescate(
      clave,
      t.tokenLabel,
      t.tokenHint,
      onBg,
      r,
      oculto: true,
      onChanged: onCampoCambiado,
      onGuardar: onGuardar,
    ),
    SizedBox(height: r.spacingS),
    _textoAyuda(t.cobaltAyuda, onBg, r, alpha: 0.35),
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
  ];
}
