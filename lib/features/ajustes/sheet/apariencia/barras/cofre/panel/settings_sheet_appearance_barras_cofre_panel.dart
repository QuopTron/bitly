// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_cofre_panel.dart — PART de
// settings_sheet_new.dart: el SUBMODAL del cofre, con los diseños.
//
// Es el panel que se despliega dentro del propio sheet (ver
// settings_sheet_appearance_barras_cofre.dart): encabezado con cuántos
// regalos quedan, el aviso de PARA QUÉ APARATO son los diseños que se ven, y
// un botón "Listo". Las grillas (Diseños y Colores) viven en _cofre_grillas.
//
// Los diseños y el contador de regalos van filtrados por el aparato en el que
// se abre el cofre: la TV no ofrece los del dedo y el celular no ofrece los de
// pantalla grande, así el mininumerito nunca queda encendido por algo que acá
// no se puede abrir.
//
// Se conecta con: _cofre (el botón) + _cofre_grillas + _cofre_seccion +
// catalogo_disenos_barra_lista (el catálogo filtrado por aparato).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

part of '../../../../settings_sheet_new.dart';

/// Panel del cofre: el encabezado, el aviso de aparato y las grillas.
class _CofrePaletasPanel extends StatefulWidget {
  final bool navbar;
  final int horas;
  final int version;

  /// Aparato que se está usando: el cofre solo ofrece sus diseños (más los
  /// que son de todos) y con eso cuenta los regalos.
  final TipoDispositivo aparato;

  /// Nombre ya localizado de ese aparato ("Celular", "TV", "PC").
  final String nombreAparato;

  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final StringsCofrePaletas t;
  final VoidCallback onCerrar;

  const _CofrePaletasPanel({
    required this.navbar,
    required this.horas,
    required this.version,
    required this.aparato,
    required this.nombreAparato,
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
    // Los del aparato en el que se está abriendo, más los que son de todos.
    final disenos = disenosParaAparato(widget.aparato);
    final colores = coloresParaAparato(widget.aparato);
    final disponibles =
        regalosDisponibles(
          horas: widget.horas,
          version: widget.version,
          vistos: const {},
          aparato: widget.aparato,
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
          Text(
            widget.t.paraAparato(widget.nombreAparato),
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: onBg.withValues(alpha: 0.45),
            ),
          ),
          SizedBox(height: r.spacingM),
          _GrillasCofre(
            disenos: disenos,
            colores: colores,
            entrada: _entrada,
            navbar: widget.navbar,
            horas: widget.horas,
            version: widget.version,
            glowColor: widget.glowColor,
            onBg: onBg,
            r: r,
            t: widget.t,
          ),
        ],
      ),
    );
  }
}
