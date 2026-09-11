// ─────────────────────────────────────────────────────────────
// indicador_red_barras.dart — PART de indicador_red.dart: medidor de
// 3 barras crecientes que traduce el nivel de calidad a una lectura
// visual inmediata (3 llenas = excelente, 0 = lenta/sin dato). Se
// mantiene monocromo para no romper la paleta de la app; el color
// problemático se aplica desde el padre en el icono.
// Se conecta con: indicador_red.dart (misma library) + servicio_calidad_red.
// Parte del flujo: Home → barra superior (indicador de red).
// ─────────────────────────────────────────────────────────────

part of 'indicador_red.dart';

/// Medidor de barras del nivel de calidad de red.
class BarrasCalidadRed extends StatelessWidget {
  final NivelRed nivel;
  final bool midiendo;
  final Color onBg;

  const BarrasCalidadRed({
    super.key,
    required this.nivel,
    required this.midiendo,
    required this.onBg,
  });

  /// Cuántas de las 3 barras van encendidas para [nivel].
  static int _barrasLlenas(NivelRed nivel) {
    switch (nivel) {
      case NivelRed.excelente:
        return 3;
      case NivelRed.buena:
        return 2;
      case NivelRed.regular:
        return 1;
      case NivelRed.mala:
      case NivelRed.desconocido:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final llenas = _barrasLlenas(nivel);
    final alturas = <double>[
      r.val(4, 3, 6),
      r.val(6, 4, 9),
      r.val(8, 5, 12),
    ];
    final colorActivo = colorNivelRed(nivel, TipoRed.otra, onBg);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < alturas.length; i++) ...[
          if (i > 0) SizedBox(width: r.val(2, 1.5, 3)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: r.val(2.5, 2, 3.5),
            height: alturas[i],
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: i < llenas
                  ? colorActivo
                  : onBg.withValues(alpha: 0.18),
            ),
          ),
        ],
      ],
    );
  }
}
