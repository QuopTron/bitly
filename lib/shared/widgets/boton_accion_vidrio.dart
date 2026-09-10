// ─────────────────────────────────────────────────────────────
// boton_accion_vidrio.dart — Botón circular de acción con estilo
// glassmorphism (fondo translúcido, borde con brillo sutil y
// animación de escala al tocar). Reemplaza las 3 copias de los
// botones de acción de las páginas de detalle (álbum/playlist/
// artista) por una sola implementación.
// Se conecta con: colores_app + tema de la app.
// Parte del flujo: Detalle (acciones like/descargar/reproducir).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../tema/colores_app.dart';

/// Botón circular glass con glow y animación de presión.
class BotonAccionVidrio extends StatefulWidget {
  final IconData icono;
  final VoidCallback? onTap;
  final Color? color;
  final bool relleno;

  const BotonAccionVidrio({
    super.key,
    required this.icono,
    this.onTap,
    this.color,
    this.relleno = false,
  });

  @override
  State<BotonAccionVidrio> createState() => _BotonAccionVidrioState();
}

class _BotonAccionVidrioState extends State<BotonAccionVidrio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrlEscala;
  late final Animation<double> _escala;

  @override
  void initState() {
    super.initState();
    _ctrlEscala = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0,
      upperBound: 1,
    );
    _escala = Tween(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrlEscala, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrlEscala.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final acento =
        widget.color ?? (esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeProfundo);
    final habilitado = widget.onTap != null;

    final alphaFondo = widget.relleno ? 0.22 : 0.08;
    final colorFondo = widget.relleno
        ? acento.withValues(alpha: alphaFondo)
        : ColoresApp.enSuperficie(esOscuro).withValues(alpha: alphaFondo);

    final colorBorde = widget.relleno
        ? acento.withValues(alpha: 0.5)
        : ColoresApp.enSuperficie(esOscuro).withValues(alpha: 0.12);

    final colorIcono = widget.relleno
        ? acento
        : widget.color ?? ColoresApp.enSuperficie(esOscuro);

    return GestureDetector(
      onTapDown: habilitado ? (_) => _ctrlEscala.forward() : null,
      onTapUp: habilitado ? (_) => _ctrlEscala.reverse() : null,
      onTapCancel: habilitado ? () => _ctrlEscala.reverse() : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _escala,
        builder: (context, child) =>
            Transform.scale(scale: _escala.value, child: child),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: habilitado ? colorFondo : colorFondo.withValues(alpha: 0.3),
            border: Border.all(
              color: habilitado
                  ? colorBorde
                  : colorBorde.withValues(alpha: 0.3),
              width: 1.0,
            ),
            boxShadow: widget.relleno
                ? [
                    BoxShadow(
                      color: acento.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icono,
            size: 22,
            color: habilitado
                ? colorIcono
                : colorIcono.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}