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
                      final icon = type == 'message'
                          ? Icons.message_outlined
                          : type == 'comment'
                              ? Icons.chat_bubble_outline
                              : type == 'post'
                                  ? Icons.smart_display_rounded
                                  : Icons.favorite;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () {
                            if (type == 'message') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ChatScreen()),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFFFF006E).withValues(alpha: 0.18),
                                  backgroundImage: actor is Map && (actor['profilePic'] ?? '').toString().isNotEmpty
                                      ? NetworkImage(actor['profilePic'].toString())
                                      : null,
                                  child: actor is Map && (actor['profilePic'] ?? '').toString().isEmpty
                                      ? Text(
                                          actorName.isNotEmpty ? actorName[0].toUpperCase() : 'U',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        )
                                      : Icon(icon, color: const Color(0xFFFF006E), size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (item['title'] ?? 'Update').toString(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        (item['body'] ?? '').toString(),
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 18),
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
