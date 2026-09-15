// ─────────────────────────────────────────────────────────────
// fondo_ambiente_velo.dart — Velo dinámico que extrae el color
// dominante del cover y lo muestra como fondo sólido en modo
// Spotify. Transición animada al cambiar de canción.
//
// Se conecta con: fondo_ambiente.dart (lo monta como capa 2).
// Parte del flujo: Home → fondo ambiente.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../utilidades/portada/paleta_portada.dart';

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
      if (mounted) setState(() => _acento = paleta?.dominante);
    } catch (e) { debugPrint("[Widget] $e"); }
  }

  @override
  Widget build(BuildContext context) {
    final colorBase = _acento ?? widget.defaultBg;
    final colorFinal = Color.lerp(
      widget.defaultBg, colorBase, widget.isDark ? 0.45 : 0.30,
    )!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      color: colorFinal,
    );
  }
}
