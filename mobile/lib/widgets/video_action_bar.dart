import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TikTok-style right-side action bar with animated icons.
/// Each button has a bounce animation on tap and a glow shadow.
class VideoActionBar extends StatelessWidget {
  final bool isLiked;
  final bool isFavorited;
  final bool isReposted;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int repostsCount;
  final int favoritesCount;
  final String profilePic;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onRepostTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback onMoreTap;
  final VoidCallback? onProfileTap;

  const VideoActionBar({
    super.key,
    required this.isLiked,
    required this.isFavorited,
    required this.isReposted,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.repostsCount,
    required this.favoritesCount,
    required this.profilePic,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onRepostTap,
    required this.onFavoriteTap,
    required this.onMoreTap,
    this.onProfileTap,
  });

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Profile avatar
        if (profilePic.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: GestureDetector(
              onTap: onProfileTap,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    profilePic,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Like
        _AnimatedActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: _formatCount(likesCount),
          color: isLiked ? const Color(0xFFFF006E) : Colors.white,
          glowColor: isLiked ? const Color(0xFFFF006E) : null,
          onTap: onLikeTap,
        ),
        const SizedBox(height: 18),

        // Comment
        _AnimatedActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: _formatCount(commentsCount),
          onTap: onCommentTap,
        ),
        const SizedBox(height: 18),

        // Repost
        _AnimatedActionButton(
          icon: Icons.repeat_rounded,
          label: _formatCount(repostsCount),
          color: isReposted ? const Color(0xFF4ADE80) : Colors.white,
          glowColor: isReposted ? const Color(0xFF4ADE80) : null,
          onTap: onRepostTap,
        ),
        const SizedBox(height: 18),

        // Share
        _AnimatedActionButton(
          icon: Icons.send_rounded,
          label: _formatCount(sharesCount),
          onTap: onShareTap,
        ),
        const SizedBox(height: 18),

        // Bookmark
        _AnimatedActionButton(
          icon: isFavorited ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: _formatCount(favoritesCount),
          color: isFavorited ? const Color(0xFFFFC107) : Colors.white,
          glowColor: isFavorited ? const Color(0xFFFFC107) : null,
          onTap: onFavoriteTap,
        ),
        const SizedBox(height: 18),

        // More
        _AnimatedActionButton(
          icon: Icons.more_horiz_rounded,
          label: '',
          color: Colors.white70,
          onTap: onMoreTap,
          iconSize: 26,
        ),
      ],
    );
  }
}

/// Action button with bounce animation on tap and optional glow.
class _AnimatedActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? glowColor;
  final VoidCallback onTap;
  final double iconSize;

  const _AnimatedActionButton({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    this.glowColor,
    required this.onTap,
    this.iconSize = 30,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween(begin: 1.0, end: 0.75).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _bounceController.forward().then((_) {
      _bounceController.reverse();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: widget.glowColor != null
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.glowColor!.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    )
                  : null,
              child: Icon(
                widget.icon,
                color: widget.color,
                size: widget.iconSize,
                shadows: const [
                  Shadow(blurRadius: 16, color: Colors.black87),
                ],
              ),
            ),
            if (widget.label.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
