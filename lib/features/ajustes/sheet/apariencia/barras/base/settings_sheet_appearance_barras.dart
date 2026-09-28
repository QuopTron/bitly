// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras.dart — PART de settings_sheet_new.dart:
// espacio "Barras": el redondeo de las dos esquinas de ARRIBA del navbar y
// del miniplayer (se elige cuál se edita) y el cofre de DISEÑOS, que trae
// formas (recto, pastilla, contorno) y colores.
//
// Ya no hay selector de contorno aparte: el contorno es parte de los diseños.
// La vista previa es UNA sola y va alternando entre las dos barras. Todo se
// aplica al instante y las piezas viven en _barras_piezas / _previa / _control,
// más el cofre y sus partes.
// Se conecta con: apariencia_helper + catalogo_disenos_barra_lista.
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Tarjeta "Barras": navbar y miniplayer con su cofre de diseños.
class _BarrasCard extends StatefulWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final AppLocalizations loc;

  const _BarrasCard({
    super.key,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.loc,
  });

  @override
  State<_BarrasCard> createState() => _BarrasCardState();
}

class _BarrasCardState extends State<_BarrasCard> {
  /// ¿Se está editando el navbar? Si no, el miniplayer.
  bool _navbar = true;

  @override
  Widget build(BuildContext context) {
    final t = widget.loc.apariencia;
    final r = widget.r;
    final onBg = widget.onBg;
    // El cofre es POR APARATO: la TV no ofrece los diseños del dedo ni el
    // celular los de pantalla grande, así que se resuelve una sola vez acá.
    final aparato = tipoDeEsteAparato();
    return ValueListenableBuilder<PreferenciasApariencia>(
      valueListenable: AparienciaHelper.notifier(),
      builder:
          (context, prefs, _) => ContenedorVidrio(
            borderRadius: 16,
            borderColor: onBg.withValues(alpha: 0.08),
            bgColor: onBg.withValues(alpha: 0.03),
            padding: EdgeInsets.all(r.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _encabezado(t),
                SizedBox(height: r.spacingS),
                _SelectorBarraEditada(
                  navbar: _navbar,
                  t: t,
                  r: r,
                  onBg: onBg,
                  glowColor: widget.glowColor,
                  onCambio: (navbar) => setState(() => _navbar = navbar),
                ),
                SizedBox(height: r.spacingM),
                _VistaPreviaBarra(
                  prefs: prefs,
                  navbar: _navbar,
                  r: r,
                  onBg: onBg,
                  glowColor: widget.glowColor,
                  t: t,
                ),
                SizedBox(height: r.spacingM),
                _controlBarra(context, navbar: _navbar, prefs: prefs, t: t),
                _AyudaControl(
                  texto:
                      _barrasTieneOlas(context, navbar: _navbar)
                          ? t.barras.ayudaOlas
                          : t.barras.ayuda,
                  r: r,
                  onBg: onBg,
                ),
                // Tamaño y forma son del MINIPLAYER: el navbar no tiene
                // carátula que agrandar ni se despega del borde.
                if (!_navbar)
                  _MiniplayerPresets(
                    prefs: prefs,
                    t: t.barras,
                    r: r,
                    onBg: onBg,
                    glowColor: widget.glowColor,
                  ),
                SizedBox(height: r.spacingM),
                _CofreDisenos(
                  navbar: _navbar,
                  glowColor: widget.glowColor,
                  onBg: onBg,
                  r: r,
                  t: widget.loc.cofre,
                  aparato: aparato,
                  nombreAparato: _nombreTipo(widget.loc.conexion, aparato),
                ),
              ],
            ),
          ),
    );
  }

  /// Encabezado con el mininumerito de regalos por abrir.
  Widget _encabezado(StringsApariencia t) => Row(
    children: [
      Icon(
        Icons.rounded_corner_rounded,
        color: widget.glowColor,
        size: widget.r.subtitleSize,
      ),
      SizedBox(width: widget.r.spacingS),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.barras.titulo,
              style: TextStyle(
                fontSize: widget.r.subtitleSize,
                fontWeight: FontWeight.w700,
                color: widget.onBg,
              ),
            ),
            Text(
              t.barras.ayuda,
              style: TextStyle(
                fontSize: widget.r.footerSize - 2,
                color: widget.onBg.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
      ValueListenableBuilder<int>(
        valueListenable: AparienciaHelper.regalos,
        builder:
            (context, n, _) =>
                n <= 0
                    ? const SizedBox.shrink()
                    : _ChipPersonalizado(
                      texto: '$n',
                      glowColor: widget.glowColor,
                      r: widget.r,
                    ),
      ),
    ],
  );
}
