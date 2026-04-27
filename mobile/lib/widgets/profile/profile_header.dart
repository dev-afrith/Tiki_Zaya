import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/widgets/gamification_widgets.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String displayName;
  final String profilePicUrl;
  final String bio;
  final int tzPoints;
  final VoidCallback onRewardsTap;
  final VoidCallback onPhotoTap;

  const ProfileHeader({
    super.key,
    required this.username,
    required this.displayName,
    required this.profilePicUrl,
    required this.bio,
    required this.tzPoints,
    required this.onRewardsTap,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF111111);
    final muted = isDark ? Colors.white54 : Colors.black54;

    return Stack(
      children: [
        // Background banner (subtle blur or gradient)
        Container(
          height: 140,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFF006E).withValues(alpha: 0.15),
                isDark ? Colors.black : const Color(0xFFF6F7FB),
              ],
            ),
          ),
        ),
        
        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 90, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Profile Picture with glow
                  GestureDetector(
                    onTap: onPhotoTap,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF006E).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: isDark ? Colors.black : Colors.white,
                          width: 4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: const Color(0xFF222222),
                        backgroundImage: profilePicUrl.isNotEmpty
                            ? CachedNetworkImageProvider(profilePicUrl)
                            : null,
                        child: profilePicUrl.isEmpty
                            ? Text(
                                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // TZ Points Badge
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TZPointsWidget(
                      points: tzPoints,
                      onTap: onRewardsTap,
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // User Info
              Text(
                displayName.isNotEmpty && displayName != 'Unknown' ? displayName : username,
                style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              if (username.isNotEmpty && displayName != username)
                Text(
                  '@$username',
                  style: TextStyle(color: muted, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  bio,
                  style: TextStyle(color: fg, fontSize: 14, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
