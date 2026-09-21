// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_granular_fila.dart — PART de
// settings_sheet_new.dart: la fila que abre y cierra "Avanzado".
//
// Es la cabecera tocable del desplegable: el ícono de ajustes finos, el
// título con su explicación y el chevron que gira al abrir. No tiene estado
// propio: recibe si está abierto y avisa del toque.
//
// Se conecta con: settings_sheet_appearance_granular.dart (la monta).
// Parte del flujo: Ajustes → Apariencia → Estilo con cover → Avanzado.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// La fila que abre y cierra "Avanzado", con el chevron que gira.
class _FilaAvanzado extends StatelessWidget {
  final String titulo;
  final String ayuda;
  final bool abierto;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onTap;

  const _FilaAvanzado({
    required this.titulo,
    required this.ayuda,
    required this.abierto,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            Icons.tune_rounded,
            color: abierto ? glowColor : onBg.withValues(alpha: 0.5),
            size: r.footerSize + 2,
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: r.footerSize,
                    fontWeight: FontWeight.w600,
                    color: onBg.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  ayuda,
                  style: TextStyle(
                    fontSize: r.footerSize - 2,
                    color: onBg.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          AnimatedRotation(
            turns: abierto ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: onBg.withValues(alpha: 0.5),
              size: r.subtitleSize,
            ),
          ),
        ],
      ),
    );
  }
}
