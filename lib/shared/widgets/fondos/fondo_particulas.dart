// ─────────────────────────────────────────────────────────────
// fondo_particulas.dart — Fondo animado de partículas (notas
// musicales flotando con glow radial suave) usado en el splash y
// el fondo del player. Optimizado: glow y glifo cacheados por
// partícula (sin blur MaskFilter por frame) y RepaintBoundary para
// no repintar el resto de la UI. El modelo de partícula vive en el
// part fondo_particulas_particula.dart.
// Se conecta con: splash y player (fondos animados) + tema.
// Parte del flujo: presentación (fondo animado).
// ─────────────────────────────────────────────────────────────

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

part 'fondo_particulas_particula.dart';

/// Painter que dibuja todas las partículas con su glow cacheado.
class _PainterParticulas extends CustomPainter {
  final List<_Particula> particles;
  final Color glowColor, particleColor;

  _PainterParticulas({
    required this.particles,
    required this.glowColor,
    required this.particleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      p.asegurarCache(glowColor, particleColor);
      final tp = p.glyph;
      final gp = p.glowPaint;
      if (tp == null || gp == null) continue;
      final cx = p.x * size.width, cy = p.y * size.height;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(p.rotation);
      // Glow suave: un círculo de gradiente radial (cacheado) — sin saveLayer.
      canvas.drawCircle(Offset.zero, p.size * 1.6, gp);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PainterParticulas oldDelegate) =>
      oldDelegate.particles != particles ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.particleColor != particleColor;
}

/// Fondo animado de notas musicales con glow.
class FondoParticulas extends StatefulWidget {
  final int particleCount;
  final Color glowColor, particleColor;
  final double maxParticleSize, minParticleSize, speedMultiplier;

  const FondoParticulas({
    super.key,
    this.particleCount = 6,
    this.glowColor = const Color(0x15FFFFFF),
    this.particleColor = Colors.white,
    this.maxParticleSize = 32,
    this.minParticleSize = 14,
    this.speedMultiplier = 1.0,
  });

  @override
  State<FondoParticulas> createState() => _FondoParticulasState();
}

class _FondoParticulasState extends State<FondoParticulas>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particula> _particulas;
  final _rng = Random();
  final _iconosNota = ['♩', '♪', '♫', '♬'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
    _particulas = List.generate(
      widget.particleCount,
      (_) => _crearParticula(),
    );
  }

  _Particula _crearParticula() => _Particula(
    x: _rng.nextDouble(),
    y: _rng.nextDouble(),
    size: widget.minParticleSize +
        _rng.nextDouble() * (widget.maxParticleSize - widget.minParticleSize),
    speedX: (_rng.nextDouble() - 0.5) * 0.012 * widget.speedMultiplier,
    speedY: -_rng.nextDouble() * 0.018 * widget.speedMultiplier,
    opacity: 0.15 + _rng.nextDouble() * 0.3,
    rotation: _rng.nextDouble() * 6.28,
    rotationSpeed: (_rng.nextDouble() - 0.5) * 0.015,
    iconLabel: _iconosNota[_rng.nextInt(_iconosNota.length)],
  );

  void _reiniciarParticula(_Particula p) {
    p.x = _rng.nextDouble();
    p.y = 1.1;
    p.speedX = (_rng.nextDouble() - 0.5) * 0.012 * widget.speedMultiplier;
    p.speedY = -_rng.nextDouble() * 0.018 * widget.speedMultiplier;
    p.opacity = 0.15 + _rng.nextDouble() * 0.3;
    // La apariencia cambió → el glow/glyph cacheado se reconstruye perezoso.
    p.glowPaint = null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        for (final p in _particulas) {
          p.x += p.speedX;
          p.y += p.speedY;
          p.rotation += p.rotationSpeed;
          if (p.y < -0.1 || p.x < -0.1 || p.x > 1.1) _reiniciarParticula(p);
        }
        return RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _PainterParticulas(
              particles: _particulas,
              glowColor: widget.glowColor,
              particleColor: widget.particleColor,
            ),
          ),
        );
      },
    );
  }
}