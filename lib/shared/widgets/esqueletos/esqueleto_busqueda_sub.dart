// ─────────────────────────────────────────────────────────────
// esqueleto_busqueda_sub.dart — PART de esqueleto_busqueda.dart:
// piezas del esqueleto de búsqueda — tarjeta de track placeholder,
// cabecera de sección (icono circular + texto) y la grilla de
// placeholders que imita TarjetaGrilla (2-4 columnas según ancho,
// ratio 0.72). Gradientes estáticos.
//
// Las medidas salen del aparato (Responsive + especificaciones): en la TV
// las filas y los círculos del esqueleto crecen con el resto de la app, si
// no el cargando se vería chico y el salto al resultado real sería brusco.
// Se conecta con: esqueleto_busqueda.dart (misma library) +
// responsive + especificaciones_plataforma.
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
    final r = Responsive(context);
    final e = EspecificacionesPlataforma.de(context);
    return Container(
      height: r.val(80, 70, 130),
      margin: EdgeInsets.symmetric(vertical: r.spacingXS),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(e.radioTarjeta + 4),
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
    final r = Responsive(context);
    final e = EspecificacionesPlataforma.de(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.spacingXS),
      child: Row(
        children: [
          Container(
            width: e.iconoTile,
            height: e.iconoTile,
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
          SizedBox(width: r.spacingM),
          Container(
            width: r.val(120, 100, 200),
            height: r.val(16, 14, 26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(e.radioEsqueleto),
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
    final r = Responsive(context);
    final e = EspecificacionesPlataforma.de(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final disponible = constraints.maxWidth - 32;
        final columnas =
            disponible > 700
                ? 4
                : disponible > 340
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            mainAxisSpacing: r.spacingS,
            crossAxisSpacing: r.spacingS,
            childAspectRatio: 0.72,
          ),
          itemCount: columnas * 2,
          itemBuilder: (_, index) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(e.radioTarjeta + 2),
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
