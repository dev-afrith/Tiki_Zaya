import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/screens/fullscreen_feed_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  List<dynamic> _searchHashtags = [];
  List<dynamic> _searchVideos = [];
  List<String> _recentSearches = [];
  List<dynamic> _myFollowing = [];
  String _currentUserId = '';
  bool _isSearching = false;
  Map<String, dynamic>? _discoveryData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDiscoveryData();
  }

  Future<void> _loadDiscoveryData() async {
    final me = await ApiService.getUser();
    final data = await ApiService.getDiscoveryData();
    if (mounted) {
      setState(() {
        _currentUserId = (me?['id'] ?? me?['_id'] ?? '').toString();
        _myFollowing = (me?['following'] as List?) ?? [];
        _discoveryData = data;
        _isLoading = false;
      });
    }
  }

  void _addRecentSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _recentSearches.removeWhere((item) => item.toLowerCase() == q.toLowerCase());
      _recentSearches.insert(0, q);
      if (_recentSearches.length > 8) {
        _recentSearches = _recentSearches.take(8).toList();
      }
    });
  }

  Future<void> _toggleFollowInDiscover(String userId) async {
    if (userId.isEmpty || userId == _currentUserId) return;
    try {
      final result = await ApiService.toggleFollow(userId);
      final following = result['following'] == true;
      setState(() {
        if (following) {
          if (!_myFollowing.any((id) => id.toString() == userId)) {
            _myFollowing.add(userId);
          }
        } else {
          _myFollowing.removeWhere((id) => id.toString() == userId);
        }
      });
    } catch (_) {}
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchHashtags = [];
        _searchVideos = [];
      });
      return;
    }

    setState(() { _isSearching = true; });

    try {
      final results = await ApiService.searchUsers(query);
      final related = await ApiService.searchHashtagsAndVideos(query);
      setState(() {
        _searchResults = results;
        _searchHashtags = (related['hashtags'] as List?) ?? [];
        _searchVideos = (related['videos'] as List?) ?? [];
        _isSearching = false;
      });
    } catch (e) {
      setState(() { _isSearching = false; });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search creators or videos',
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.search, color: Color(0xFFFF006E)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: _searchUsers,
                  onSubmitted: (value) {
                    _addRecentSearch(value);
                    _searchUsers(value);
                  },
                ),
              ),
            ),

            Expanded(
              child: _isSearching || _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E)))
                : _searchResults.isEmpty && _searchHashtags.isEmpty && _searchVideos.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _loadDiscoveryData,
                      color: const Color(0xFFFF006E),
                      child: _buildMainDiscovery(),
                    )
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDiscovery() {
    final hashtags = _discoveryData?['hashtags'] as List? ?? [];
    final creators = _discoveryData?['creators'] as List? ?? [];
    final videos = _discoveryData?['videos'] as List? ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Trending Hashtags
          if (hashtags.isNotEmpty) ...[
            _buildDiscoveryHeader('Trending'),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: hashtags.length,
                itemBuilder: (context, index) => _buildTag(hashtags[index]),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 2. Recommended Creators
          if (creators.isNotEmpty) ...[
            _buildDiscoveryHeader('Recommended Creators'),
            ...creators.map((c) => _buildCreatorItem(c)),
            const SizedBox(height: 24),
          ],

          // 3. Trending Videos Grid
          if (videos.isNotEmpty) ...[
            _buildDiscoveryHeader('Trending Videos'),
            _buildVideoGrid(videos),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscoveryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF006E).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF006E).withValues(alpha: 0.3)),
      ),
      child: Text(
        tag,
        style: const TextStyle(color: Color(0xFFFF006E), fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Widget _buildCreatorItem(Map<String, dynamic> creator) {
    final name = creator['username'] ?? 'Unknown';
    final followers = '${creator['followersCount'] ?? 0} followers';
    final avatar = creator['profilePic'] ?? '';
    final userId = (creator['_id'] ?? creator['id'] ?? '').toString();
    final isFollowing = _myFollowing.any((id) => id.toString() == userId);
    final isOwn = _currentUserId.isNotEmpty && _currentUserId == userId;

    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[900],
        ),
        child: ClipOval(
          child: avatar.isNotEmpty
            ? Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            : Center(
                child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
        ),
      ),
      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(followers, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: isOwn
          ? const SizedBox.shrink()
          : ElevatedButton(
              onPressed: () => _toggleFollowInDiscover(userId),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.white12 : const Color(0xFFFF006E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: Text(
                isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
    );
  }

  Widget _buildVideoGrid(List<dynamic> videos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        final views = '${video['views'] ?? 0}';
        final previewUrl = _videoPreviewUrl(video);
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullscreenFeedScreen(
                  videos: videos,
                  initialIndex: index,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.05),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (previewUrl.isNotEmpty)
                    Image.network(
                      previewUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.white10,
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                      ),
                    )
                  else
                    Container(
                      color: Colors.white10,
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                    ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Row(
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                        const SizedBox(width: 2),
                        Text(views, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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

  String _videoPreviewUrl(dynamic video) {
    final thumbnail = (video['thumbnailUrl'] ?? '').toString();
    if (thumbnail.isNotEmpty) return thumbnail;

    final videoUrl = (video['videoUrl'] ?? '').toString();
    if (videoUrl.contains('cloudinary.com') && videoUrl.contains('/video/upload/')) {
      return videoUrl.replaceFirst('/video/upload/', '/video/upload/so_1,q_auto,f_jpg/');
    }
    return '';
  }

  Widget _buildSearchResults() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent Searches',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _recentSearches = [];
                    });
                  },
                  child: const Text(
                    'Clear all',
                    style: TextStyle(color: Color(0xFFFF006E), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          ..._recentSearches.map((query) => ListTile(
                leading: const Icon(Icons.history, color: Colors.white54, size: 18),
                title: Text(query, style: const TextStyle(color: Colors.white70)),
                trailing: GestureDetector(
                  onTap: () {
                    setState(() {
                      _recentSearches.remove(query);
                    });
                  },
                  child: const Icon(Icons.close, color: Colors.white38, size: 18),
                ),
                onTap: () {
                  _searchController.text = query;
                  _searchUsers(query);
                },
              )),
          const SizedBox(height: 8),
        ],
        if (_searchHashtags.isNotEmpty) ...[
          _buildDiscoveryHeader('Related Hashtags'),
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _searchHashtags.length,
              itemBuilder: (context, index) {
                final tag = _searchHashtags[index].toString();
                return GestureDetector(
                  onTap: () {
                    final normalized = tag.replaceFirst('#', '');
                    _searchController.text = normalized;
                    _searchUsers(normalized);
                  },
                  child: _buildTag(tag),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (_searchVideos.isNotEmpty) ...[
          _buildDiscoveryHeader('Videos For Your Search'),
          _buildVideoGrid(_searchVideos),
          const SizedBox(height: 18),
        ],
        if (_searchResults.isNotEmpty) ...[
          _buildDiscoveryHeader('Creators'),
          ..._searchResults.map((user) {
            final username = (user['username'] ?? 'user').toString();
            final userId = user['id'] ?? user['_id'];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFFF006E),
                child: Text(username.isNotEmpty ? username[0].toUpperCase() : 'U'),
              ),
              title: Text(username, style: const TextStyle(color: Colors.white)),
              trailing: Builder(builder: (context) {
                final uid = (userId ?? '').toString();
                final isFollowing = _myFollowing.any((id) => id.toString() == uid);
                final isOwn = uid.isNotEmpty && uid == _currentUserId;
                if (isOwn || uid.isEmpty) return const SizedBox.shrink();
                return ElevatedButton(
                  onPressed: () => _toggleFollowInDiscover(uid),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.white12 : const Color(0xFFFF006E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                );
              }),
              onTap: () {
                _addRecentSearch(username);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
              },
            );
          }),
        ],
      ],
    );
  }
}
