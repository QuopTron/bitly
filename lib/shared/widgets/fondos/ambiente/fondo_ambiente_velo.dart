// ─────────────────────────────────────────────────────────────
// fondo_ambiente_velo.dart — Velo dinámico que extrae el color
// dominante del cover y lo muestra como fondo sólido en modo
// Spotify, acomodado para que las letras del tema se lean encima.
// Transición animada al cambiar de canción.
//
// Se conecta con: fondo_ambiente.dart (lo monta como capa 2) + estilo_helper.
// Parte del flujo: Home → fondo ambiente.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../utilidades/formato/comun/formato/estilo_helper.dart';
import '../../../utilidades/portada/paleta/paleta_portada.dart';

/// Velo que muestra el color dominante del cover como fondo.
class VeloDinamico extends StatefulWidget {
  final String coverUrl;
  final bool isDark;
  final Color defaultBg;

  const VeloDinamico({
    super.key,
    required this.coverUrl,
    required this.isDark,
    required this.defaultBg,
  });

  @override
  State<VeloDinamico> createState() => _VeloDinamicoState();
}

class _VeloDinamicoState extends State<VeloDinamico> {
  Color? _acento;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  @override
  void didUpdateWidget(covariant VeloDinamico oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) _extraerColor();
  }

  Future<void> _extraerColor() async {
    try {
      final paleta = await paletaParaPortada(widget.coverUrl);
      // `acentoTinte` = el color que domina de verdad (un cover sin color no
      // recibe un tono inventado).
      if (mounted) setState(() => _acento = paleta?.acentoTinte);
    } catch (e) {
      debugPrint("[Widget] $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorBase = _acento ?? widget.defaultBg;
    // El color del cover se pinta con presencia (estilo_helper): mezclado
    // apagado quedaba casi igual que la carátula de abajo y el control de
    // opacidad no se notaba.
    //
    // Las letras de la Home son las del TEMA: el fondo se acomoda a ellas
    // (ver `EstiloHelper.fondoDeCover`), así un cover saturado y claro no deja
    // el texto blanco al borde de lo ilegible.
    final colorFinal = EstiloHelper.fondoDeCover(
      colorBase,
      widget.defaultBg,
      widget.isDark ? Colors.white : Colors.black,
      mezcla: widget.isDark ? 0.58 : 0.45,
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      color: colorFinal,
    );
  }
}
