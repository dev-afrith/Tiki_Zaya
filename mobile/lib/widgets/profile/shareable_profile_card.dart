import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ShareableProfileCard extends StatelessWidget {
  final String username;
  final String displayName;
  final String profilePicUrl;
  final int postsCount;
  final int followersCount;
  final int tzPoints;

  const ShareableProfileCard({
    super.key,
    required this.username,
    required this.displayName,
    required this.profilePicUrl,
    required this.postsCount,
    required this.followersCount,
    required this.tzPoints,
  });

  String _formatNumber(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF006E).withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flash_on, color: Color(0xFFFF006E), size: 18),
              const SizedBox(width: 4),
              Text(
                'TikiZaya Profile',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Profile Pic
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF006E), Color(0xFFB067FF)],
              ),
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: const Color(0xFF222222),
              backgroundImage: profilePicUrl.isNotEmpty
                  ? CachedNetworkImageProvider(profilePicUrl)
                  : null,
              child: profilePicUrl.isEmpty
                  ? Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 36),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          
          // Names
          Text(
            displayName.isNotEmpty && displayName != 'Unknown' ? displayName : username,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          if (username.isNotEmpty && displayName != username) ...[
            const SizedBox(height: 4),
            Text(
              '@$username',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Stats Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat(isDark, _formatNumber(postsCount), 'Posts'),
                _buildStat(isDark, _formatNumber(followersCount), 'Followers'),
                _buildStat(isDark, _formatNumber(tzPoints), 'TZ Points'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // QR Code Placeholder
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                Icons.qr_code_2,
                size: 100,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Scan to follow',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(bool isDark, String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
