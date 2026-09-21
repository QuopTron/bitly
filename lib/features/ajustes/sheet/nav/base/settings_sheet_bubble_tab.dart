// ─────────────────────────────────────────────────────────────
// settings_sheet_bubble_tab.dart — Burbuja circular de navegación del
// sheet de Ajustes: círculo con glow, icono y etiqueta chica; la activa
// lleva relleno, anillo y punto.
//
// Posicionamiento: el círculo y la etiqueta van cada uno en un slot de
// ancho completo. Así las cinco burbujas quedan en el mismo eje (antes
// "Rendimiento" y "Estadísticas" se veían corridas porque cada columna
// se centraba sobre su propio ancho de etiqueta) y el conjunto aguanta// cualquier DPI o escala de texto del sistema.
//
// El ícono sale de `_iconosPestanas` y la etiqueta de `StringsAjustes`
// (mismo índice): así se traduce sin tocar este widget.
//
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: Ajustes → fila de burbujas (tabs).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Burbuja circular: círculo con el icono y una etiqueta chica debajo.
class _BubbleTab extends StatelessWidget {
  final int index;
  final bool active;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onTap;

  const _BubbleTab({
    required this.index,
    required this.active,
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
      child: AnimatedScale(
        scale: active ? 1.0 : 0.92,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Slot de ancho completo: todas las burbujas comparten eje. El
            // mininumerito se cuelga de la burbuja que tiene algo pendiente:
            // Apariencia (los regalos del cofre) y Conexión (el aviso de
            // novedades). Cada uno lee su contador; si está en 0 no se pinta.
            SizedBox(
              width: double.infinity,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _circulo(),
                    if (index == _indiceApariencia)
                      _numerito(AparienciaHelper.regalos),
                    if (index == _indiceConexion) _numerito(novedadesConexion),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // La etiqueta se encoge si la burbuja es angosta (pantalla
                // chica o texto del sistema grande) en vez de desbordar.
                child: Text(
                  AppLocalizations.of(context).ajustes.pestanas[index],
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: r.footerSize - 2,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? glowColor : onBg.withValues(alpha: 0.45),
                    letterSpacing: active ? 0.2 : 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Punto que marca la pestaña activa.
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: active ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: glowColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mininumerito con lo pendiente de esa burbuja. Se esconde solo cuando
  /// la cuenta es 0, así no queda un "0" colgado.
  Widget _numerito(ValueListenable<int> contador) =>
      ValueListenableBuilder<int>(
        valueListenable: contador,
        builder: (context, n, _) {
          if (n <= 0) return const SizedBox.shrink();
          return Positioned(
            top: -3,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: glowColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                n > 9 ? '9+' : '$n',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.footerSize - 3,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.enSuperficie(false),
                ),
              ),
            ),
          );
        },
      );

  /// Círculo con glow: relleno, anillo y sombra cuando está activa.
  Widget _circulo() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            active
                ? LinearGradient(
                  colors: [
                    glowColor.withValues(alpha: 0.9),
                    glowColor.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                : null,
        color: active ? null : onBg.withValues(alpha: 0.05),
        border: Border.all(
          color:
              active
                  ? Colors.white.withValues(alpha: 0.3)
                  : onBg.withValues(alpha: 0.08),
          width: active ? 1.5 : 1.0,
        ),
        boxShadow:
            active
                ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ]
                : null,
      ),
      child: Icon(
        _iconosPestanas[index],
        size: r.footerSize + 1,
        color: active ? Colors.white : onBg.withValues(alpha: 0.5),
      ),
    );
  }
}
