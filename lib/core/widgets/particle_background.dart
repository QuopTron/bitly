import 'dart:math';
import 'package:flutter/material.dart';

class _Particle {
  double x, y, size, speedX, speedY, opacity, rotation, rotationSpeed;
  final String iconLabel;
  _Particle({required this.x, required this.y, required this.size, required this.speedX, required this.speedY, required this.opacity, required this.rotation, required this.rotationSpeed, required this.iconLabel});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Color glowColor, particleColor;
  _ParticlePainter({required this.particles, required this.glowColor, required this.particleColor});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final cx = p.x * size.width, cy = p.y * size.height;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(p.rotation);
      final gp = Paint()..color = glowColor.withValues(alpha: p.opacity * 0.08)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawCircle(const Offset(0, 0), p.size * 0.7, gp);
      final mp = Paint()..color = glowColor.withValues(alpha: p.opacity * 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(const Offset(0, 0), p.size * 0.4, mp);
      final tp = TextPainter(text: TextSpan(text: p.iconLabel, style: TextStyle(fontSize: p.size, color: particleColor.withValues(alpha: p.opacity))), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

class ParticleBackground extends StatefulWidget {
  final int particleCount;
  final Color glowColor, particleColor;
  final double maxParticleSize, minParticleSize, speedMultiplier;

  const ParticleBackground({
    super.key, this.particleCount = 12,
    this.glowColor = const Color(0xFF1ED760), this.particleColor = Colors.white,
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
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _controller, builder: (context, child) {
      return LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth, h = constraints.maxHeight;
        for (final p in _particles) {
          p.x += p.speedX; p.y += p.speedY; p.rotation += p.rotationSpeed;
          if (p.y < -0.1 || p.x < -0.1 || p.x > 1.1) _resetParticle(p);
        }
        return CustomPaint(size: Size(w, h), painter: _ParticlePainter(particles: _particles, glowColor: widget.glowColor, particleColor: widget.particleColor));
      });
    });
  }
}
