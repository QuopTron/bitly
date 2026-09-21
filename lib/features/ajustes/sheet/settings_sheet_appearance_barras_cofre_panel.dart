// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_cofre_panel.dart — PART de
// settings_sheet_new.dart: el SUBMODAL del cofre, con los diseños.
//
// Es el panel que se despliega dentro del propio sheet (ver
// settings_sheet_appearance_barras_cofre.dart): encabezado con cuántos
// regalos quedan y un botón "Listo", y dos SECCIONES —primero los diseños
// y después los colores— para que no se mezclen en una lista larga.
//
// La grilla se mide con LayoutBuilder: el ancho de cada tarjeta se calcula
// para que las 3 (o 2, si el panel es angosto) llenen la fila EXACTA, sin
// sobras desparejas ni apretujones en pantallas chicas.
//
// Se conecta con: _cofre (el botón) + _cofre_seccion + _cofre_entrada +
// catalogo_disenos_barra_lista (las dos secciones).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Panel del cofre: el encabezado y las grillas de diseños y colores.
class _CofrePaletasPanel extends StatefulWidget {
  final bool navbar;
  final int horas;
  final int version;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final StringsCofrePaletas t;
  final VoidCallback onCerrar;

  const _CofrePaletasPanel({
    required this.navbar,
    required this.horas,
    required this.version,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.t,
    required this.onCerrar,
  });

  @override
  State<_CofrePaletasPanel> createState() => _CofrePaletasPanelState();
}

class _CofrePaletasPanelState extends State<_CofrePaletasPanel>
    with SingleTickerProviderStateMixin {
  /// Controla la entrada escalonada de los diseños.
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final onBg = widget.onBg;
    final disponibles =
        regalosDisponibles(
          horas: widget.horas,
          version: widget.version,
          vistos: const {},
        ).length;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: r.spacingS),
      padding: EdgeInsets.all(r.spacingM),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.glowColor.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezadoCofre(
            t: widget.t,
            r: r,
            onBg: onBg,
            disponibles: disponibles,
            onCerrar: widget.onCerrar,
          ),
          SizedBox(height: r.spacingM),
          LayoutBuilder(
            builder: (context, limites) {
              // 3 por fila si hay ancho cómodo; 2 en pantallas angostas.
              final columnas = limites.maxWidth > r.width * 0.62 ? 3 : 2;
              final hueco = r.spacingS;
              final ancho =
                  (limites.maxWidth - hueco * (columnas - 1)) / columnas;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _seccion(
                    widget.t.seccionDisenos,
                    disenosCofreBarra,
                    0,
                    ancho,
                    hueco,
                  ),
                  SizedBox(height: r.spacingM),
                  _seccion(
                    widget.t.seccionColores,
                    coloresCofreBarra,
                    disenosCofreBarra.length,
                    ancho,
                    hueco,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Una sección del cofre (ver _cofre_seccion).
  Widget _seccion(
    String titulo,
    List<DisenoBarra> items,
    int base,
    double ancho,
    double hueco,
  ) => _SeccionCofre(
    titulo: titulo,
    items: items,
    base: base,
    ancho: ancho,
    hueco: hueco,
    entrada: _entrada,
    navbar: widget.navbar,
    horas: widget.horas,
    version: widget.version,
    glowColor: widget.glowColor,
    onBg: widget.onBg,
    r: widget.r,
    t: widget.t,
  );
}
