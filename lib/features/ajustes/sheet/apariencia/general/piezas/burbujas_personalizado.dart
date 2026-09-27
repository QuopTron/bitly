// ─────────────────────────────────────────────────────────────
// burbujas_personalizado.dart — La fila de burbujitas que elige QUÉ se está
// personalizando en Ajustes → Apariencia.
//
// Por qué existe: los bloques "personalizados" (espacios, tamaños y niveles
// del estilo con cover) apilaban un deslizador por componente. Con cinco
// controles juntos no se sabía cuál era cuál y la tarjeta quedaba larguísima.
// Ahora hay UNA burbujita por cosa (con su ícono y su nombre) y abajo se toca
// solo esa: se lee de un vistazo y en pantalla chica la fila se acomoda sola
// (Wrap: si no entra, baja de renglón en vez de desbordar).
//
// Es un widget propio y no una PART de settings_sheet_new porque no necesita
// nada del estado de la hoja: recibe las opciones, cuál está elegida y avisa
// del toque.
//
// Se conecta con: settings_sheet_appearance_diseno_avanzado.dart,
// settings_sheet_appearance_escala_avanzado.dart y
// settings_sheet_appearance_granular.dart (la montan).
// Parte del flujo: Ajustes → Apariencia → Personalizado.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../../shared/utilidades/plataforma/responsive.dart';

/// Una burbujita: su ícono y su nombre.
class OpcionBurbuja {
  final IconData icono;
  final String etiqueta;

  const OpcionBurbuja({required this.icono, required this.etiqueta});
}

/// Fila de burbujas seleccionables. La elegida va con relleno, glow y el texto
/// en blanco; las demás quedan apagadas.
class BurbujasPersonalizado extends StatelessWidget {
  final List<OpcionBurbuja> opciones;

  /// Índice de la burbuja elegida.
  final int seleccionada;

  /// Avisa cuando el usuario toca otra burbuja (no avisa si toca la misma).
  final ValueChanged<int> onSeleccion;

  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const BurbujasPersonalizado({
    super.key,
    required this.opciones,
    required this.seleccionada,
    required this.onSeleccion,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: r.spacingXS,
      runSpacing: r.spacingXS,
      children: [
        for (var i = 0; i < opciones.length; i++) _burbuja(context, i),
      ],
    );
  }

  Widget _burbuja(BuildContext context, int i) {
    final activa = i == seleccionada;
    final op = opciones[i];
    return Semantics(
      button: true,
      selected: activa,
      label: op.etiqueta,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!activa) onSeleccion(i);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: r.spacingS + 2,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            gradient:
                activa
                    ? LinearGradient(
                      colors: [
                        glowColor.withValues(alpha: 0.95),
                        glowColor.withValues(alpha: 0.55),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
            color: activa ? null : onBg.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  activa
                      ? Colors.white.withValues(alpha: 0.28)
                      : onBg.withValues(alpha: 0.09),
              width: activa ? 1.2 : 1,
            ),
            boxShadow:
                activa
                    ? [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.28),
                        blurRadius: 12,
                      ),
                    ]
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                op.icono,
                size: r.footerSize + 1,
                color: activa ? Colors.white : onBg.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              // El nombre se acorta con puntos suspensivos si la burbuja no
              // tiene ancho (pantalla chica o texto del sistema grande).
              Flexible(
                child: Text(
                  op.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.footerSize - 1,
                    fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                    color: activa ? Colors.white : onBg.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
