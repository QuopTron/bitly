import 'dart:math';
import 'package:flutter/material.dart';

class Particle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  double opacity;
  double rotation;
  double rotationSpeed;
  final IconData icon;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
    required this.rotation,
    required this.rotationSpeed,
    required this.icon,
  });
}

class ParticleBackground extends StatefulWidget {
  final int particleCount;
  final Color glowColor;
  final Color particleColor;
  final double maxParticleSize;
  final double minParticleSize;
  final double speedMultiplier;

  const ParticleBackground({
    super.key,
    this.particleCount = 12,
    this.glowColor = const Color(0xFF1ED760),
    this.particleColor = Colors.white,
    this.maxParticleSize = 32,
    this.minParticleSize = 14,
    this.speedMultiplier = 1.0,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;
  final _rng = Random();
  final _notes = [
    Icons.music_note,
    Icons.music_note_outlined,
    Icons.audiotrack,
    Icons.queue_music,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
    _particles = List.generate(widget.particleCount, (_) => _createParticle());
  }

  Particle _createParticle() {
    return Particle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: widget.minParticleSize +
          _rng.nextDouble() * (widget.maxParticleSize - widget.minParticleSize),
      speedX: (_rng.nextDouble() - 0.5) * 0.012 * widget.speedMultiplier,
      speedY: -_rng.nextDouble() * 0.018 * widget.speedMultiplier,
      opacity: 0.15 + _rng.nextDouble() * 0.3,
      rotation: _rng.nextDouble() * 6.28,
      rotationSpeed: (_rng.nextDouble() - 0.5) * 0.015,
      icon: _notes[_rng.nextInt(_notes.length)],
    );
  }

  void _resetParticle(Particle p) {
    p.x = _rng.nextDouble();
    p.y = 1.1;
    p.speedX = (_rng.nextDouble() - 0.5) * 0.012 * widget.speedMultiplier;
    p.speedY = -_rng.nextDouble() * 0.018 * widget.speedMultiplier;
    p.opacity = 0.15 + _rng.nextDouble() * 0.3;

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
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            for (final p in _particles) {
              p.x += p.speedX;
              p.y += p.speedY;
              p.rotation += p.rotationSpeed;

              if (p.y < -0.1 || p.x < -0.1 || p.x > 1.1) {
                _resetParticle(p);
              }
            }

            return Stack(
              children: _particles.map((p) {
                final left = p.x * w - p.size / 2;
                final top = p.y * h - p.size / 2;

                return Positioned(
                  left: left,
                  top: top,
                  child: Transform.rotate(
                    angle: p.rotation,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Opacity(
                          opacity: p.opacity * 0.12,
                          child: Icon(p.icon,
                              size: p.size + 20, color: widget.glowColor),
                        ),
                        Opacity(
                          opacity: p.opacity * 0.2,
                          child: Icon(p.icon,
                              size: p.size + 10, color: widget.glowColor),
                        ),
                        Opacity(
                          opacity: p.opacity * 0.35,
                          child: Icon(p.icon,
                              size: p.size + 4, color: widget.glowColor),
                        ),
                        Opacity(
                          opacity: p.opacity,
                          child: Icon(p.icon,
                              size: p.size, color: widget.particleColor),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
