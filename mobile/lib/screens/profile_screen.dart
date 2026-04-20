import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/edit_profile_screen.dart';
import 'package:mobile/screens/settings_screen.dart';
import 'package:mobile/screens/fullscreen_feed_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final currentUser = await ApiService.getUser();
      _currentUserId = currentUser?['id']?.toString();

      final targetUserId = widget.userId ?? _currentUserId;
      if (targetUserId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final profile = await ApiService.getProfile(targetUserId);
      final videos = await ApiService.getUserVideos(targetUserId);
      final reposts = await ApiService.getUserReposts(targetUserId);

      if (mounted) {
        setState(() {
          _user = profile;
          _userVideos = videos;
          _repostedVideos = reposts;
          _isFollowing = (profile['followers'] as List?)?.contains(_currentUserId) ?? false;
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
        if (_isFollowing) {
          (_user!['followers'] as List).add(_currentUserId);
        } else {
          (_user!['followers'] as List).remove(_currentUserId);
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
    final username = (_user?['username'] ?? 'user').toString();
    final bio = (_user?['bio'] ?? '').toString();
    await Share.share('Check out @$username on TikiZaya!\n$bio');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF6F7FB);
    final fg = isDark ? Colors.white : const Color(0xFF111111);
    final muted = isDark ? Colors.white54 : Colors.black54;
    final isOwnProfile = widget.userId == null || widget.userId == _currentUserId;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF006E))),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: fg),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          '@${_user?['username'] ?? 'Profile'}',
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (isOwnProfile)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: fg),
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              onSelected: (value) async {
                if (value == 'about') {
                  _showAboutSheet();
                } else if (value == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                } else if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'about',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text('About this account', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text('Settings', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Color(0xFFFF006E), size: 20),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Color(0xFFFF006E))),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _showProfilePhoto,
                    child: Hero(
                      tag: 'profile_${_user?['id']}',
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: const Color(0xFFFF006E),
                        backgroundImage: _profilePhotoUrl.isNotEmpty
                            ? NetworkImage(_profilePhotoUrl)
                            : null,
                        child: _profilePhotoUrl.isEmpty
                            ? Text(
                                (_user?['username'] ?? 'U').toString()[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${(_user?['username'] ?? 'unknown').toString()}',
                          style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (_user?['name'] ?? _user?['username'] ?? 'Unknown').toString(),
                          style: TextStyle(color: muted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _user?['bio'] == null || _user!['bio'].toString().isEmpty ? 'No bio yet' : _user!['bio'].toString(),
                  style: TextStyle(color: muted, fontSize: 14),
                ),
              ),
            ),
            _buildProfileMeta(),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('${_userVideos.length}', 'Posts'),
                  _buildStat('${(_user?['followers'] as List?)?.length ?? 0}', 'Followers'),
                  _buildStat('${(_user?['following'] as List?)?.length ?? 0}', 'Following'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isOwnProfile
                          ? () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user!)),
                              );
                              if (result == true) _loadProfile();
                            }
                          : _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOwnProfile
                            ? Colors.white12
                            : (_isFollowing ? Colors.white12 : const Color(0xFFFF006E)),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(isOwnProfile ? 'Edit Profile' : (_isFollowing ? 'Following' : 'Follow')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _shareProfile,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Share Profile', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, thickness: 0.6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildTabButton('Posts', 0)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTabButton('Reposts', 1)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _selectedTab == 0 ? 'Posted Videos' : 'Reposted Videos',
                  style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _buildVideosGrid(_selectedTab == 0 ? _userVideos : _repostedVideos),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosGrid(List<dynamic> videos) {
    if (videos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          children: [
            Icon(Icons.video_library_outlined, size: 60, color: Colors.white10),
            const SizedBox(height: 12),
            Text(_selectedTab == 0 ? 'No videos yet' : 'No reposts yet', style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final item = videos[index] as Map<String, dynamic>;
        final previewUrl = _videoPreviewUrl(item);
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullscreenFeedScreen(
                  videos: videos,
                  initialIndex: index,
                  currentUser: _user,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: previewUrl.isNotEmpty
                      ? Image.network(
                          previewUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.white10),
                        )
                      : Container(color: Colors.white10),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
                const Center(
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 38),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 11),
                          const SizedBox(width: 2),
                          Text(
                            '${item['views'] ?? 0}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.repeat_rounded, color: Colors.white, size: 11),
                          const SizedBox(width: 2),
                          Text(
                            '${item['repostsCount'] ?? 0}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String count, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111111),
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: isDark ? Colors.grey[600] : Colors.black54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF006E).withValues(alpha: 0.18)
              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFFFF006E) : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? (isDark ? Colors.white : const Color(0xFF111111)) : (isDark ? Colors.white54 : Colors.black54),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  String _videoPreviewUrl(Map<String, dynamic> video) {
    final thumbnail = (video['thumbnailUrl'] ?? '').toString();
    if (thumbnail.isNotEmpty) return thumbnail;

    final videoUrl = (video['videoUrl'] ?? '').toString();
    if (videoUrl.contains('cloudinary.com') && videoUrl.contains('/video/upload/')) {
      return videoUrl.replaceFirst('/video/upload/', '/video/upload/so_1,q_auto,f_jpg/');
    }
    return '';
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
}
