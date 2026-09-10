// ─────────────────────────────────────────────────────────────
// esqueleto_busqueda_sub.dart — PART de esqueleto_busqueda.dart:
// piezas del esqueleto de búsqueda — tarjeta de track placeholder
// (80px, radio 18), cabecera de sección (icono circular + texto)
// y la grilla de placeholders que imita TarjetaGrilla (2-4
// columnas según ancho, ratio 0.72). Gradientes estáticos.
// Se conecta con: esqueleto_busqueda.dart (misma library).
// Parte del flujo: búsqueda (loading mientras llegan resultados).
// ─────────────────────────────────────────────────────────────

part of 'esqueleto_busqueda.dart';

/// Esqueleto de una tarjeta de track (mismo alto/radio que TarjetaTrack).
class _TarjetaTrackEsqueleto extends StatelessWidget {
  final Color base;
  final Color brillo;

  const _TarjetaTrackEsqueleto({required this.base, required this.brillo});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment(-1.0, 0),
          end: Alignment(1.0, 0),
          colors: [base, brillo, base],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Esqueleto de una cabecera de sección (icono circular + texto).
class _EncabezadoSeccion extends StatelessWidget {
  final Color base;
  final Color brillo;

  const _EncabezadoSeccion({required this.base, required this.brillo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment(-1.0, 0),
                end: Alignment(1.0, 0),
                colors: [base, brillo, base],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 120,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment(-1.0, 0),
                end: Alignment(1.0, 0),
                colors: [base, brillo, base],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grilla de esqueletos que imita la grilla de TarjetaGrilla.
class _GrillaEsqueleto extends StatelessWidget {
  final Color base;
  final Color brillo;

  const _GrillaEsqueleto({required this.base, required this.brillo});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final disponible = constraints.maxWidth - 32;
        final columnas = disponible > 700 ? 4 : disponible > 340 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.72,
          ),
          itemCount: columnas * 2,
          itemBuilder: (_, index) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment(-1.0, 0),
                  end: Alignment(1.0, 0),
                  colors: [base, brillo, base],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            );
          },
        );
      },
    );
  }
}