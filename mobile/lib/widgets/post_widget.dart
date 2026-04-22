import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/widgets/like_animation_widget.dart';

class ActiveLikeAnimation {
  final int id;
  final Offset position;

  const ActiveLikeAnimation({required this.id, required this.position});
}

class PostWidget extends StatelessWidget {
  final Widget child;
  final List<ActiveLikeAnimation> activeAnimations;
  final void Function(TapDownDetails details) onDoubleTapDown;
  final bool enableAnimations;
  final IconData icon;
  final Color iconColor;
  final LikeAnimationStyle style;

  const PostWidget({
    super.key,
    required this.child,
    required this.activeAnimations,
    required this.onDoubleTapDown,
    required this.enableAnimations,
    this.icon = Icons.extension_rounded,
    this.iconColor = const Color(0xFFFFB703),
    this.style = LikeAnimationStyle.puzzle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: () {},
      onDoubleTapDown: onDoubleTapDown,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (enableAnimations)
            ...activeAnimations.map((animation) {
              final jitter = _jitterForId(animation.id);
              return Positioned(
                left: animation.position.dx - 36 + jitter.dx,
                top: animation.position.dy - 36 + jitter.dy,
                child: RepaintBoundary(
                  child: LikeAnimationWidget(
                    icon: icon,
                    color: iconColor,
                    style: style,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Offset _jitterForId(int id) {
    final random = math.Random(id);
    return Offset((random.nextDouble() - 0.5) * 12, (random.nextDouble() - 0.5) * 8);
  }
}

typedef PostDoubleTapOverlay = PostWidget;
