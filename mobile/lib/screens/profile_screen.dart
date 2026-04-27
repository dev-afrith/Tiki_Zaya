import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/edit_profile_screen.dart';
import 'package:mobile/screens/settings_screen.dart';
import 'package:mobile/screens/fullscreen_feed_screen.dart';
import 'package:mobile/screens/rewards_screen.dart';
import 'package:mobile/widgets/gamification_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mobile/widgets/profile/profile_header.dart';
import 'package:mobile/widgets/profile/stats_section.dart';
import 'package:mobile/widgets/profile/action_buttons.dart';
import 'package:mobile/widgets/profile/profile_streak_widget.dart';
import 'package:mobile/widgets/profile/creator_insights.dart';
import 'package:mobile/widgets/profile/profile_tabs.dart';
import 'package:mobile/widgets/profile/profile_video_grid.dart';
import 'package:mobile/widgets/profile/shareable_profile_card.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  List<dynamic> _userVideos = [];
  List<dynamic> _repostedVideos = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  String? _currentUserId;
  int _selectedTab = 0; // 0: posts, 1: reposts
  int _tzPoints = 0;
  int _streakDays = 0;
  List<String> _badges = const [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final summary = await ApiService.getGamificationSummary();
      final currentUser = summary['user'] as Map<String, dynamic>?;
      _currentUserId = currentUser?['id']?.toString() ?? currentUser?['_id']?.toString();

      final targetUserId = widget.userId ?? _currentUserId;
      if (targetUserId == null || targetUserId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final profile = widget.userId == null
          ? (summary['user'] as Map<String, dynamic>? ?? <String, dynamic>{})
          : await ApiService.getProfile(targetUserId);
      final videos = await ApiService.getUserVideos(targetUserId);
      List<dynamic> reposts = [];
      try {
        reposts = await ApiService.getUserReposts(targetUserId);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _user = profile.isNotEmpty ? profile : null;
          _userVideos = videos;
          _repostedVideos = reposts;
          final gamification = (widget.userId == null ? summary['gamification'] : profile['gamification']) as Map<String, dynamic>?;
          _tzPoints = _readInt(gamification?['points'], _tzPoints);
          _streakDays = _readInt(gamification?['streakDays'], _streakDays);
          _badges = _readBadges(gamification?['badges']);
          if (profile.isNotEmpty) {
            final followers = profile['followers'];
            if (followers is List) {
              _isFollowing = followers.contains(_currentUserId);
            }
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_user == null || _currentUserId == null) return;
    try {
      final result = await ApiService.toggleFollow(_user!['id'].toString());
      setState(() {
        _isFollowing = result['following'] ?? false;
        final followers = _user!['followers'];
        if (followers is List) {
          if (_isFollowing) {
            if (!followers.any((id) => id.toString() == _currentUserId)) {
              followers.add(_currentUserId);
            }
          } else {
            followers.removeWhere((id) => id.toString() == _currentUserId);
          }
        } else {
          final currentCount = _readCount(_user?['followersCount'] ?? _user?['followers']);
          _user!['followersCount'] = _isFollowing ? currentCount + 1 : (currentCount > 0 ? currentCount - 1 : 0);
        }
      });
    } catch (_) {}
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _shareProfile() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShareableProfileCard(
                username: _profileUsername(fallback: ''),
                displayName: _profileDisplayName(),
                profilePicUrl: _profilePhotoUrl,
                postsCount: _userVideos.length,
                followersCount: _followersCount,
                tzPoints: _tzPoints,
              ),
              const SizedBox(height: 16),
              FloatingActionButton.extended(
                onPressed: () => Navigator.pop(context),
                backgroundColor: const Color(0xFFFF006E),
                label: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
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

  List<String> _readBadges(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
    }
    return const [];
  }

  Widget _buildAboutCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final country = (_user?['country'] ?? '').toString();
    final joined = _user?['createdAt']?.toString();
    String joinedText = 'Unknown';
    if (joined != null && joined.isNotEmpty) {
      try {
        joinedText = DateTime.parse(joined).toLocal().toIso8601String().split('T').first;
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About this account',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111111),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _aboutRow(Icons.public_outlined, 'Based in', country.isEmpty ? 'Not set' : country),
          const SizedBox(height: 8),
          _aboutRow(Icons.calendar_month_outlined, 'Joined', joinedText),
          const SizedBox(height: 8),
          _aboutRow(Icons.lock_outline, 'Privacy', (_user?['isPrivate'] == true) ? 'Private' : 'Public'),
        ],
      ),
    );
  }

  String get _profilePhotoUrl {
    final profilePic = (_user?['profilePic'] ?? '').toString();
    if (profilePic.isNotEmpty) return profilePic;
    return (_user?['profilePhotoUrl'] ?? '').toString();
  }

  String get _profileInitial {
    final candidates = [
      _profileUsername(fallback: ''),
      _profileDisplayName(),
      (_user?['email'] ?? '').toString().trim(),
    ];

    for (final candidate in candidates) {
      final value = candidate.trim();
      if (value.isNotEmpty) {
        return value[0].toUpperCase();
      }
    }

    return 'U';
  }

  String _profileUsername({required String fallback}) {
    final candidates = [
      _user?['username'],
      _user?['userName'],
      _user?['handle'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'user') {
        return value;
      }
    }

    return fallback;
  }

  String _profileDisplayName() {
    final candidates = [
      _user?['name'],
      _user?['displayName'],
      _user?['fullName'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'user') {
        return value;
      }
    }

    final username = _profileUsername(fallback: '');
    if (username.isNotEmpty) {
      return username;
    }

    final email = (_user?['email'] ?? '').toString().trim();
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }

    return 'Unknown';
  }

  String get _profileTitle {
    final username = _profileUsername(fallback: '');
    if (username.isNotEmpty) return '@$username';
    final displayName = _profileDisplayName();
    return displayName == 'Unknown' ? 'Profile' : displayName;
  }

  int get _followersCount => _readCount(_user?['followersCount'] ?? _user?['followers']);

  int get _followingCount => _readCount(_user?['followingCount'] ?? _user?['following']);

  int _readCount(dynamic value) {
    if (value is List) {
      return value.length;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  Widget _buildProfileMeta() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = (_user?['category'] ?? '').toString().trim();
    final socialLinks = (_user?['socialLinks'] is Map)
      ? Map<String, dynamic>.from(_user!['socialLinks'] as Map)
      : <String, dynamic>{};

    final instagram = (socialLinks['instagram'] ?? '').toString().trim();
    final youtube = (socialLinks['youtube'] ?? '').toString().trim();
    final website = (socialLinks['website'] ?? '').toString().trim();

    final hasMeta = category.isNotEmpty || instagram.isNotEmpty || youtube.isNotEmpty || website.isNotEmpty;
    if (!hasMeta) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category.isNotEmpty)
              _aboutRow(Icons.category_outlined, 'Category', category),
            if (category.isNotEmpty && (instagram.isNotEmpty || youtube.isNotEmpty || website.isNotEmpty))
              const SizedBox(height: 8),
            if (instagram.isNotEmpty)
              _buildLinkRow(Icons.camera_alt_outlined, 'Instagram', instagram),
            if (instagram.isNotEmpty && (youtube.isNotEmpty || website.isNotEmpty)) const SizedBox(height: 8),
            if (youtube.isNotEmpty)
              _buildLinkRow(Icons.ondemand_video_outlined, 'YouTube', youtube),
            if (youtube.isNotEmpty && website.isNotEmpty) const SizedBox(height: 8),
            if (website.isNotEmpty)
              _buildLinkRow(Icons.language_outlined, 'Website', website),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkRow(IconData icon, String label, String url) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openExternalUrl(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, color: isDark ? Colors.white54 : Colors.black45, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
              ),
            ),
            Flexible(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: isDark ? const Color(0xFF87CEFA) : const Color(0xFF1E4FA3),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 14, color: isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    var value = rawUrl.trim();
    if (value.isEmpty) return;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  void _showProfilePhoto() {
    final url = _profilePhotoUrl;
    if (url.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _showAboutSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F12) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              _buildAboutCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: isDark ? Colors.white54 : Colors.black45, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111111),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF6F7FB);
    final fg = isDark ? Colors.white : const Color(0xFF111111);
    final isOwnProfile = widget.userId == null || widget.userId == _currentUserId;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF006E))),
      );
    }

    // Calculate total likes and views for Creator Insights
    int totalViews = 0;
    int totalLikes = 0;
    for (var video in _userVideos) {
      totalViews += _readInt(video['views'], 0);
      totalLikes += _readInt(video['likesCount'], 0);
    }

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (isOwnProfile)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black87),
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              onSelected: (value) async {
                if (value == 'about') _showAboutSheet();
                else if (value == 'settings') Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                else if (value == 'logout') _logout();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'about', child: Row(children: [Icon(Icons.info_outline, color: Colors.white70, size: 20), SizedBox(width: 8), Text('About this account', style: TextStyle(color: Colors.white))])),
                PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings, color: Colors.white70, size: 20), SizedBox(width: 8), Text('Settings', style: TextStyle(color: Colors.white))])),
                PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Color(0xFFFF006E), size: 20), SizedBox(width: 8), Text('Logout', style: TextStyle(color: Color(0xFFFF006E)))])),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // 1. Profile Header
            ProfileHeader(
              username: _profileUsername(fallback: ''),
              displayName: _profileDisplayName(),
              profilePicUrl: _profilePhotoUrl,
              bio: (_user?['bio'] ?? '').toString(),
              tzPoints: _tzPoints,
              onRewardsTap: _openRewards,
              onPhotoTap: _showProfilePhoto,
            ),
            
            // 2. Stats Section
            StatsSection(
              postsCount: _userVideos.length,
              followersCount: _followersCount,
              followingCount: _followingCount,
            ),

            // 3. Action Buttons
            ActionButtons(
              isOwnProfile: isOwnProfile,
              isFollowing: _isFollowing,
              onPrimaryTap: isOwnProfile
                  ? () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user!)));
                      if (result == true) _loadProfile();
                    }
                  : _toggleFollow,
              onShareTap: _shareProfile,
            ),

            const SizedBox(height: 16),
            
            // Profile Meta (Links)
            _buildProfileMeta(),
            
            const SizedBox(height: 16),

            // 4. Creator Insights
            if (isOwnProfile && _userVideos.isNotEmpty)
              CreatorInsights(totalLikes: totalLikes, totalViews: totalViews),

            const SizedBox(height: 16),

            // 5. Streak Widget
            ProfileStreakWidget(streakDays: _streakDays),

            const SizedBox(height: 24),

            // 6. Tabs
            ProfileTabs(
              selectedIndex: _selectedTab,
              onTabChanged: (index) => setState(() => _selectedTab = index),
            ),
            
            const SizedBox(height: 16),

            // 7. Video Grid
            ProfileVideoGrid(
              videos: _selectedTab == 0 ? _userVideos : _repostedVideos,
              isPostsTab: _selectedTab == 0,
              currentUser: _user,
              onVideoTap: (index) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenFeedScreen(
                      videos: _selectedTab == 0 ? _userVideos : _repostedVideos,
                      initialIndex: index,
                      currentUser: _user,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
