import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Bottom-left caption section with gradient background for readability.
/// Shows username, follow button, caption with highlighted hashtags,
/// and a sound indicator.
class VideoCaptionOverlay extends StatelessWidget {
  final String username;
  final String profilePic;
  final String authorId;
  final String caption;
  final bool isFollowing;
  final bool canFollow;
  final VoidCallback onFollowTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSoundTap;

  const VideoCaptionOverlay({
    super.key,
    required this.username,
    required this.profilePic,
    required this.authorId,
    required this.caption,
    required this.isFollowing,
    required this.canFollow,
    required this.onFollowTap,
    required this.onProfileTap,
    required this.onSoundTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 80, // Reserve space for the action bar
        bottom: bottomPadding + 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xCC000000),
            Color(0x66000000),
            Colors.transparent,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username row with profile pic and follow
          Row(
            children: [
              // Profile avatar
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF3B8E), Color(0xFF8B5CF6)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: ClipOval(
                      child: profilePic.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: profilePic,
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const SizedBox.shrink(),
                              errorWidget: (_, __, ___) => _buildInitialAvatar(),
                            )
                          : _buildInitialAvatar(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Username
              GestureDetector(
                onTap: onProfileTap,
                child: Text(
                  '@$username',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Follow button
              if (canFollow)
                GestureDetector(
                  onTap: onFollowTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: isFollowing
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFFF006E), Color(0xFFFF4499)],
                            ),
                      color: isFollowing ? Colors.white.withValues(alpha: 0.12) : null,
                      border: isFollowing
                          ? Border.all(color: Colors.white.withValues(alpha: 0.25))
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isFollowing
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFFFF006E).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Caption with hashtag highlighting
          if (caption.isNotEmpty)
            _buildRichCaption(caption),

          const SizedBox(height: 8),

          // Sound indicator row
          GestureDetector(
            onTap: onSoundTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white70,
                  size: 14,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                ),
                const SizedBox(width: 4),
                const Flexible(
                  child: Text(
                    'Original Sound',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar() {
    return Container(
      color: Colors.white12,
      alignment: Alignment.center,
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Build caption with highlighted hashtags
  Widget _buildRichCaption(String text) {
    final words = text.split(' ');
    final spans = <InlineSpan>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.startsWith('#') || word.startsWith('@')) {
        spans.add(TextSpan(
          text: '$word ',
          style: const TextStyle(
            color: Color(0xFF7DD3FC),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
            shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: '$word ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.35,
            shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
          ),
        ));
      }
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}
