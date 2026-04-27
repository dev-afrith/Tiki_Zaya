import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileVideoGrid extends StatelessWidget {
  final List<dynamic> videos;
  final bool isPostsTab;
  final Map<String, dynamic>? currentUser;
  final void Function(int) onVideoTap;

  const ProfileVideoGrid({
    super.key,
    required this.videos,
    required this.isPostsTab,
    required this.currentUser,
    required this.onVideoTap,
  });

  String _videoPreviewUrl(Map<String, dynamic> video) {
    final thumbnail = (video['thumbnailUrl'] ?? '').toString();
    if (thumbnail.isNotEmpty) return thumbnail;

    final videoUrl = (video['videoUrl'] ?? '').toString();
    if (videoUrl.contains('cloudinary.com') && videoUrl.contains('/video/upload/')) {
      return videoUrl.replaceFirst('/video/upload/', '/video/upload/so_1,q_auto,f_jpg/');
    }
    return '';
  }

  String _formatNumber(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60, bottom: 40),
        child: Column(
          children: [
            Icon(Icons.video_library_outlined, size: 60, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              isPostsTab ? 'No videos yet' : 'No reposts yet',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.grey[500],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // Handled by parent ScrollView
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.7, // Taller aspect ratio for TikTok-like thumbnails
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final item = videos[index] as Map<String, dynamic>;
        final previewUrl = _videoPreviewUrl(item);
        final isPinned = isPostsTab && index == 0; // Mock pinned logic

        return GestureDetector(
          onTap: () => onVideoTap(index),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: isPinned ? Border.all(color: const Color(0xFFFF006E), width: 1.5) : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isPinned ? 8.5 : 10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail (Lazy loaded via CachedNetworkImage)
                  if (previewUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: previewUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.white.withValues(alpha: 0.05)),
                      errorWidget: (context, url, error) => Container(color: Colors.white.withValues(alpha: 0.1)),
                    )
                  else
                    Container(color: Colors.white.withValues(alpha: 0.1)),
                  
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.5, 0.8, 1.0],
                      ),
                    ),
                  ),

                  // Pinned Badge
                  if (isPinned)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF006E),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.push_pin_rounded, color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text('Pinned', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),

                  // Stats Overlay
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              _formatNumber(item['views'] ?? 0),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        if (!isPostsTab) // Show repost count for reposts tab
                          Row(
                            children: [
                              const Icon(Icons.repeat_rounded, color: Colors.white, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                '${item['repostsCount'] ?? 0}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
