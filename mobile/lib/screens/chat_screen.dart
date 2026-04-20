import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/screens/fullscreen_feed_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isLoading = true;
  List<dynamic> _inbox = [];
  List<dynamic> _suggestedUsers = [];
  int _unreadTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final inboxData = await ApiService.getInboxData();
      final inbox = (inboxData['inbox'] as List?) ?? [];
      final suggested = await ApiService.getSuggestedUsers();
      if (mounted) {
        setState(() {
          _inbox = inbox;
          _suggestedUsers = suggested;
          _unreadTotal = (inboxData['unreadTotal'] is num) ? (inboxData['unreadTotal'] as num).toInt() : 0;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _inbox = [];
          _suggestedUsers = [];
        });
      }
    } finally {
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.maybePop(context);
          },
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF3B8E), Color(0xFF8B5CF6), Color(0xFF3B82F6)],
          ).createShader(bounds),
          child: Text(
            'Messages',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        actions: [
          if (_unreadTotal > 0)
            Container(
              margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF006E),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$_unreadTotal',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInbox,
        color: const Color(0xFFFF006E),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF006E)),
              )
            : _inbox.isEmpty
                ? ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      Center(
                        child: Text(
                          'No messages yet',
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_suggestedUsers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Start a conversation',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      ..._suggestedUsers.take(10).map((user) {
                        final username = user['username']?.toString() ?? 'Unknown';
                        final profilePic = user['profilePic']?.toString() ?? '';
                        final userId = user['_id']?.toString();
                        if (userId == null) return const SizedBox.shrink();

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1B2036),
                            backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                            child: profilePic.isEmpty
                                ? Text(username[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                                : null,
                          ),
                          title: Text(
                            username,
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatThreadScreen(
                                  peerUserId: userId,
                                  peerUsername: username,
                                  peerProfilePic: profilePic,
                                ),
                              ),
                            );
                            _loadInbox();
                          },
                        );
                      }),
                    ],
                  )
                : ListView.separated(
                    itemCount: _inbox.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = _inbox[index] as Map<String, dynamic>;
                      final user = item['user'] as Map<String, dynamic>? ?? {};
                      final username = user['username']?.toString() ?? 'Unknown';
                      final profilePic = user['profilePic']?.toString() ?? '';
                      final latestText = item['latestText']?.toString() ?? '';
                      final unreadCount = (item['unreadCount'] is num) ? (item['unreadCount'] as num).toInt() : 0;
                      final userId = user['_id']?.toString();
                      if (userId == null) return const SizedBox.shrink();

                      return ListTile(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatThreadScreen(
                                peerUserId: userId,
                                peerUsername: username,
                                peerProfilePic: profilePic,
                              ),
                            ),
                          );
                          _loadInbox();
                        },
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1B2036),
                          backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                          child: profilePic.isEmpty
                              ? Text(
                                  username[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(
                          username,
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                latestText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(color: Colors.white54),
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF006E),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class ChatThreadScreen extends StatefulWidget {
  final String peerUserId;
  final String peerUsername;
  final String peerProfilePic;

  const ChatThreadScreen({
    super.key,
    required this.peerUserId,
    required this.peerUsername,
    required this.peerProfilePic,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = await ApiService.getUser();
    _currentUserId = user?['_id']?.toString() ?? user?['id']?.toString();
    await ApiService.markConversationRead(widget.peerUserId);
    await _loadConversation();
    await _connectSocket();
  }

  Future<void> _loadConversation() async {
    try {
      final messages = await ApiService.getConversation(widget.peerUserId);
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot load conversation for this user.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _connectSocket() async {
    final token = await ApiService.getToken();
    if (token == null) return;

    _socket = io.io(
      ApiService.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket?.onConnect((_) {
      _socket?.emit('join_conversation', {'withUserId': widget.peerUserId});
    });

    _socket?.on('new_message', (data) {
      if (!mounted || data == null) return;
      final fromId = data['fromUserId'] is Map ? data['fromUserId']['_id'] : data['fromUserId'];
      final toId = data['toUserId'] is Map ? data['toUserId']['_id'] : data['toUserId'];
      final participants = {fromId?.toString(), toId?.toString()};

      if (participants.contains(_currentUserId) && participants.contains(widget.peerUserId)) {
        setState(() {
          _messages.add(data);
        });
        _scrollToBottom();
      }
    });

    _socket?.connect();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final result = await ApiService.sendMessage(widget.peerUserId, text);
      _messageController.clear();
      if (mounted) {
        setState(() {
          _messages.add(result);
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _cloudinaryVideoToPreview(String videoUrl) {
    if (!videoUrl.contains('res.cloudinary.com') || !videoUrl.contains('/video/upload/')) {
      return '';
    }
    final transformed = videoUrl.replaceFirst('/video/upload/', '/video/upload/so_0/');
    return transformed.replaceFirst(RegExp(r'\.[a-zA-Z0-9]+$'), '.jpg');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1B2036),
              backgroundImage: widget.peerProfilePic.isNotEmpty ? NetworkImage(widget.peerProfilePic) : null,
              child: widget.peerProfilePic.isEmpty
                  ? Text(
                      widget.peerUsername[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(widget.peerUsername, style: GoogleFonts.poppins(color: Colors.white)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E)))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    itemBuilder: (context, index) {
                      final item = _messages[index] as Map<String, dynamic>;
                      final from = item['fromUserId'];
                      final fromId = from is Map ? from['_id']?.toString() : from?.toString();
                      final isMine = fromId == _currentUserId;
                      final messageType = (item['messageType'] ?? 'text').toString();
                      final sharedVideo = item['sharedVideo'] is Map<String, dynamic>
                          ? item['sharedVideo'] as Map<String, dynamic>
                          : null;

                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                          decoration: BoxDecoration(
                            color: isMine ? const Color(0xFFFF006E) : const Color(0xFF1B2036),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: (messageType == 'reel' && sharedVideo != null)
                              ? _buildReelMessageCard(sharedVideo, isMine)
                              : Text(
                                  item['text']?.toString() ?? '',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                                ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        hintStyle: GoogleFonts.poppins(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF151A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF006E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelMessageCard(Map<String, dynamic> sharedVideo, bool isMine) {
    final videoUrl = (sharedVideo['videoUrl'] ?? '').toString();
    final thumbnailUrlRaw = (sharedVideo['thumbnailUrl'] ?? '').toString();
    final thumbnailUrl = thumbnailUrlRaw.isNotEmpty ? thumbnailUrlRaw : _cloudinaryVideoToPreview(videoUrl);
    final caption = (sharedVideo['caption'] ?? '').toString();
    final ownerUsername = (sharedVideo['ownerUsername'] ?? 'user').toString();
    final videoId = (sharedVideo['videoId'] ?? '').toString();

    return GestureDetector(
      onTap: (videoUrl.isEmpty && videoId.isEmpty)
          ? null
          : () async {
              Map<String, dynamic> payload = {
                '_id': videoId,
                'videoUrl': videoUrl,
                'thumbnailUrl': thumbnailUrl,
                'caption': caption,
                'userId': {
                  '_id': sharedVideo['ownerId'] ?? '',
                  'username': ownerUsername,
                  'profilePic': '',
                },
                'likes': [],
                'favorites': [],
                'commentsCount': 0,
                'repostsCount': 0,
                'sharesCount': 0,
              };

              if (videoId.isNotEmpty) {
                try {
                  final realVideo = await ApiService.getVideoById(videoId);
                  if (realVideo.isNotEmpty && realVideo['error'] == null && realVideo['message'] == null) {
                    payload = realVideo;
                  }
                } catch (_) {
                  // Fall back to shared payload when direct fetch fails.
                }
              }

              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullscreenFeedScreen(
                    videos: [payload],
                    initialIndex: 0,
                  ),
                ),
              );
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 170,
              width: 190,
              color: Colors.black26,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl.isNotEmpty)
                    Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black26),
                    )
                  else
                    Container(color: Colors.black26),
                  const Center(
                    child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 44),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reel from @$ownerUsername',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (caption.isNotEmpty)
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: isMine ? Colors.white.withValues(alpha: 0.9) : Colors.white70,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
