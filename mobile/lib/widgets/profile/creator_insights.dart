import 'package:flutter/material.dart';

class CreatorInsights extends StatelessWidget {
  final int totalLikes;
  final int totalViews;

  const CreatorInsights({
    super.key,
    required this.totalLikes,
    required this.totalViews,
  });

  String _formatNumber(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildInsight(context, Icons.favorite_rounded, const Color(0xFFFF006E), _formatNumber(totalLikes), 'Likes'),
            Container(height: 20, width: 1, color: isDark ? Colors.white12 : Colors.black12),
            _buildInsight(context, Icons.play_arrow_rounded, const Color(0xFF6AD9FF), _formatNumber(totalViews), 'Views'),
          ],
        ),
      ),
    );
  }

  Widget _buildInsight(BuildContext context, IconData icon, Color iconColor, String count, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
