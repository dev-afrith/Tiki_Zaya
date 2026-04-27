import 'package:flutter/material.dart';
import 'package:mobile/screens/chat_screen.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:mobile/services/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  List<dynamic> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; });

    try {
      final notificationsData = await ApiService.getNotifications();
      final suggestions = await ApiService.getSuggestedUsers();

      if (mounted) {
        setState(() {
          _notifications = (notificationsData['notifications'] as List?) ?? [];
          _suggestions = suggestions;
          _isLoading = false;
        });
      }

      // We do NOT mark all read on open anymore. 
      // User must tap them or hit a mark all read button if we want, or we keep them unread until tapped.
      // Actually, user requested: "When user opens notification screen -> mark all as read OR user taps -> mark one". Let's follow: "user opens notification screen → mark all as read". 
      // If we mark all as read, then all become read instantly. But they asked for "unread bolding + red dot". If we mark all read on open, they won't see the red dot.
      // So let's NOT mark all read on open, let's let them tap.
      // Wait, "When: user opens notification screen -> mark all as read, user taps -> mark one". If we mark all as read on open, we should do it in the background but leave the local UI showing them as unread until the user leaves the screen, OR just don't mark all read. Let's just update the count to 0 in provider, but keep `isRead = false` locally so they can see which ones are new.
      // Actually, better to just let them tap to mark as read, or provide a "Mark all as read" button.
      // Let's do background "mark all as read" but keep local state as is.
      ApiService.markAllNotificationsRead();
      if (mounted) {
        Provider.of<NotificationProvider>(context, listen: false).clearUnreadNotifications();
      }
    } catch (_) {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _markOneRead(int index) {
    if (_notifications[index]['isRead'] == true) return;
    
    setState(() {
      _notifications[index]['isRead'] = true;
    });
    
    final id = _notifications[index]['_id'].toString();
    ApiService.markOneNotificationRead(id);
    Provider.of<NotificationProvider>(context, listen: false).decrementUnreadNotifications();
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${diff.inDays ~/ 7}w';
    } catch (_) {
      return '';
    }
  }

  Map<String, List<dynamic>> _groupNotifications(List<dynamic> notifs) {
    final Map<String, List<dynamic>> grouped = {
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var n in notifs) {
      final dateStr = n['createdAt']?.toString();
      if (dateStr == null) continue;
      try {
        final d = DateTime.parse(dateStr).toLocal();
        final checkDate = DateTime(d.year, d.month, d.day);
        
        if (checkDate == today) {
          grouped['Today']!.add(n);
        } else if (checkDate == yesterday) {
          grouped['Yesterday']!.add(n);
        } else {
          grouped['Earlier']!.add(n);
        }
      } catch (_) {}
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupNotifications(_notifications);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E)))
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFFFF006E),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text('No notifications yet', style: TextStyle(color: Colors.white54)),
                    )
                  else ...[
                    _buildGroup('Today', grouped['Today']!),
                    _buildGroup('Yesterday', grouped['Yesterday']!),
                    _buildGroup('Earlier', grouped['Earlier']!),
                  ],
                  const SizedBox(height: 24),
                  const Text('Suggestions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  ..._suggestions.take(8).map((user) {
                    final username = (user['username'] ?? 'user').toString();
                    final profilePic = (user['profilePic'] ?? '').toString();
                    final userId = (user['_id'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white12,
                              backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                              child: profilePic.isEmpty
                                  ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white))
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@$username',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$username is on TikiZaya, follow them and be connected',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: userId.isEmpty
                                  ? null
                                  : () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
                                    },
                              child: const Text('View', style: TextStyle(color: Color(0xFFFF006E))),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildGroup(String title, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        ...items.map((item) {
          final index = _notifications.indexOf(item);
          final actor = item['actor'];
          final actorName = actor is Map ? (actor['username'] ?? 'Someone').toString() : 'Someone';
          final type = (item['type'] ?? '').toString();
          final message = (item['message'] ?? '').toString();
          final createdAt = item['createdAt']?.toString();
          final isRead = item['isRead'] == true;

          final icon = type == 'message'
              ? Icons.message
              : type == 'comment'
                  ? Icons.chat_bubble
                  : type == 'follow'
                      ? Icons.person_add
                      : type == 'post'
                          ? Icons.smart_display_rounded
                          : Icons.favorite;

          String actionText = message.replaceFirst(actorName, '').trim();
          if (actionText.isEmpty) actionText = 'interacted with you';

          return InkWell(
            onTap: () {
              _markOneRead(index);
              if (type == 'message') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
              } else if (type == 'follow') {
                if (actor is Map && actor['_id'] != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: actor['_id'].toString())));
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              color: isRead ? Colors.transparent : Colors.white.withValues(alpha: 0.05),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white12,
                        backgroundImage: actor is Map && (actor['profilePic'] ?? '').toString().isNotEmpty
                            ? NetworkImage(actor['profilePic'].toString())
                            : null,
                        child: actor is Map && (actor['profilePic'] ?? '').toString().isEmpty
                            ? Text(
                                actorName.isNotEmpty ? actorName[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF006E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Icon(icon, color: Colors.white, size: 10),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 14, 
                          height: 1.4, 
                          fontFamily: 'Outfit',
                          fontWeight: isRead ? FontWeight.normal : FontWeight.w700,
                        ),
                        children: [
                          TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: ' $actionText', style: TextStyle(color: isRead ? Colors.white70 : Colors.white)),
                          TextSpan(
                            text: '  ${_formatTimeAgo(createdAt)}',
                            style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isRead)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF006E),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
