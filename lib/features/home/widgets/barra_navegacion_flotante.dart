// ─────────────────────────────────────────────────────────────
// barra_navegacion_flotante.dart — Barra de navegación inferior
// flotante del LAYOUT MÓVIL (celular/tablet): 3 pestañas (Buscar,
// Inicio, Mi Espacio) con animación de selección y vidrio. Solo se
// usa en la variante móvil de la Home; el escritorio usa la barra
// lateral (barra_navegacion_lateral.dart).
// Se conecta con: home_movil.dart (navegación) + shared (vidrio,
// responsive, tema).
// Parte del flujo: Home (navegación de pestañas en celular).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';

/// Navbar inferior flotante con vidrio (layout móvil).
class BarraNavegacionFlotante extends StatefulWidget {
  final bool isDark;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const BarraNavegacionFlotante({
    super.key,
    required this.isDark,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  State<BarraNavegacionFlotante> createState() => _BarraNavegacionFlotanteState();
}

class _BarraNavegacionFlotanteState extends State<BarraNavegacionFlotante> {
  late int _selected;

  static const _items = [
    _ItemNav(Icons.search_rounded, 'Buscar'),
    _ItemNav(Icons.home_rounded, 'Inicio'),
    _ItemNav(Icons.grid_view_rounded, 'Mi Espacio'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentIndex;
  }

  @override
  void didUpdateWidget(BarraNavegacionFlotante oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mantiene la selección sincronizada si el padre cambia currentIndex
    // (p.ej. el navbar global sobre detalles, que refleja la Home real).
    if (widget.currentIndex != oldWidget.currentIndex) {
      _selected = widget.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = ColoresApp.enSuperficie(widget.isDark);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ContenedorVidrio(
        borderRadius: 0,
        blurSigma: 20,
        borderColor: onBg.withValues(alpha: 0.08),
        bgColor: ColoresApp.superficie(widget.isDark).withValues(alpha: 0.80),
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingM,
          vertical: r.spacingS * 0.7,
        ),
        child: Row(
          children: List.generate(
            _items.length,
            (i) => Expanded(child: _itemNav(i, r, onBg)),
          ),
        ),
      ),
    );
  }

  Widget _itemNav(int i, Responsive r, Color onBg) {
    final sel = _selected == i;
    return GestureDetector(
      onTap: () {
        setState(() => _selected = i);
        widget.onTap?.call(i);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(vertical: r.spacingS * 1.1),
        decoration: BoxDecoration(
          color: sel ? onBg.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: sel ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                _items[i].icon,
                size: r.subtitleSize + 10,
                color: sel ? onBg : onBg.withValues(alpha: 0.35),
              ),
            ),
            SizedBox(height: r.spacingXS * 0.7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: sel ? 5 : 0,
              height: sel ? 5 : 0,
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemNav {
  final IconData icon;
  final String label;
  const _ItemNav(this.icon, this.label);
}