import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/screens/comments_screen.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/screens/fullscreen_feed_screen.dart';
import 'package:mobile/screens/notifications_screen.dart';
import 'package:mobile/widgets/heart_animation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

// ─────────────────────────────────────────────────────────────
//  HOME SCREEN — Instagram + TikTok Hybrid Feed
// ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  final List<dynamic> _videos = [];
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  bool _isLoadingFeedMore = false;
  String? _feedError;
  int _currentPage = 1;
  bool _hasMore = true;
  int _focusedIndex = 0;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _feedError = null;
      });
    }

    try {
      final user = await ApiService.getUser();

      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }

      await _loadNotifications();
      await _loadFeed(reset: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedError = 'Unable to load your feed right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await ApiService.getNotifications();
      if (!mounted) return;
      final notifications = (data['notifications'] as List?) ?? [];
      setState(() {
        _unreadNotifications = notifications.where((n) => n['isRead'] != true).length;
      });
    } catch (_) {
      // Notifications should not block feed rendering.
    }
  }

  Future<void> _loadFeed({bool reset = false}) async {
    if (_isLoadingFeedMore) return;
    if (!reset && !_hasMore) return;

    if (mounted) {
      setState(() {
        _isLoadingFeedMore = true;
      });
    }

    try {
      final pageToLoad = reset ? 1 : _currentPage;
      final data = await ApiService.getFeed(page: pageToLoad, limit: 10);
      final items = (data['videos'] as List?) ?? [];
      final totalPages = (data['totalPages'] is num) ? (data['totalPages'] as num).toInt() : 1;

      if (!mounted) return;
      setState(() {
        if (reset) {
          _videos
            ..clear()
            ..addAll(items);
          _currentPage = 2;
        } else {
          _videos.addAll(items);
          _currentPage += 1;
        }
        _hasMore = pageToLoad < totalPages && items.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedError = 'Could not load videos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFeedMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadNotifications();
    await _loadFeed(reset: true);
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    await _loadNotifications();
  }

  void _onPageChanged(int index) {
    setState(() {
      _focusedIndex = index;
    });
    if (index >= _videos.length - 2) {
      _loadFeed();
    }
  }

  void _openFullscreen(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenFeedScreen(
          videos: _videos,
          initialIndex: index,
          currentUser: _currentUser,
        ),
      ),
    );
  }

  Widget _buildNotificationBadge(int count) {
    if (count <= 0) return const SizedBox.shrink();
    return Positioned(
      right: 6,
      top: 7,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFFF006E),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildFeedBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E)));
    }

    if (_feedError != null && _videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_feedError!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return const Center(
        child: Text('No videos yet. Upload your first reel!', style: TextStyle(color: Colors.white70)),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFF006E),
      onRefresh: _refresh,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                return FeedPost(
                  video: _videos[index],
                  shouldPlay: _focusedIndex == index,
                  currentUser: _currentUser,
                  isFullscreen: false,
                  onRequestFullscreen: () => _openFullscreen(index),
                );
              },
            ),
          ),
          if (_isLoadingFeedMore)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF006E)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF3B8E), Color(0xFF8B5CF6), Color(0xFF3B82F6)],
          ).createShader(bounds),
          child: Text(
            'TikiZaya',
            style: GoogleFonts.yellowtail(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: _openNotifications,
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
              ),
              _buildNotificationBadge(_unreadNotifications),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF070707), Color(0xFF101020), Color(0xFF070707)],
          ),
        ),
        child: _buildFeedBody(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  FEED POST — Individual video card within the feed
// ─────────────────────────────────────────────────────────────

class FeedPost extends StatefulWidget {
  final dynamic video;
  final bool shouldPlay;
  final Map<String, dynamic>? currentUser;
  final bool isFullscreen;
  final VoidCallback? onRequestFullscreen;

  const FeedPost({
    super.key,
    required this.video,
    required this.shouldPlay,
    this.currentUser,
    this.isFullscreen = false,
    this.onRequestFullscreen,
  });

  @override
  State<FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends State<FeedPost> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isLiked = false;
  bool _isFavorited = false;
  bool _isFollowing = false;
  bool _isReposted = false;
  bool _isArchived = false;
  bool _isHiddenFromFeed = false;
  bool _hasVideoError = false;
  int _likesCount = 0;
  int _favoritesCount = 0;
  int _repostsCount = 0;
  int _sharesCount = 0;
  int _viewsCount = 0;
  int _commentsCountLive = 0;
  Timer? _statsTimer;
  final List<Offset> _tapPositions = [];

  @override
  void initState() {
    super.initState();
    _likesCount = (widget.video['likes'] as List?)?.length ?? 0;
    _favoritesCount = (widget.video['favorites'] as List?)?.length ?? 0;
    _repostsCount = (widget.video['repostsCount'] is num) ? (widget.video['repostsCount'] as num).toInt() : 0;
    _sharesCount = (widget.video['sharesCount'] is num) ? (widget.video['sharesCount'] as num).toInt() : 0;
    _viewsCount = (widget.video['viewsCount'] is num)
      ? (widget.video['viewsCount'] as num).toInt()
      : (widget.video['views'] is num ? (widget.video['views'] as num).toInt() : 0);
    _commentsCountLive = (widget.video['commentsCount'] is num) ? (widget.video['commentsCount'] as num).toInt() : 0;
    _isArchived = widget.video['isArchived'] == true;
    _initVideo();
    _checkInitialStates();
    _startStatsPollingIfNeeded();

    // Increment view after 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && widget.shouldPlay) ApiService.incrementVideoView(widget.video['_id']);
    });
  }

  Future<void> _checkInitialStates() async {
    final user = widget.currentUser ?? await ApiService.getUser();
    if (user != null && mounted) {
      final likes = widget.video['likes'] as List? ?? [];
      final favorites = widget.video['favorites'] as List? ?? [];
      final following = (user['following'] as List?) ?? [];
      final reposts = (user['reposts'] as List?) ?? [];
      final authorId = widget.video['userId'] is Map ? widget.video['userId']['_id']?.toString() : widget.video['userId']?.toString();
      final videoId = widget.video['_id']?.toString();
      setState(() {
        _isLiked = likes.contains(user['id']);
        _isFavorited = favorites.contains(user['id']);
        _isFollowing = authorId != null && following.any((item) => item.toString() == authorId);
        _isReposted = videoId != null && reposts.any((item) => item.toString() == videoId);
      });
    }
  }

  @override
  void didUpdateWidget(FeedPost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      if (widget.shouldPlay && !oldWidget.shouldPlay) {
        _controller.play();
        _startStatsPollingIfNeeded();
      } else if (!widget.shouldPlay && oldWidget.shouldPlay) {
        _controller.pause();
        _stopStatsPolling();
      }
    }
  }

  void _startStatsPollingIfNeeded() {
    _stopStatsPolling();
    if (!widget.shouldPlay) return;
    _syncVideoStats();
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !widget.shouldPlay) return;
      _syncVideoStats();
    });
  }

  void _stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void> _syncVideoStats() async {
    final videoId = (widget.video['_id'] ?? '').toString();
    if (videoId.isEmpty) return;
    try {
      final stats = await ApiService.getVideoStats(videoId);
      if (!mounted) return;
      setState(() {
        _repostsCount = (stats['repostsCount'] is num) ? (stats['repostsCount'] as num).toInt() : _repostsCount;
        _sharesCount = (stats['sharesCount'] is num) ? (stats['sharesCount'] as num).toInt() : _sharesCount;
        _commentsCountLive = (stats['commentsCount'] is num) ? (stats['commentsCount'] as num).toInt() : _commentsCountLive;
        _viewsCount = (stats['viewsCount'] is num) ? (stats['viewsCount'] as num).toInt() : _viewsCount;
      });
    } catch (_) {
      // Keep video playback smooth when stats API fails.
    }
  }

  Future<void> _initVideo() async {
    final videoUrl = (widget.video['videoUrl'] ?? '').toString();
    if (videoUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasVideoError = true;
        });
      }
      return;
    }

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    try {
      await _controller.initialize();
      _controller.setLooping(true);
      if (widget.shouldPlay) _controller.play();
      if (mounted) setState(() { _isInitialized = true; });
    } catch (e) {
      debugPrint('Video error: $e');
    }
  }

  Future<void> _toggleLike() async {
    try {
      final videoId = (widget.video['_id'] ?? '').toString();
      if (videoId.isEmpty) return;
      final result = await ApiService.toggleLike(videoId);
      if (mounted) {
        final likedNow = result['liked'] ?? false;
        setState(() {
          _isLiked = likedNow;
          _likesCount = result['likes'] ?? _likesCount;
        });
        if (likedNow) {
          final size = MediaQuery.of(context).size;
          setState(() {
            _tapPositions.add(Offset(size.width / 2, size.height / 2.4));
          });
          Timer(const Duration(milliseconds: 650), () {
            if (!mounted) return;
            setState(() {
              if (_tapPositions.isNotEmpty) {
                _tapPositions.removeAt(0);
              }
            });
          });
        }
      }
    } catch (e) { debugPrint('Like error: $e'); }
  }

  Future<void> _toggleFavorite() async {
    try {
      final videoId = (widget.video['_id'] ?? '').toString();
      if (videoId.isEmpty) return;
      final result = await ApiService.toggleFavorite(videoId);
      if (mounted) {
        setState(() {
          _isFavorited = result['favorited'] ?? false;
          _favoritesCount = result['favoritesCount'] ?? _favoritesCount;
        });
      }
    } catch (e) { debugPrint('Favorite error: $e'); }
  }

  Future<void> _toggleFollowAuthor() async {
    final author = widget.video['userId'];
    final authorId = author is Map ? author['_id']?.toString() : author?.toString();
    if (authorId == null) return;
    try {
      await ApiService.toggleFollow(authorId);
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    } catch (e) {
      debugPrint('Follow error: $e');
    }
  }

  Future<void> _toggleRepost() async {
    try {
      final videoId = (widget.video['_id'] ?? '').toString();
      if (videoId.isEmpty) return;
      final result = await ApiService.toggleRepost(videoId);
      if (mounted) {
        setState(() {
          _isReposted = result['reposted'] ?? false;
          _repostsCount = (result['repostsCount'] is num) ? (result['repostsCount'] as num).toInt() : _repostsCount;
        });
      }
    } catch (e) {
      debugPrint('Repost error: $e');
    }
  }

  void _showAccountDetails(Map<String, dynamic> user) {
    final country = (user['country'] ?? '').toString();
    final joined = (user['createdAt'] ?? '').toString();
    String joinedDate = 'Unknown';
    if (joined.isNotEmpty) {
      try {
        joinedDate = DateTime.parse(joined).toLocal().toIso8601String().split('T').first;
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12162A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${user['username'] ?? 'Unknown'}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _accountInfoRow('Based in', country.isEmpty ? 'Not set' : country),
              _accountInfoRow('Date joined', joinedDate),
              _accountInfoRow('Privacy', (user['isPrivate'] == true) ? 'Private' : 'Public'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showMoreActions() {
    final dynamic userRaw = widget.video['userId'];
    final Map<String, dynamic>? user = userRaw is Map<String, dynamic> ? userRaw : null;
    final authorId = userRaw is Map ? userRaw['_id']?.toString() : userRaw?.toString();
    if (authorId == null || authorId.isEmpty) return;

    final myId = widget.currentUser?['id']?.toString() ?? widget.currentUser?['_id']?.toString();
    final isOwnPost = myId == authorId;

    final description = _videoDescription();
    final postedOn = _formatPostedDate(widget.video['createdAt']?.toString());

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12162A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
            ),
            const SizedBox(height: 16),
            const Text('Video details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description.isEmpty ? 'No description added.' : description,
                      style: const TextStyle(color: Colors.white, height: 1.35),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.length > 140)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Tap copy link to share this post.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _statTile('Views', _formatCount(_viewsCount))),
                  const SizedBox(width: 10),
                  Expanded(child: _statTile('Likes', _formatCount(_likesCount))),
                  const SizedBox(width: 10),
                  Expanded(child: _statTile('Shares', _formatCount(_sharesCount))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(postedOn, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 10),
            if (!isOwnPost)
              ListTile(
                leading: Icon(
                  _isFollowing ? Icons.person_remove_alt_1_outlined : Icons.person_add_alt_1_outlined,
                  color: Colors.white,
                ),
                title: Text(_isFollowing ? 'Unfollow' : 'Follow', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleFollowAuthor();
                },
              ),
            if (isOwnPost)
              ListTile(
                leading: const Icon(Icons.archive_outlined, color: Colors.white),
                title: const Text('Archive reel', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _archiveCurrentVideo();
                },
              ),
            if (isOwnPost)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                title: const Text('Delete reel', style: TextStyle(color: Colors.redAccent)),
                subtitle: const Text('This will be deleted permanently', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteVideo();
                },
              ),
            ListTile(
              leading: Icon(_isFavorited ? Icons.bookmark : Icons.bookmark_border, color: Colors.white),
              title: Text(_isFavorited ? 'Save video' : 'Save video', style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _toggleFavorite();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.white),
              title: const Text('Copy link', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _copyVideoLink();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.white),
              title: const Text('Report', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _reportVideo();
              },
            ),
            const Divider(color: Colors.white12),
            if (user != null)
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text('About this account', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showAccountDetails(user);
                },
              ),
          ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareVideoExternal() async {
    final username = widget.video['userId'] is Map ? (widget.video['userId']['username'] ?? 'User').toString() : 'User';
    final caption = (widget.video['caption'] ?? 'Check this out!').toString();
    final url = (widget.video['videoUrl'] ?? '').toString();
    final videoId = (widget.video['_id'] ?? '').toString();
    if (videoId.isNotEmpty) {
      try {
        final shareResult = await ApiService.incrementVideoShare(videoId);
        if (mounted) {
          setState(() {
            _sharesCount = (shareResult['sharesCount'] is num) ? (shareResult['sharesCount'] as num).toInt() : _sharesCount;
          });
        }
      } catch (_) {}
    }
    await Share.share('$caption\n\nBy @$username on TikiZaya!\n$url', subject: 'TikiZaya Video');
  }

  Future<void> _copyVideoLink() async {
    final url = (widget.video['videoUrl'] ?? '').toString();
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video link copied')),
      );
    }
  }

  void _reportVideo() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted. Thanks for helping keep TikiZaya safe.')),
    );
  }

  String _videoDescription() {
    final description = (widget.video['description'] ?? widget.video['caption'] ?? '').toString().trim();
    return description;
  }

  String _formatPostedDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Posted date unavailable';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return 'Posted on ${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return 'Posted date unavailable';
    }
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _shareVideoInApp(String toUserId, String toUsername) async {
    final username = widget.video['userId'] is Map ? (widget.video['userId']['username'] ?? 'User').toString() : 'User';
    final caption = (widget.video['caption'] ?? 'Check this out!').toString();
    final url = (widget.video['videoUrl'] ?? '').toString();
    final thumbnailUrl = (widget.video['thumbnailUrl'] ?? '').toString();
    final ownerId = widget.video['userId'] is Map ? (widget.video['userId']['_id'] ?? '').toString() : '';
    final videoId = (widget.video['_id'] ?? '').toString();

    try {
      await ApiService.sendMessage(
        toUserId,
        'Shared a reel',
        messageType: 'reel',
        sharedVideo: {
          'videoId': videoId,
          'videoUrl': url,
          'thumbnailUrl': thumbnailUrl,
          'caption': caption,
          'ownerId': ownerId,
          'ownerUsername': username,
        },
      );

      if (videoId.isNotEmpty) {
        try {
          final shareResult = await ApiService.incrementVideoShare(videoId);
          if (mounted) {
            setState(() {
              _sharesCount = (shareResult['sharesCount'] is num) ? (shareResult['sharesCount'] as num).toInt() : _sharesCount;
            });
          }
        } catch (_) {
          // Message send already succeeded; ignore counter update failures.
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shared to @$toUsername successfully')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to share in app')),
        );
      }
    }
  }

  Future<void> _openShareOptions() async {
    final users = await ApiService.getSuggestedUsers();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12162A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Share',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Share in app', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 118,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: users.length > 12 ? 12 : users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userId = (user['_id'] ?? '').toString();
                    final name = (user['username'] ?? 'user').toString();
                    final profilePic = (user['profilePic'] ?? '').toString();
                    if (userId.isEmpty) return const SizedBox.shrink();

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _shareVideoInApp(userId, name);
                      },
                      child: SizedBox(
                        width: 82,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF3B8E), Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.white12,
                                    backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                                    child: profilePic.isEmpty
                                        ? Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '@$name',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Spacer(),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.apps_rounded, color: Colors.white),
                title: const Text('Share to WhatsApp, Instagram, and more', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _shareVideoExternal();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _archiveCurrentVideo() async {
    final videoId = (widget.video['_id'] ?? '').toString();
    if (videoId.isEmpty) return;
    try {
      await ApiService.archiveVideo(videoId);
      if (!mounted) return;
      setState(() {
        _isArchived = true;
        _isHiddenFromFeed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reel archived and moved to hidden contents')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to archive reel')),
      );
    }
  }

  Future<void> _confirmDeleteVideo() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('Delete Reel?', style: TextStyle(color: Colors.white)),
        content: const Text('This will be deleted permanently.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final videoId = (widget.video['_id'] ?? '').toString();
    if (videoId.isEmpty) return;

    try {
      await ApiService.deleteVideo(videoId);
      if (!mounted) return;
      setState(() {
        _isHiddenFromFeed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reel deleted permanently')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete reel')),
      );
    }
  }

  void _showSoundInfo() {
    final metadata = widget.video['editingMetadata'];
    String soundName = 'Original Sound';
    if (metadata is Map && metadata['soundName'] != null && metadata['soundName'].toString().trim().isNotEmpty) {
      soundName = metadata['soundName'].toString().trim();
    }
    if (widget.video['soundName'] != null && widget.video['soundName'].toString().trim().isNotEmpty) {
      soundName = widget.video['soundName'].toString().trim();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('Sound', style: TextStyle(color: Colors.white)),
        content: Text(soundName, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _handleDoubleTap(TapDownDetails details) {
    setState(() {
      _tapPositions.add(details.localPosition);
      if (!_isLiked) _toggleLike();
    });
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() { _tapPositions.clear(); });
    });
  }

  @override
  void dispose() {
    _stopStatsPolling();
    _controller.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  // ─── EDITING HELPERS ──────────────────────────────
  
  static const Map<String, List<double>> _kFilterMatrices = {
    'Vivid': [1.3, 0, 0, 0, -15, 0, 1.3, 0, 0, -15, 0, 0, 1.3, 0, -15, 0, 0, 0, 1, 0],
    'Warm': [1.2, 0.1, 0, 0, 10, 0, 1.0, 0, 0, 5, 0, 0, 0.85, 0, -10, 0, 0, 0, 1, 0],
    'Cool': [0.85, 0, 0.15, 0, -5, 0, 1.0, 0.1, 0, 0, 0.1, 0, 1.2, 0, 15, 0, 0, 0, 1, 0],
    'Noir': [0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0, 0, 0, 1, 0],
    'Sepia': [0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534, 0.131, 0, 0, 0, 0, 0, 1, 0],
    'Vintage': [0.9, 0.15, 0.05, 0, 10, 0.1, 0.85, 0.05, 0, 5, 0.05, 0.1, 0.7, 0, 20, 0, 0, 0, 1, 0],
    'Sunset': [1.3, 0.2, 0, 0, 20, 0.1, 1.0, 0, 0, 10, 0, 0.1, 0.7, 0, -15, 0, 0, 0, 1, 0],
    'Neon': [1.4, 0, 0, 0, -20, 0, 0.6, 0.4, 0, -10, 0, 0.4, 1.4, 0, -20, 0, 0, 0, 1, 0],
    'Fade': [1, 0, 0, 0, 30, 0, 1, 0, 0, 30, 0, 0, 1, 0, 30, 0, 0, 0, 0.85, 0],
  };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 360;
    final railRight = isCompact ? 5.0 : 8.0;
    final railBottom = media.size.height * 0.095;
    final railSpacing = isCompact ? 11.0 : 14.0;
    final railIconSize = isCompact ? 24.0 : 27.0;
    final railLabelSize = isCompact ? 9.0 : 10.0;
    final bottomRightReserve = isCompact ? 72.0 : 86.0;

    final user = widget.video['userId'];
    final username = user is Map ? (user['username'] ?? 'Unknown').toString() : 'Unknown';
    final profilePic = user is Map ? (user['profilePic'] ?? '').toString() : '';
    final authorId = user is Map ? (user['_id'] ?? '').toString() : user?.toString() ?? '';
    final myId = widget.currentUser?['id']?.toString() ?? widget.currentUser?['_id']?.toString() ?? '';
    final isOwnReel = authorId.isNotEmpty && myId.isNotEmpty && authorId == myId;
    final canFollow = authorId.isNotEmpty && myId.isNotEmpty && !isOwnReel;
    final commentsCount = _commentsCountLive;
    final timeAgo = _timeAgo(widget.video['createdAt']?.toString());
    
    // Metadata
    final meta = widget.video['editingMetadata'] ?? {};
    final filterName = meta is Map ? (meta['filter'] as String? ?? 'Original') : 'Original';
    final speed = meta is Map && meta['speed'] is num ? (meta['speed'] as num).toDouble() : 1.0;
    final texts = meta is Map ? (meta['texts'] as List? ?? []) : [];

    if (_isInitialized && _controller.value.playbackSpeed != speed) {
      _controller.setPlaybackSpeed(speed);
    }

    if (_isHiddenFromFeed || _isArchived) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text('This reel is hidden', style: TextStyle(color: Colors.white54)),
      );
    }

    return Column(
      children: [
        // ── POST HEADER: avatar + username + timestamp ──
        if (!widget.isFullscreen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (authorId.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: authorId)));
                    }
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: profilePic.isNotEmpty
                          ? Image.network(
                              profilePic,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFFF006E),
                                child: Center(child: Text(username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFFF006E),
                              child: Center(child: Text(username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      if (timeAgo.isNotEmpty)
                        Text(timeAgo, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox.shrink(),
              ],
            ),
          ),

        // ── VIDEO CONTENT + overlays ──
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video player (with Filter)
              GestureDetector(
                onDoubleTapDown: _handleDoubleTap,
                onTap: () {
                  if (widget.isFullscreen) {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                    setState(() {});
                  } else {
                    widget.onRequestFullscreen?.call();
                  }
                },
                child: _isInitialized
                    ? Container(
                        color: Colors.black,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: _buildFilteredVideo(filterName),
                          ),
                        ),
                      )
                    : _hasVideoError
                        ? const Center(
                            child: Text(
                              'Video unavailable',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E))),
              ),

              // Text Overlays
              ...texts.map((t) {
                final pos = t['position'] ?? {'dx': 100.0, 'dy': 200.0};
                final colorStr = t['color'] as String? ?? '#ffffffff';
                final color = Color(int.parse(colorStr.replaceFirst('#', '0x'), radix: 16));
                
                return Positioned(
                  left: (pos['dx'] ?? 100.0).toDouble(),
                  top: (pos['dy'] ?? 200.0).toDouble() - (widget.isFullscreen ? 0 : 60),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      t['text'] ?? '',
                      style: TextStyle(
                        color: color,
                        fontSize: (t['fontSize'] ?? 20.0).toDouble(),
                        fontWeight: (t['bold'] ?? true) ? FontWeight.bold : FontWeight.normal,
                        shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                  ),
                );
              }),

              // Floating hearts from double-tap
              ..._tapPositions.map((pos) => Positioned(
                left: pos.dx - 40,
                top: pos.dy - 40,
                child: HeartAnimation(
                  isAnimating: true,
                  child: const Icon(Icons.favorite, color: Color(0xFFFF006E), size: 80),
                ),
              )),

              // ── RIGHT SIDE: Engagement buttons ──
              Positioned(
                right: railRight,
                bottom: railBottom,
                child: Column(
                  children: [
                    // Like
                    _buildEngagement(
                      icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                      label: _formatCount(_likesCount),
                      color: _isLiked ? const Color(0xFFFF006E) : Colors.white,
                      onTap: _toggleLike,
                      iconSize: railIconSize,
                      labelSize: railLabelSize,
                    ),
                    SizedBox(height: railSpacing),
                    // Comment
                    _buildEngagement(
                      icon: Icons.chat_bubble_outline,
                      label: _formatCount(commentsCount),
                      iconSize: railIconSize,
                      labelSize: railLabelSize,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => SizedBox(
                            height: MediaQuery.of(context).size.height * 0.75,
                            child: CommentsSheet(videoId: (widget.video['_id'] ?? '').toString()),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: railSpacing),
                    _buildEngagement(
                      icon: Icons.repeat_rounded,
                      label: _formatCount(_repostsCount),
                      color: _isReposted ? const Color(0xFF4ADE80) : Colors.white,
                      onTap: _toggleRepost,
                      iconSize: railIconSize,
                      labelSize: railLabelSize,
                    ),
                    SizedBox(height: railSpacing),
                    // Share
                    _buildEngagement(
                      icon: Icons.send_outlined,
                      label: _formatCount(_sharesCount),
                      onTap: _openShareOptions,
                      iconSize: railIconSize,
                      labelSize: railLabelSize,
                    ),
                    SizedBox(height: railSpacing),
                    _buildEngagement(
                      icon: _isFavorited ? Icons.bookmark : Icons.bookmark_border,
                      label: _formatCount(_favoritesCount),
                      color: _isFavorited ? const Color(0xFFFFC107) : Colors.white,
                      onTap: _toggleFavorite,
                      iconSize: railIconSize,
                      labelSize: railLabelSize,
                    ),
                    SizedBox(height: railSpacing),
                    _buildEngagement(
                      icon: Icons.more_horiz,
                      label: '',
                      color: Colors.white70,
                      onTap: _showMoreActions,
                      iconSize: railIconSize,
                      labelSize: railLabelSize,
                    ),
                  ],
                ),
              ),

              // ── BOTTOM LEFT: Caption + music ──
              Positioned(
                left: 12,
                bottom: 26,
                right: bottomRightReserve,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: authorId.isEmpty
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ProfileScreen(userId: authorId)),
                                    );
                                  },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                                  child: profilePic.isEmpty
                                      ? Text(
                                          username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  '@$username',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          if (canFollow) ...[
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _toggleFollowAuthor,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                child: Container(
                                  key: ValueKey(_isFollowing ? 'following' : 'follow'),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isFollowing ? Colors.white12 : const Color(0xFFFF006E),
                                    border: _isFollowing ? Border.all(color: Colors.white24) : null,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _isFollowing ? 'Following' : 'Follow',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_videoDescription().isNotEmpty)
                      Text(
                        _videoDescription(),
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              Positioned(
                right: 12,
                bottom: 8,
                child: GestureDetector(
                  onTap: _showSoundInfo,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilteredVideo(String filterName) {
    Widget video = VideoPlayer(_controller);
    if (_kFilterMatrices.containsKey(filterName)) {
      video = ColorFiltered(
        colorFilter: ColorFilter.matrix(_kFilterMatrices[filterName]!),
        child: video,
      );
    }
    return video;
  }

  Widget _buildEngagement({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    VoidCallback? onTap,
    double iconSize = 30,
    double labelSize = 11,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: iconSize, shadows: const [Shadow(blurRadius: 12, color: Colors.black54)]),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.white, fontSize: labelSize, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
