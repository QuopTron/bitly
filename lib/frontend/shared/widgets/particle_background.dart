import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class _Particle {
  double x, y, size, speedX, speedY, opacity, rotation, rotationSpeed;
  final String iconLabel;

  /// Cached radial-gradient glow (no per-frame MaskFilter blur). Rebuilt only
  /// when the particle is created or reset (opacity changes).
  ui.Paint? glowPaint;

  /// Cached glyph (TextPainter layout is expensive — never per frame).
  TextPainter? glyph;
  double _glyphAlpha = -1;
  Color _glyphColor = const Color(0x00000000);
  double _glyphSize = -1;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
    required this.rotation,
    required this.rotationSpeed,
    required this.iconLabel,
  });

  /// Builds (or rebuilds when stale) the cached glow + glyph for this
  /// particle. Cheap enough to call on every frame; it no-ops unless the
  /// appearance actually changed.
  void ensureCached(Color glowColor, Color particleColor) {
    if (glowPaint == null) {
      final c = glowColor.withValues(alpha: opacity * 0.45);
      glowPaint = ui.Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          size * 1.6,
          [c, c.withValues(alpha: 0.0)],
        );
    }
    if (glyph == null ||
        _glyphAlpha != opacity ||
        _glyphColor != particleColor ||
        _glyphSize != size) {
      _glyphAlpha = opacity;
      _glyphColor = particleColor;
      _glyphSize = size;
      glyph = TextPainter(
        text: TextSpan(
          text: iconLabel,
          style: TextStyle(
            fontSize: size,
            height: 1,
            color: particleColor.withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Color glowColor, particleColor;
  _ParticlePainter({required this.particles, required this.glowColor, required this.particleColor});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      p.ensureCached(glowColor, particleColor);
      final tp = p.glyph;
      final gp = p.glowPaint;
      if (tp == null || gp == null) continue;
      final cx = p.x * size.width, cy = p.y * size.height;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(p.rotation);
      // Soft glow: one radial-gradient circle (cached) — no saveLayer/blur.
      canvas.drawCircle(Offset.zero, p.size * 1.6, gp);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.particles != particles ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.particleColor != particleColor;
}

class ParticleBackground extends StatefulWidget {
  final int particleCount;
  final Color glowColor, particleColor;
  final double maxParticleSize, minParticleSize, speedMultiplier;

  const ParticleBackground({
    super.key, this.particleCount = 6,
    this.glowColor = const Color(0x15FFFFFF), this.particleColor = Colors.white,
    this.maxParticleSize = 32, this.minParticleSize = 14, this.speedMultiplier = 1.0,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _rng = Random();
  final _noteIcons = ['♩', '♪', '♫', '♬'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
    _particles = List.generate(widget.particleCount, (_) => _createParticle());
  }

  _Particle _createParticle() => _Particle(
    x: _rng.nextDouble(), y: _rng.nextDouble(),
    size: widget.minParticleSize + _rng.nextDouble() * (widget.maxParticleSize - widget.minParticleSize),
    speedX: (_rng.nextDouble() - 0.5) * 0.012 * widget.speedMultiplier,
    speedY: -_rng.nextDouble() * 0.018 * widget.speedMultiplier,
    opacity: 0.15 + _rng.nextDouble() * 0.3,
    rotation: _rng.nextDouble() * 6.28,
    rotationSpeed: (_rng.nextDouble() - 0.5) * 0.015,
    iconLabel: _noteIcons[_rng.nextInt(_noteIcons.length)],
  );

  void _resetParticle(_Particle p) {
    p.x = _rng.nextDouble(); p.y = 1.1;
    p.speedX = (_rng.nextDouble() - 0.5) * 0.012 * widget.speedMultiplier;
    p.speedY = -_rng.nextDouble() * 0.018 * widget.speedMultiplier;
    p.opacity = 0.15 + _rng.nextDouble() * 0.3;
    // Appearance changed → cached glow/glyph will be rebuilt lazily.
    p.glowPaint = null;
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _controller, builder: (context, _) {
      for (final p in _particles) {
        p.x += p.speedX; p.y += p.speedY; p.rotation += p.rotationSpeed;
        if (p.y < -0.1 || p.x < -0.1 || p.x > 1.1) _resetParticle(p);
      }
      return RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(particles: _particles, glowColor: widget.glowColor, particleColor: widget.particleColor),
        ),
      );
    });
  }
}
