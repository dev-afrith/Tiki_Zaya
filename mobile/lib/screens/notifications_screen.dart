import 'package:flutter/material.dart';
import 'package:mobile/screens/chat_screen.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  List<dynamic> _suggestions = [];
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notificationsData = await ApiService.getNotifications();
      final suggestions = await ApiService.getSuggestedUsers();
      final unreadData = await ApiService.getUnreadMessagesCount();

      await ApiService.markAllNotificationsRead();

      if (mounted) {
        setState(() {
          _notifications = (notificationsData['notifications'] as List?) ?? [];
          _suggestions = suggestions;
          _unreadMessages = (unreadData['unreadTotal'] is num) ? (unreadData['unreadTotal'] as num).toInt() : 0;
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

  @override
  Widget build(BuildContext context) {
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
        actions: [
          if (_unreadMessages > 0)
            Container(
              margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF006E),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$_unreadMessages',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
        ],
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
                  else
                    ..._notifications.map((item) {
                      final actor = item['actor'];
                      final actorName = actor is Map ? (actor['username'] ?? 'Someone').toString() : 'Someone';
                      final type = (item['type'] ?? '').toString();
                      final body = (item['body'] ?? '').toString();
                      final createdAt = item['createdAt']?.toString();
                      final title = (item['title'] ?? '').toString();

                      final icon = type == 'message'
                          ? Icons.message
                          : type == 'comment'
                              ? Icons.chat_bubble
                              : type == 'follow'
                                  ? Icons.person_add
                                  : type == 'post'
                                      ? Icons.smart_display_rounded
                                      : Icons.favorite;

                      // Extract action from body (e.g., "Someone started following you")
                      String actionText = body.replaceFirst(actorName, '').trim();
                      if (actionText.isEmpty) actionText = title;

                      return InkWell(
                        onTap: () {
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
                                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4, fontFamily: 'Outfit'),
                                    children: [
                                      TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: ' $actionText', style: const TextStyle(color: Colors.white70)),
                                      TextSpan(
                                        text: '  ${_formatTimeAgo(createdAt)}',
                                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
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
}
