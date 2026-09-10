// ─────────────────────────────────────────────────────────────
// modal_cola_chip.dart — PART de modal_cola.dart: chip compacto de
// modo (shuffle/repetición) en la cabecera de la cola — icono y
// etiqueta con tinte del color brillo.
// Se conecta con: modal_cola.dart (misma library).
// Parte del flujo: reproductor (modal de cola, chips de modo).
// ─────────────────────────────────────────────────────────────

part of 'modal_cola.dart';

/// Chip de estado del modo de reproducción en la cabecera de la cola.
class ChipModoCola extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final Responsive r;
  final Color colorBrillo;

  const ChipModoCola({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.r,
    required this.colorBrillo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorBrillo.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: r.footerSize - 2, color: colorBrillo),
          SizedBox(width: 2),
          Text(
            etiqueta,
            style: TextStyle(fontSize: r.footerSize - 2, color: colorBrillo),
          ),
        ],
      ),
    );
  }
}