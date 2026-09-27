// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_diseno_deslizador.dart — PART de
// settings_sheet_new.dart: el deslizador con etiqueta y valor a la
// vista que usan el redondeo de cards, la separación X/Y del bloque
// "Diseño" y los controles de intensidad del estilo con cover (estos
// últimos con 100 pasos, o sea de a 1%).
// Se conecta con: settings_sheet_appearance_diseno.dart (misma library).
// Parte del flujo: Ajustes → Apariencia → Diseño.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Deslizador con etiqueta y valor a la vista.
class _Deslizador extends StatelessWidget {
  final String etiqueta;
  final double valor;

  /// Mínimo del deslizador. Por defecto 0 (separaciones), pero la escala de
  /// letras y de iconos arranca en 0.85: sin esto el pulgar llegaría al 0%,
  /// el valor se acotaría igual y quedaría rebotando contra el borde.
  final double minimo;
  final double maximo;
  final ValueChanged<double> onChanged;

  /// Cómo se muestra el valor de la derecha. Por defecto, el del bloque
  /// Diseño (multiplicador con una decimal, o píxeles según el máximo); el
  /// estilo con cover pasa el suyo para mostrarlo en porcentaje.
  final String Function(double)? formato;

  /// Pasos del deslizador. El estilo con cover usa 100: la barra avanza de a
  /// 1% y el número de la derecha es siempre un entero, así el usuario ve
  /// exactamente qué porcentaje está eligiendo.
  final int? divisiones;

  const _Deslizador({
    required this.etiqueta,
    required this.valor,
    required this.maximo,
    required this.onChanged,
    this.minimo = 0,
    this.formato,
    this.divisiones,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final glow = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    // Los multiplicadores se muestran con una decimal (1.0 = diseño actual)
    // y el redondeo en píxeles enteros: lo que el usuario ve es lo que aplica.
    final texto =
        formato?.call(valor) ??
        (maximo == PreferenciasApariencia.maxEspacio
            ? valor.toStringAsFixed(1)
            : '${valor.round()} px');

    return Row(
      children: [
        SizedBox(
          width: r.width * 0.24,
          child: Text(
            etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: r.footerSize, color: onBg),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: glow,
              thumbColor: glow,
              inactiveTrackColor: onBg.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: valor.clamp(minimo, maximo),
              min: minimo,
              max: maximo,
              divisions: divisiones,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: r.width * 0.12,
          child: Text(
            texto,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: r.footerSize - 1,
              fontWeight: FontWeight.w700,
              color: glow,
            ),
          ),
        ),
      ],
    );
  }
}
