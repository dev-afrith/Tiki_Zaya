import 'package:flutter/material.dart';

class StatsSection extends StatelessWidget {
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final VoidCallback? onPostsTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const StatsSection({
    super.key,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    this.onPostsTap,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  String _formatNumber(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(context, _formatNumber(postsCount), 'Posts', onPostsTap),
          _buildDivider(context),
          _buildStatItem(context, _formatNumber(followersCount), 'Followers', onFollowersTap),
          _buildDivider(context),
          _buildStatItem(context, _formatNumber(followingCount), 'Following', onFollowingTap),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String count, String label, VoidCallback? onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      splashColor: const Color(0xFFFF006E).withValues(alpha: 0.2),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111111),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 24,
      width: 1,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }
}
