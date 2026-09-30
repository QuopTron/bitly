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

/// Los campos avanzados (instancia propia de cobalt + proxy del rescate) y el
/// guardado.
List<Widget> _cuerpoCobaltRescate({
  required TextEditingController instancia,
  required TextEditingController clave,
  required TextEditingController proxy,
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
    SizedBox(height: r.spacingM),
    // Proxy del rescate: aplica a TODO el egreso de flac-rescue (espejos,
    // sitios raspables, canal sin pérdida y claves firmadas).
    _campoRescate(
      proxy,
      t.proxyLabel,
      t.proxyHint,
      onBg,
      r,
      onChanged: onCampoCambiado,
      onGuardar: onGuardar,
    ),
    if (proxy.text.trim().isNotEmpty &&
        !AjustesRescate.proxyValido(proxy.text)) ...[
      SizedBox(height: r.spacingXS),
      Text(
        t.proxyInvalido,
        style: TextStyle(
          fontSize: r.footerSize - 2,
          color: Colors.red.shade400,
        ),
      ),
    ],
    SizedBox(height: r.spacingS),
    _textoAyuda(t.proxyAyuda, onBg, r, alpha: 0.35),
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

/// El botón "Comprobar canales" y el informe que devuelve. El informe sale del
/// estado que los canales YA publicaron (no toca la red), así que se puede pedir
/// sin costo y sirve para saber si queda algo sano antes de esperar una canción.
class _BotonCanales extends StatelessWidget {
  final StringsRescate t;
  final Color onBg;
  final Responsive r;
  final Color glowColor;
  final bool consultando;
  final List<CanalRescate> canales;
  final String detalle;
  final bool agotado;
  final VoidCallback onProbar;

  const _BotonCanales({
    required this.t,
    required this.onBg,
    required this.r,
    required this.glowColor,
    required this.consultando,
    required this.canales,
    required this.detalle,
    required this.agotado,
    required this.onProbar,
  });

  /// Color del puntito según el veredicto (espejo de los estados de Go).
  Color _color(String estado) {
    switch (estado) {
      case DiagnosticoCanalesRescate.estadoOk:
        return Colors.green;
      case DiagnosticoCanalesRescate.estadoSinCuentas:
      case DiagnosticoCanalesRescate.estadoPausado:
      case DiagnosticoCanalesRescate.estadoSinSesion:
        return Colors.orange;
      default:
        return onBg.withValues(alpha: 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.spacingS),
        OutlinedButton.icon(
          onPressed: consultando ? null : onProbar,
          icon: const Icon(Icons.monitor_heart_rounded, size: 18),
          label: Text(consultando ? t.canalesComprobando : t.canalesBoton),
          style: OutlinedButton.styleFrom(
            foregroundColor: glowColor,
            side: BorderSide(color: glowColor.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (canales.isNotEmpty) ...[
          SizedBox(height: r.spacingS),
          Text(
            t.canalesTitulo,
            style: TextStyle(
              fontSize: r.footerSize - 1,
              color: onBg,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.spacingXS),
          for (final canal in canales)
            Padding(
              padding: EdgeInsets.only(bottom: r.spacingXS / 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 5, right: r.spacingXS),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _color(canal.estado),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${canal.nombre} · ${canal.estado}',
                          style: TextStyle(
                            fontSize: r.footerSize - 1,
                            color: onBg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (canal.detalle.isNotEmpty)
                          Text(
                            canal.detalle,
                            style: TextStyle(
                              fontSize: r.footerSize - 2,
                              color: onBg.withValues(alpha: 0.4),
                              height: 1.3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (agotado)
            Text(
              t.canalesAgotado,
              style: TextStyle(
                fontSize: r.footerSize - 2,
                color: Colors.orange,
              ),
            ),
        ] else if (detalle.isNotEmpty) ...[
          SizedBox(height: r.spacingXS),
          Text(
            detalle,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: onBg.withValues(alpha: 0.4),
            ),
          ),
        ],
      ],
    );
  }
}
