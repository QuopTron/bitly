// ─────────────────────────────────────────────────────────────
// settings_sheet_nav_burbujas.dart — PART de settings_sheet_new.dart: la
// fila de burbujas del celular (y de cualquier ventana angosta).
//
// Cada burbuja ocupa el mismo ancho: si el ancho disponible reparte cómodo,
// la fila llena la pantalla; si no, se desliza y deja centrada la pestaña
// activa al abrirla o al tocarla. Antes eran `Expanded` fijos, así que con
// 7 pestañas cada etiqueta quedaba partida.
//
// Se conecta con: settings_sheet_bubble_tab.dart (la burbuja) y
// settings_sheet_nav.dart (lo elige).
// Parte del flujo: Ajustes → navegación (celular).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

class _BubbleTabsRow extends StatefulWidget {
  final int? currentIndex;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final void Function(int index) onTap;

  const _BubbleTabsRow({
    required this.currentIndex,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  State<_BubbleTabsRow> createState() => _BubbleTabsRowState();
}

class _BubbleTabsRowState extends State<_BubbleTabsRow> {
  final _scroll = ScrollController();

  /// Medidas del último layout: ancho usable de la fila y de cada burbuja.
  double _anchoUtil = 0;
  double _anchoBurbuja = 0;
  bool _entraEntera = true;

  @override
  void didUpdateWidget(covariant _BubbleTabsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El tutorial también cambia de pestaña: seguimos la activa.
    if (oldWidget.currentIndex != widget.currentIndex) _centrarActiva();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Deja la pestaña activa centrada cuando la fila se desliza.
  void _centrarActiva() {
    final i = widget.currentIndex;
    if (i == null || _entraEntera) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final destino = i * _anchoBurbuja - (_anchoUtil - _anchoBurbuja) / 2;
      _scroll.animateTo(
        destino.clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final n = _iconosPestanas.length;
        final util = c.maxWidth - widget.r.spacingS * 2;
        _anchoUtil = util;
        _anchoBurbuja = math.max(_anchoMinimoBurbuja, util / n);
        _entraEntera = _anchoBurbuja * n <= util + 0.5;

        final fila = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < n; i++)
              SizedBox(
                width: _anchoBurbuja,
                child: _BubbleTab(
                  index: i,
                  active: widget.currentIndex == i,
                  glowColor: widget.glowColor,
                  onBg: widget.onBg,
                  r: widget.r,
                  onTap: () {
                    widget.onTap(i);
                    _centrarActiva();
                  },
                ),
              ),
          ],
        );

        if (_entraEntera) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.r.spacingS),
            child: fila,
          );
        }
        return SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: widget.r.spacingS),
          child: fila,
        );
      },
    );
  }
}
