import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/screens/comments_screen.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/screens/fullscreen_feed_screen.dart';
import 'package:mobile/screens/notifications_screen.dart';
import 'package:mobile/screens/rewards_screen.dart';
import 'package:mobile/widgets/like_animation_widget.dart';
import 'package:mobile/widgets/post_widget.dart';
import 'package:mobile/widgets/video_top_overlay.dart';
import 'package:mobile/widgets/video_action_bar.dart';
import 'package:mobile/widgets/video_caption_overlay.dart';
import 'package:mobile/widgets/video_progress_bar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:mobile/services/auth_provider.dart';
import 'package:mobile/services/feed_provider.dart';
import 'package:mobile/services/video_preload_manager.dart';
import 'dart:async';

// ─────────────────────────────────────────────────────────────
//  HOME SCREEN — Instagram + TikTok Hybrid Feed
// ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _titleGlowController;
  final VideoPreloadManager _preloadManager = VideoPreloadManager();
  int _focusedIndex = 0;
  int _tzPoints = 0;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _titleGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _titleGlowController.dispose();
    _pageController.dispose();
    _preloadManager.disposeAll();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final feed = Provider.of<FeedProvider>(context, listen: false);

    try {
      final summary = await ApiService.getGamificationSummary();
      _applyGamificationSummary(summary);
      await _maybeShowWelcome(summary);
      await _loadNotifications();
      await feed.fetchFeed(reset: true);
    } catch (_) {}
  }

  void _applyGamificationSummary(Map<String, dynamic> summary) {
    final user = summary['user'] as Map<String, dynamic>?;
    final gamification = summary['gamification'] as Map<String, dynamic>? ?? <String, dynamic>{};

    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (user != null) auth.updateProfile(user);
    
    setState(() {
      _tzPoints = _readInt(gamification['points'], _tzPoints);
      _streakDays = _readInt(gamification['streakDays'], _streakDays);
    });
  }

  Future<void> _refreshGamificationOnly() async {
    try {
      final summary = await ApiService.getGamificationSummary();
      _applyGamificationSummary(summary);
    } catch (_) {}
  }

  Future<void> _maybeShowWelcome(Map<String, dynamic> summary) async {
    final user = summary['user'];
    final gamification = summary['gamification'];
    if (user is! Map || gamification is! Map) return;

    final welcomeAt = gamification['welcomeBonusGrantedAt'];
    final userId = (user['_id'] ?? user['id'] ?? '').toString();
    if (userId.isEmpty || welcomeAt == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'tz_welcome_seen_$userId';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to Tikizaya. 100 TZ points added.')),
      );
    });
  }

  Future<void> _refresh() async {
    Provider.of<NotificationProvider>(context, listen: false).fetchCounts();
    await Provider.of<FeedProvider>(context, listen: false).fetchFeed(reset: true);
  }

  void _openRewards() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RewardsScreen(),
      ),
    );
  }

  int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback;
  }



  void _openFullscreen(int index, List<dynamic> videos, Map<String, dynamic>? currentUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenFeedScreen(
          videos: videos,
          initialIndex: index,
          currentUser: currentUser,
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }



  Widget _buildFeedBody() {
    return Consumer2<FeedProvider, AuthProvider>(
      builder: (context, feed, auth, child) {
        if (feed.isLoading && feed.videos.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E)));
        }

        if (feed.error != null && feed.videos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(feed.error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
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

        if (feed.videos.isEmpty) {
          return const Center(
            child: Text('No videos yet. Upload your first reel!', style: TextStyle(color: Colors.white70)),
          );
        }

        // Initialize preload manager for the first page
        if (feed.videos.isNotEmpty && _focusedIndex == 0) {
          _preloadManager.setCurrentIndex(0, feed.videos);
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
                  onPageChanged: (index) {
                    setState(() { _focusedIndex = index; });
                    // Update preload manager window
                    _preloadManager.setCurrentIndex(index, feed.videos);
                    if (index >= feed.videos.length - 2) {
                      feed.fetchFeed();
                    }
                  },
                  itemCount: feed.videos.length,
                  itemBuilder: (context, index) {
                    return FeedPost(
                      video: feed.videos[index],
                      shouldPlay: _focusedIndex == index,
                      shouldPreload: _focusedIndex + 1 == index,
                      currentUser: auth.user,
                      isFullscreen: false,
                      externalController: _preloadManager.getController(index),
                      onRequestFullscreen: () => _openFullscreen(index, feed.videos, auth.user),
                      onGamificationChanged: _refreshGamificationOnly,
                    );
                  },
                ),
              ),
              if (feed.isLoadingMore)
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set immersive status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen video feed
          _buildFeedBody(),

          // Transparent top overlay (branding + notifications)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Consumer<NotificationProvider>(
              builder: (context, notificationProvider, _) {
                return VideoTopOverlay(
                  tzPoints: _tzPoints,
                  unreadNotifications: notificationProvider.unreadNotifications,
                  glowController: _titleGlowController,
                  onRewardsTap: _openRewards,
                  onNotificationsTap: _openNotifications,
                );
              },
            ),
          ),
        ],
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
  final bool shouldPreload;
  final Map<String, dynamic>? currentUser;
  final bool isFullscreen;
  final VoidCallback? onRequestFullscreen;
  final VoidCallback? onGamificationChanged;
  final String? messageIdForStreak;
  /// When provided by VideoPreloadManager, FeedPost uses this controller
  /// instead of creating its own. This is the key memory optimization.
  final VideoPlayerController? externalController;

  const FeedPost({
    super.key,
    required this.video,
    required this.shouldPlay,
    this.shouldPreload = false,
    this.currentUser,
    this.isFullscreen = false,
    this.onRequestFullscreen,
    this.onGamificationChanged,
    this.messageIdForStreak,
    this.externalController,
  });

  @override
  State<FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends State<FeedPost> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _ownsController = true; // false when using external controller
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
  Timer? _watchTimer;
  final List<ActiveLikeAnimation> _activeLikeAnimations = [];
  int _animationIdSeed = 0;
  bool _isLikeRequestInFlight = false;
  DateTime? _lastDoubleTapAt;
  bool _streakAcknowledged = false;
  double _lastTrackedWatchPosition = 0;

  bool get canFollow {
    final author = widget.video['userId'];
    final authorId = author is Map ? author['_id']?.toString() : author?.toString();
    final myId = widget.currentUser?['id']?.toString() ?? widget.currentUser?['_id']?.toString();
    return authorId != null && myId != authorId && !_isFollowing;
  }

  // Toggle this from app settings when needed.
  bool _enableDoubleTapAnimations = true;
  LikeAnimationStyle _animationStyle = LikeAnimationStyle.puzzle;

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
    if (widget.shouldPlay || widget.shouldPreload) {
       _checkInitialStates();
    }
    _startStatsPollingIfNeeded();
    _startWatchTrackingIfNeeded();

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

    // Pick up external controller if newly available
    if (!_isInitialized &&
        widget.externalController != null &&
        widget.externalController!.value.isInitialized) {
      _controller = widget.externalController!;
      _ownsController = false;
      setState(() { _isInitialized = true; });
    } else if (!_isInitialized && (widget.shouldPlay || widget.shouldPreload)) {
      _initVideo();
    }

    if (_isInitialized) {
      if (widget.shouldPlay && !oldWidget.shouldPlay) {
        _controller.play();
        _startStatsPollingIfNeeded();
        _startWatchTrackingIfNeeded();
      } else if (!widget.shouldPlay && oldWidget.shouldPlay) {
        _controller.pause();
        _stopStatsPolling();
        _stopWatchTracking();
      }
    }
  }

  void _startStatsPollingIfNeeded() {
    _stopStatsPolling();
    if (!widget.shouldPlay) return;
    _syncVideoStats();
    _statsTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !widget.shouldPlay) return;
      _syncVideoStats();
    });
  }

  void _stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  void _startWatchTrackingIfNeeded() {
    _stopWatchTracking();
    if (!widget.shouldPlay) return;

    final videoId = (widget.video['_id'] ?? '').toString();
    if (videoId.isEmpty) return;

    _watchTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted || !widget.shouldPlay || !_isInitialized || !_controller.value.isPlaying) return;

      try {
        await ApiService.recordWatchProgress(videoId: videoId, seconds: 10);
        widget.onGamificationChanged?.call();
      } catch (_) {
        // Keep playback smooth when watch tracking fails.
      }
    });
  }

  void _stopWatchTracking() {
    _watchTimer?.cancel();
    _watchTimer = null;
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
    if (!widget.shouldPlay && !widget.shouldPreload) return;
    if (_isInitialized) return;

    // Use external controller from VideoPreloadManager if available
    if (widget.externalController != null && widget.externalController!.value.isInitialized) {
      _controller = widget.externalController!;
      _ownsController = false;
      if (mounted) setState(() { _isInitialized = true; });

      if (widget.messageIdForStreak != null) {
        _controller.addListener(_videoStreakListener);
      }
      return;
    }

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
    _ownsController = true;
    try {
      await _controller.initialize();
      _controller.setLooping(true);
      if (widget.shouldPlay) _controller.play();
      if (mounted) setState(() { _isInitialized = true; });

      // Listen for streak validation if messageIdForStreak is present
      if (widget.messageIdForStreak != null) {
        _controller.addListener(_videoStreakListener);
      }
    } catch (e) {
      debugPrint('Video error: $e');
    }
  }

  void _videoStreakListener() {
    if (!mounted || _streakAcknowledged || widget.messageIdForStreak == null || !_isInitialized) return;
    
    final position = _controller.value.position.inMilliseconds / 1000.0;
    final duration = _controller.value.duration.inMilliseconds / 1000.0;
    
    if (duration <= 0) return;

    // Condition: 3 seconds OR 30% of video
    final threshold = 3.0; // seconds
    final percentageThreshold = duration * 0.3;
    final target = threshold < percentageThreshold ? threshold : percentageThreshold;

    if (position >= target) {
      _streakAcknowledged = true;
      _controller.removeListener(_videoStreakListener);
      debugPrint('🔥 Streak target met: reporting watch for message ${widget.messageIdForStreak}');
      ApiService.acknowledgeReelWatch(widget.messageIdForStreak!, position);
    }
  }

  Future<void> _toggleLike() async {
    if (_isLikeRequestInFlight) return; // Debounce

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final feed = Provider.of<FeedProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    final userId = (auth.user?['id'] ?? auth.user?['_id'] ?? '').toString();
    final videoId = (widget.video['_id'] ?? '').toString();
    if (userId.isEmpty || videoId.isEmpty) return;

    setState(() {
      _isLikeRequestInFlight = true;
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      final result = await ApiService.toggleLike(videoId);
      
      // Update feed silently so when navigating back, state is fresh
      final latestLikesCount = result['likesCount'] ?? _likesCount;
      feed.updateVideoSilently(videoId, {
        'likesCount': latestLikesCount,
        'likes': result['likes'] ?? [] // Some endpoints might return full array, some just counts
      });
      
      if (mounted) {
        setState(() {
          _likesCount = (latestLikesCount as num).toInt();
        });
      }
    } catch (e) {
      debugPrint('Like error: $e');
      if (mounted) {
        setState(() {
          // Revert UI on failure
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to like video')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLikeRequestInFlight = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final feed = Provider.of<FeedProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    final userId = (auth.user?['id'] ?? auth.user?['_id'] ?? '').toString();
    final videoId = (widget.video['_id'] ?? '').toString();
    if (userId.isEmpty || videoId.isEmpty) return;

    setState(() {
      _isFavorited = !_isFavorited;
      _favoritesCount += _isFavorited ? 1 : -1;
    });

    try {
      // Background update
      feed.toggleFavorite(videoId, userId).then((_) {
        feed.updateVideoSilently(videoId, {'favoritesCount': _favoritesCount});
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _isFavorited = !_isFavorited;
            _favoritesCount += _isFavorited ? 1 : -1;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to favorite')));
        }
      });
    } catch (e) {
      debugPrint('Favorite error: $e');
    }
  }

  Future<void> _toggleFollowAuthor() async {
    final author = widget.video['userId'];
    final authorId = author is Map ? author['_id']?.toString() : author?.toString();
    if (authorId == null) return;
    try {
      await ApiService.toggleFollow(authorId);
      // We could add follow state to AuthProvider but for now let's keep it local or refresh user
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
    final feed = Provider.of<FeedProvider>(context, listen: false);
    final videoId = (widget.video['_id'] ?? '').toString();
    if (videoId.isEmpty) return;

    try {
      await feed.toggleRepost(videoId);
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
            SwitchListTile(
              value: _enableDoubleTapAnimations,
              activeColor: const Color(0xFFFF006E),
              title: const Text('Double-tap animation', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Enable or disable tap effects', style: TextStyle(color: Colors.white70, fontSize: 12)),
              onChanged: (value) {
                setState(() {
                  _enableDoubleTapAnimations = value;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              title: const Text('Animation style', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                _animationStyle == LikeAnimationStyle.puzzle ? 'Puzzle' : 'Spark',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              onTap: () {
                setState(() {
                  _animationStyle = _animationStyle == LikeAnimationStyle.puzzle
                      ? LikeAnimationStyle.spark
                      : LikeAnimationStyle.puzzle;
                });
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
    final videoId = (widget.video['_id'] ?? '').toString();
    
    if (videoId.isEmpty) return;
    
    final shareUrl = 'https://tikizaya.com/v/$videoId';

    // 1. Optimistic UI update
    setState(() {
      _sharesCount++;
    });

    // 2. Open Share Sheet INSTANTLY
    final shareText = '🔥 Watch this on TikiZaya\n@$username • $caption\n\n👉 $shareUrl';
    Share.share(shareText, subject: 'Watch on TikiZaya');

    // 3. API Call in Background
    try {
      final feed = Provider.of<FeedProvider>(context, listen: false);
      ApiService.incrementVideoShare(videoId).then((shareResult) {
        final latestShares = (shareResult['sharesCount'] is num) ? (shareResult['sharesCount'] as num).toInt() : _sharesCount;
        feed.updateVideoSilently(videoId, {'sharesCount': latestShares});
        if (mounted) {
          setState(() {
            _sharesCount = latestShares;
          });
        }
      }).catchError((_) {
        // Revert on failure
        if (mounted) {
          setState(() {
            _sharesCount--;
          });
        }
      });
    } catch (_) {}
  }

  Future<void> _copyVideoLink() async {
    final videoId = (widget.video['_id'] ?? '').toString();
    if (videoId.isEmpty) return;
    
    final url = 'https://tikizaya.com/v/$videoId';
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
    final now = DateTime.now();
    if (_lastDoubleTapAt != null && now.difference(_lastDoubleTapAt!) < const Duration(milliseconds: 160)) {
      return;
    }
    _lastDoubleTapAt = now;

    HapticFeedback.lightImpact();

    final id = ++_animationIdSeed;
    setState(() {
      _activeLikeAnimations.add(
        ActiveLikeAnimation(id: id, position: details.localPosition),
      );
    });

    Future.delayed(const Duration(milliseconds: 860), () {
      if (!mounted) return;
      setState(() {
        _activeLikeAnimations.removeWhere((entry) => entry.id == id);
      });
    });

    // Prevent duplicate like requests while still allowing visual feedback.
    if (!_isLiked && !_isLikeRequestInFlight) {
      _toggleLike();
    }
  }

  @override
  void dispose() {
    _stopStatsPolling();
    _stopWatchTracking();
    // Only dispose if we own the controller (not provided by VideoPreloadManager)
    if (_ownsController && _isInitialized) {
      _controller.dispose();
    }
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

  // Video progress for the progress bar
  double _videoProgress = 0.0;
  bool _showPauseIcon = false;

  void _updateVideoProgress() {
    if (!_isInitialized) return;
    final position = _controller.value.position.inMilliseconds;
    final duration = _controller.value.duration.inMilliseconds;
    if (duration > 0 && mounted) {
      setState(() {
        _videoProgress = position / duration;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.video['userId'];
    final username = user is Map ? (user['username'] ?? 'Unknown').toString() : 'Unknown';
    final profilePic = user is Map ? (user['profilePic'] ?? '').toString() : '';
    final authorId = user is Map ? (user['_id'] ?? '').toString() : user?.toString() ?? '';
    final myId = widget.currentUser?['id']?.toString() ?? widget.currentUser?['_id'] ?? '';
    
    // Likes, Favorites, Reposts from props
    final likes = widget.video['likes'] as List? ?? [];
    final favorites = widget.video['favorites'] as List? ?? [];
    final repostsCount = (widget.video['repostsCount'] is num) ? (widget.video['repostsCount'] as num).toInt() : 0;
    final isLiked = likes.contains(myId);
    final isFavorited = favorites.contains(myId);
    final isReposted = (widget.video['isReposted'] == true);
    
    final commentsCount = (widget.video['commentsCount'] is num) ? (widget.video['commentsCount'] as num).toInt() : 0;
    final sharesCount = (widget.video['sharesCount'] is num) ? (widget.video['sharesCount'] as num).toInt() : 0;
    
    // Metadata
    final meta = widget.video['editingMetadata'] ?? {};
    final filterName = meta is Map ? (meta['filter'] as String? ?? 'Original') : 'Original';
    final speed = meta is Map && meta['speed'] is num ? (meta['speed'] as num).toDouble() : 1.0;
    final texts = meta is Map ? (meta['texts'] as List? ?? []) : [];

    if (_isInitialized && _controller.value.playbackSpeed != speed) {
      _controller.setPlaybackSpeed(speed);
    }

    // Listen for progress updates
    if (_isInitialized && widget.shouldPlay) {
      _controller.addListener(_updateVideoProgress);
    }

    if (_isHiddenFromFeed || _isArchived) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text('This reel is hidden', style: TextStyle(color: Colors.white54)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── FULL-SCREEN VIDEO (BoxFit.cover) ──
        PostWidget(
          activeAnimations: _activeLikeAnimations,
          enableAnimations: _enableDoubleTapAnimations,
          onDoubleTapDown: _handleDoubleTap,
          style: _animationStyle,
          child: GestureDetector(
            onTap: () {
              if (_isInitialized) {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                  setState(() { _showPauseIcon = true; });
                } else {
                  _controller.play();
                  setState(() { _showPauseIcon = false; });
                }
              }
            },
            child: Container(
              color: Colors.black,
              child: _isInitialized
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: _buildFilteredVideo(filterName),
                        ),
                      ),
                    )
                  : _hasVideoError
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded, color: Colors.white24, size: 48),
                              SizedBox(height: 8),
                              Text('Video unavailable', style: TextStyle(color: Colors.white38, fontSize: 13)),
                            ],
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF006E),
                            strokeWidth: 2.5,
                          ),
                        ),
            ),
          ),
        ),

        // ── PAUSE ICON OVERLAY ──
        if (_showPauseIcon && _isInitialized && !_controller.value.isPlaying)
          Center(
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),

        // ── TEXT OVERLAYS (from editor) ──
        ...texts.map((t) {
          final pos = t['position'] ?? {'dx': 100.0, 'dy': 200.0};
          final colorStr = t['color'] as String? ?? '#ffffffff';
          final color = Color(int.parse(colorStr.replaceFirst('#', '0x'), radix: 16));
          
          return Positioned(
            left: (pos['dx'] ?? 100.0).toDouble(),
            top: (pos['dy'] ?? 200.0).toDouble(),
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

        // ── RIGHT SIDE: Animated action bar ──
        Positioned(
          right: 8,
          bottom: MediaQuery.of(context).padding.bottom + 90,
          child: VideoActionBar(
            isLiked: isLiked,
            isFavorited: isFavorited,
            isReposted: isReposted,
            likesCount: likes.length,
            commentsCount: commentsCount,
            sharesCount: sharesCount,
            repostsCount: repostsCount,
            favoritesCount: favorites.length,
            profilePic: profilePic,
            onLikeTap: _toggleLike,
            onCommentTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: CommentsSheet(
                    videoId: (widget.video['_id'] ?? '').toString(),
                    onGamificationChanged: () {
                      if (mounted) {
                        setState(() {
                          _commentsCountLive++;
                        });
                        // Update provider silently
                        final feed = Provider.of<FeedProvider>(context, listen: false);
                        feed.updateVideoSilently((widget.video['_id'] ?? '').toString(), {'commentsCount': _commentsCountLive});
                      }
                    },
                  ),
                ),
              );
            },
            onShareTap: _openShareOptions,
            onRepostTap: _toggleRepost,
            onFavoriteTap: _toggleFavorite,
            onMoreTap: _showMoreActions,
            onProfileTap: authorId.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen(userId: authorId)),
                    );
                  },
          ),
        ),

        // ── BOTTOM: Caption + username + gradient ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: VideoCaptionOverlay(
            username: username,
            profilePic: profilePic,
            authorId: authorId,
            caption: _videoDescription(),
            isFollowing: _isFollowing,
            canFollow: canFollow,
            onFollowTap: _toggleFollowAuthor,
            onProfileTap: authorId.isEmpty
                ? () {}
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen(userId: authorId)),
                    );
                  },
            onSoundTap: _showSoundInfo,
          ),
        ),

        // ── BOTTOM: Video progress bar ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: VideoProgressBar(progress: _videoProgress),
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
}

