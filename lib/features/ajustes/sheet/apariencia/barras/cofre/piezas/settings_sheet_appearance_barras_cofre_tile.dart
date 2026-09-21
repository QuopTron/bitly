// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_cofre_tile.dart — PART de
// settings_sheet_new.dart: una PALETA dentro del cofre.
//
// Pinta la muestra (ver _cofre_muestra), el nombre y una línea de estado
// ("En uso", "Usar" o cómo se abre). La primera dice además con qué versión
// vino ("Viene con la v1.0.0"): es el regalo que trae la app.
//
// Al tocarla se aplica a la barra que se edita, con una animación de apertura
// (la muestra crece y suelta un glow de su color) y el regalo queda marcado
// como abierto (ahí baja el mininumerito).
//
// Se conecta con: _cofre_panel (la grilla) + catalogo_disenos_barra_lista +
// apariencia_barras_helper.
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

part of '../../../../settings_sheet_new.dart';

/// Una paleta del cofre: su muestra, su nombre y su estado.
class _PotPaletaTile extends StatefulWidget {
  final DisenoBarra diseno;
  final bool navbar;
  final bool abierto;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final StringsCofrePaletas t;

  /// Ancho exacto que le da la grilla del panel (así entran justas).
  final double ancho;

  const _PotPaletaTile({
    required this.diseno,
    required this.navbar,
    required this.abierto,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.t,
    required this.ancho,
  });

  @override
  State<_PotPaletaTile> createState() => _PotPaletaTileState();
}

class _PotPaletaTileState extends State<_PotPaletaTile>
    with SingleTickerProviderStateMixin {
  /// La animación de apertura: la muestra crece y suelta su glow una vez.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  /// Colores de la paleta (la de regalo viene vacía: es el vidrio de hoy).
  List<Color> get _colores => [for (final c in widget.diseno.paleta) Color(c)];

  @override
  Widget build(BuildContext context) {
    // "En uso" se compara por ESTADO, así una paleta y una forma pueden
    // estar puestas a la vez sin pisarse.
    final enUso = AparienciaDisenos.disenoEnUso(
      context,
      widget.diseno,
      navbar: widget.navbar,
    );
    return SizedBox(
      // El ancho lo fija la GRILLA (ver _cofre_panel): llenan la fila exacta.
      width: widget.ancho,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.abierto && !enUso ? _aplicar : null,
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pop,
              builder:
                  (context, _) => Transform.scale(
                    scale: 1 + 0.06 * _pop.value,
                    child: _MuestraPaleta(
                      colores: _colores,
                      radioArriba: AparienciaDisenos.radioDe(
                        context,
                        widget.diseno,
                        navbar: widget.navbar,
                      ),
                      adorno: AparienciaMuestra.adorno(
                        context,
                        widget.diseno,
                        navbar: widget.navbar,
                      ),
                      olas: AparienciaDisenos.olasDe(
                        context,
                        navbar: widget.navbar,
                      ),
                      sticker: AparienciaMuestra.sticker(
                        context,
                        widget.diseno,
                        navbar: widget.navbar,
                      ),
                      borde: AparienciaBarras.bordeDe(
                        AparienciaDisenos.trazoDe(context, widget.diseno),
                      ),
                      brillo: _pop.value,
                      abierto: widget.abierto,
                      enUso: enUso,
                      glowColor: widget.glowColor,
                      onBg: widget.onBg,
                      r: widget.r,
                    ),
                  ),
            ),
            SizedBox(height: widget.r.spacingXS),
            _TextoPaleta(
              diseno: widget.diseno,
              t: widget.t,
              r: widget.r,
              onBg: widget.onBg,
              glowColor: widget.glowColor,
              colores: _colores,
              enUso: enUso,
              abierto: widget.abierto,
            ),
          ],
        ),
      ),
    );
  }

  /// Abrir el regalo es USARLO: recién ahí baja el mininumerito. La paleta
  /// cambia al instante (las barras leen el notifier) y la animación lo
  /// festeja.
  void _aplicar() {
    Haptico.medio();
    AparienciaDisenos.aplicarDiseno(
      context,
      widget.diseno,
      navbar: widget.navbar,
    );
    AparienciaBarras.marcarRegalosVistos(context, [widget.diseno.id]);
    _pop.forward(from: 0);
  }
}
