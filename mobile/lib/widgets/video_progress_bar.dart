import 'package:flutter/material.dart';

/// Thin video progress indicator bar at the very bottom of the screen.
/// Shows playback position as a glowing gradient line.
class VideoProgressBar extends StatelessWidget {
  final double progress; // 0.0 → 1.0

  const VideoProgressBar({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2.5,
      child: Stack(
        children: [
          // Background track
          Container(
            color: Colors.white.withValues(alpha: 0.12),
          ),
          // Progress fill
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF42B3),
                    Color(0xFFB067FF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF42B3).withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
