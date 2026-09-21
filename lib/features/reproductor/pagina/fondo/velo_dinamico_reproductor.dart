// ─────────────────────────────────────────────────────────────
// reproductor_pagina_fondo.dart — PART de reproductor_pagina.dart:
// velo_dinamico_reproductor.dart — PART de reproductor_pagina.dart: _VeloDinamicoReproductor (movido desde reproductor_pagina_fondo.dart).
// Se conecta con: reproductor_pagina.dart (misma library).
// ─────────────────────────────────────────────────────────────

part of '../base/reproductor_pagina.dart';

/// Velo dinámico del reproductor: color dominante como fondo sólido.
class _VeloDinamicoReproductor extends StatefulWidget {
  final String coverUrl;
  final bool esOscuro;
  final Color defaultBg;

  const _VeloDinamicoReproductor({
    required this.coverUrl,
    required this.esOscuro,
    required this.defaultBg,
  });

  @override
  State<_VeloDinamicoReproductor> createState() =>
      _VeloDinamicoReproductorState();
}

class _VeloDinamicoReproductorState extends State<_VeloDinamicoReproductor> {
  Color? _acento;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  @override
  void didUpdateWidget(covariant _VeloDinamicoReproductor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _extraerColor();
    }
  }

  Future<void> _extraerColor() async {
    try {
      final paleta = await paletaParaPortada(widget.coverUrl);
      if (mounted) {
        setState(() {
          _acento = paleta?.dominante;
        });
      }
    } catch (e) {
      debugPrint("[Feature] $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorBase = _acento ?? widget.defaultBg;
    // El color del cover se pinta con presencia (estilo_helper): mezclado
    // apagado quedaba casi igual que la carátula de abajo y el control de
    // opacidad no se notaba.
    final colorFinal = EstiloHelper.colorDeCover(
      colorBase,
      widget.defaultBg,
      mezcla: widget.esOscuro ? 0.60 : 0.46,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      color: colorFinal,
    );
  }
}
