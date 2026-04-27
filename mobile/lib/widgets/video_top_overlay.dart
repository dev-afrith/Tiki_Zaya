import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/widgets/gamification_widgets.dart';
import 'package:mobile/widgets/badge_icon.dart';

/// Transparent overlay header — floats on top of video.
/// Minimal branding + notification bell. Does NOT block immersion.
class VideoTopOverlay extends StatelessWidget {
  final int tzPoints;
  final int unreadNotifications;
  final AnimationController glowController;
  final VoidCallback onRewardsTap;
  final VoidCallback onNotificationsTap;

  const VideoTopOverlay({
    super.key,
    required this.tzPoints,
    required this.unreadNotifications,
    required this.glowController,
    required this.onRewardsTap,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 14,
        right: 14,
        bottom: 10,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xAA000000),
            Color(0x44000000),
            Colors.transparent,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Row(
        children: [
          // TZ Points badge
          TZPointsWidget(
            points: tzPoints,
            onTap: onRewardsTap,
            compact: true,
          ),
          const SizedBox(width: 10),

          // Centered branding
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: glowController,
                builder: (context, child) {
                  final t = glowController.value;
                  final glow = 7 + (t * 7);
                  final scale = 1 + (t * 0.02);

                  return Transform.scale(
                    scale: scale,
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment(-1 + (t * 0.5), -0.3),
                        end: const Alignment(1, 0.5),
                        colors: const [
                          Color(0xFFFF42B3),
                          Color(0xFFB067FF),
                          Color(0xFF6AD9FF),
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'TikiZaya',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dancingScript(
                          color: Colors.white,
                          fontSize: 30,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFF42B3).withValues(alpha: 0.35),
                              blurRadius: glow,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Notification bell
          SizedBox(
            width: 38,
            height: 38,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: onNotificationsTap,
                icon: BadgeIcon(
                  icon: Icons.notifications_none_rounded,
                  color: Colors.white,
                  iconSize: 22,
                  count: unreadNotifications,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
