import 'dart:math' as math;

import 'package:flutter/material.dart';

enum LikeAnimationStyle { puzzle, spark }

class LikeAnimationWidget extends StatefulWidget {
  final Duration duration;
  final double size;
  final IconData icon;
  final Color color;
  final LikeAnimationStyle style;

  const LikeAnimationWidget({
    super.key,
    this.duration = const Duration(milliseconds: 820),
    this.size = 72,
    this.icon = Icons.extension_rounded,
    this.color = const Color(0xFFFFB703),
    this.style = LikeAnimationStyle.puzzle,
  });

  @override
  State<LikeAnimationWidget> createState() => _LikeAnimationWidgetState();
}

class _LikeAnimationWidgetState extends State<LikeAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _rise;
  late final Animation<double> _scale;
  late final List<_ParticleSpec> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..forward();

    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.45, 1, curve: Curves.easeOut)),
    );
    _rise = Tween<double>(begin: 0, end: -26).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)), weight: 55),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
    ]).animate(_controller);

    _particles = _buildParticles();
  }

  List<_ParticleSpec> _buildParticles() {
    final random = math.Random();
    final count = widget.style == LikeAnimationStyle.spark ? 12 : 9;

    return List<_ParticleSpec>.generate(count, (index) {
      final angle = (-math.pi / 2) + (random.nextDouble() - 0.5) * 1.8;
      final distance = 18 + random.nextDouble() * 34;
      final dx = math.cos(angle) * distance * (0.6 + random.nextDouble() * 0.7);
      final dy = -distance * (0.85 + random.nextDouble() * 0.65);
      return _ParticleSpec(
        size: 4 + random.nextDouble() * 5,
        endDx: dx,
        endDy: dy,
        rotation: (random.nextDouble() - 0.5) * 1.8,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_controller.value);
          return Opacity(
            opacity: _opacity.value,
            child: Transform.translate(
              offset: Offset(0, _rise.value),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    ..._particles.map((particle) {
                      final x = particle.endDx * t;
                      final y = particle.endDy * t;
                      return Transform.translate(
                        offset: Offset(x, y),
                        child: Transform.rotate(
                          angle: particle.rotation * t,
                          child: Opacity(
                            opacity: 1 - t,
                            child: Container(
                              width: particle.size,
                              height: particle.size,
                              decoration: BoxDecoration(
                                color: widget.color.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    Transform.scale(
                      scale: _scale.value,
                      child: Icon(widget.icon, size: widget.size, color: widget.color),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ParticleSpec {
  final double size;
  final double endDx;
  final double endDy;
  final double rotation;

  const _ParticleSpec({
    required this.size,
    required this.endDx,
    required this.endDy,
    required this.rotation,
  });
}
