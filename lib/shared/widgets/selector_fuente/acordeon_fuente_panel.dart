// ─────────────────────────────────────────────────────────────
// acordeon_fuente_panel.dart — PART de acordeon_fuente.dart:
// panel flotante del selector de fuentes (Material con elevación,
// lista de fuentes con icono + nombre + check de selección y
// divisores). Entra con fade + slide corto. Las filas usan la
// clase FilaFuente definida en la library principal.
// Se conecta con: acordeon_fuente.dart (misma library) + nada más.
// Parte del flujo: búsqueda (selector de extensión).
// ─────────────────────────────────────────────────────────────

part of 'acordeon_fuente.dart';

/// Panel flotante con la lista de fuentes.
class PanelFuenteFlotante extends StatelessWidget {
  final bool esOscuro;
  final Color onBg;
  final Color colorBrillo;
  final List<FilaFuente> filas;
  final String fuenteSeleccionada;
  final ValueChanged<String> onSeleccionar;

  const PanelFuenteFlotante({
    super.key,
    required this.esOscuro,
    required this.onBg,
    required this.colorBrillo,
    required this.filas,
    required this.fuenteSeleccionada,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -8),
            child: child,
          ),
        );
      },
      child: Material(
        elevation: 16,
        color: esOscuro ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.hardEdge,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < filas.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 42,
                        endIndent: 12,
                        color: onBg.withValues(alpha: esOscuro ? 0.08 : 0.12),
                      ),
                    _fila(filas[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fila(FilaFuente fila) {
    final seleccionada = fuenteSeleccionada == fila.valor;
    return Material(
      color: seleccionada
          ? onBg.withValues(alpha: esOscuro ? 0.1 : 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: () => onSeleccionar(fila.valor),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _iconoRedondeadoChico(fila.icono),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fila.etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: seleccionada ? FontWeight.w700 : FontWeight.w500,
                      color: onBg.withValues(alpha: seleccionada ? 1 : 0.78),
                    ),
                  ),
                ),
                Icon(
                  seleccionada ? Icons.check_circle : Icons.circle_outlined,
                  size: 17,
                  color: seleccionada
                      ? onBg
                      : onBg.withValues(alpha: esOscuro ? 0.3 : 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconoRedondeadoChico(IconData icono) {
    final c = onBg;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: esOscuro ? 0.1 : 0.08),
      ),
      child: Icon(icono, size: 15, color: c.withValues(alpha: 0.9)),
    );
  }
}