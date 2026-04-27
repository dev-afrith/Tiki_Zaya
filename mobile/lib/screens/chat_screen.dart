import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/screens/fullscreen_feed_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:mobile/widgets/voice_recorder_widget.dart';
import 'package:mobile/widgets/audio_bubble.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────
//  INBOX SCREEN (Chat list)
// ─────────────────────────────────────────────────────────────

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
    setState(() => _isLoading = true);
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
        setState(() { _inbox = []; _suggestedUsers = []; });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inSeconds < 60) return 'now';
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF3B8E), Color(0xFF8B5CF6), Color(0xFF3B82F6)],
          ).createShader(bounds),
          child: Text(
            'Messages',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700),
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
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E)))
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
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
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
                          title: Text(username, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ChatThreadScreen(
                                peerUserId: userId,
                                peerUsername: username,
                                peerProfilePic: profilePic,
                              )),
                            );
                            _loadInbox();
                          },
                        );
                      }),
                    ],
                  )
                : ListView.separated(
                    itemCount: _inbox.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                    itemBuilder: (context, index) {
                      final item = _inbox[index] as Map<String, dynamic>;
                      final user = item['user'] as Map<String, dynamic>? ?? {};
                      final username = user['username']?.toString() ?? 'Unknown';
                      final profilePic = user['profilePic']?.toString() ?? '';
                      final latestText = item['latestText']?.toString() ?? '';
                      final latestAt = item['latestAt']?.toString();
                      final unreadCount = (item['unreadCount'] is num) ? (item['unreadCount'] as num).toInt() : 0;
                      final userId = user['_id']?.toString();
                      if (userId == null) return const SizedBox.shrink();

                      return ListTile(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ChatThreadScreen(
                              peerUserId: userId,
                              peerUsername: username,
                              peerProfilePic: profilePic,
                            )),
                          );
                          _loadInbox();
                        },
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1B2036),
                          backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                          child: profilePic.isEmpty
                              ? Text(username[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                              : null,
                        ),
                        title: Text(
                          username,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          latestText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: unreadCount > 0 ? Colors.white : Colors.white54,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatTimeAgo(latestAt),
                              style: GoogleFonts.poppins(
                                color: unreadCount > 0 ? const Color(0xFFFF006E) : Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              Container(
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
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CHAT THREAD SCREEN (Instagram-style DM)
// ─────────────────────────────────────────────────────────────

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
  final ImagePicker _imagePicker = ImagePicker();

  // Deduplicated message store: (serverId || clientMessageId) → message map
  final Map<String, Map<String, dynamic>> _messageMap = {};
  final Uuid _uuid = const Uuid();
  List<Map<String, dynamic>> get _messages {
    final list = _messageMap.values.toList();
    list.sort((a, b) {
      final aTime = a['createdAt']?.toString() ?? '';
      final bTime = b['createdAt']?.toString() ?? '';
      return aTime.compareTo(bTime);
    });
    return list;
  }

  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingImage = false;
  String? _currentUserId;
  io.Socket? _socket;
  bool _peerTyping = false;
  bool _peerOnline = false;
  bool _peerHasSeenLatest = false;
  String? _seenAtText;
  int _tempIdCounter = 0;
  int _interactionStreakCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() => setState(() {}));
    _bootstrap();
  }

  bool _isTyping = false;

  Future<void> _bootstrap() async {
    final user = await ApiService.getUser();
    _currentUserId = user?['_id']?.toString() ?? user?['id']?.toString();
    await ApiService.markConversationRead(widget.peerUserId);
    await _loadConversation();
    await _fetchStreak();
    await _connectSocket();
  }

  Future<void> _fetchStreak() async {
    try {
      final data = await ApiService.getInteractionStreak(widget.peerUserId);
      if (mounted) {
        setState(() {
          _interactionStreakCount = data['streak']?['streakCount'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadConversation() async {
    try {
      final messages = await ApiService.getConversation(widget.peerUserId);
      if (mounted) {
        setState(() {
          _messageMap.clear();
          for (final msg in messages) {
            if (msg is Map<String, dynamic>) {
              final id = _extractId(msg);
              if (id.isNotEmpty) _messageMap[id] = msg;
            }
          }
          _isLoading = false;
          _updateSeenStatus();
        });
        if (messages.isNotEmpty) _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  String _extractId(Map<String, dynamic> msg) {
    // Priority: serverId (_id) > clientMessageId
    return (msg['_id'] ?? msg['clientMessageId'] ?? msg['tempId'] ?? '').toString();
  }

  void _updateSeenStatus() {
    final mine = _messages.where((m) => _getSenderId(m) == _currentUserId).toList();
    if (mine.isEmpty) return;
    mine.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
    final latest = mine.first;
    final status = (latest['status'] ?? 'sent').toString();
    final seenAt = latest['readAt'];

    setState(() {
      _peerHasSeenLatest = status == 'seen';
      if (_peerHasSeenLatest && seenAt != null) {
        _seenAtText = 'Seen ${_formatSeenAt(seenAt.toString())}';
      } else if (_peerHasSeenLatest) {
        _seenAtText = 'Seen';
      } else {
        _seenAtText = null;
      }
    });
  }

  String _formatSeenAt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final date = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
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
      // Mark messages as seen via socket too
      _socket?.emit('mark_seen', {'fromUserId': widget.peerUserId});
      // Check online status
      _socket?.emitWithAck('check_online', {'userId': widget.peerUserId}, ack: (data) {
        if (mounted && data is Map) {
          setState(() => _peerOnline = data['online'] == true);
        }
      });
    });

    // Incoming messages — deduplicated by _id
    _socket?.on('new_message', (data) {
      if (!mounted || data == null) return;
      final msg = data is Map<String, dynamic> ? data : <String, dynamic>{};
      final fromId = msg['fromUserId'] is Map ? msg['fromUserId']['_id'] : msg['fromUserId'];
      final toId = msg['toUserId'] is Map ? msg['toUserId']['_id'] : msg['toUserId'];
      final participants = {fromId?.toString(), toId?.toString()};

      if (participants.contains(_currentUserId) && participants.contains(widget.peerUserId)) {
        final serverId = msg['_id']?.toString() ?? '';
        final clientId = msg['clientMessageId']?.toString() ?? '';

        setState(() {
          // Robust deduplication:
          // 1. If we have a message with this clientMessageId, replace it (promotes it to server message)
          if (clientId.isNotEmpty && _messageMap.containsKey(clientId)) {
            _messageMap.remove(clientId);
          }
          // 2. If we have a message with this serverId, replace it
          if (serverId.isNotEmpty) {
            _messageMap[serverId] = msg;
          } else if (clientId.isNotEmpty) {
            _messageMap[clientId] = msg;
          }
          
          _updateSeenStatus();
        });

        // If incoming from peer, mark as seen immediately since we're in the chat
        if (fromId?.toString() == widget.peerUserId) {
          _socket?.emit('mark_seen', {'fromUserId': widget.peerUserId});
        }

        _scrollToBottom();
      }
    });

    // Seen status updates
    _socket?.on('messages_seen', (data) {
      if (!mounted || data == null) return;
      final seenBy = data['seenBy']?.toString();
      if (seenBy == widget.peerUserId) {
        setState(() {
          _peerHasSeenLatest = true;
          _seenAtText = data['seenAt'] != null ? _formatSeenAt(data['seenAt'].toString()) : 'Seen';
        });
      }
    });

    // Typing indicator
    _socket?.on('user_typing', (data) {
      if (!mounted || data == null) return;
      if (data['userId']?.toString() == widget.peerUserId) {
        setState(() => _peerTyping = data['isTyping'] == true);
      }
    });

    _socket?.connect();
  }



  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    _isTyping = false;
    _socket?.emit('typing', {'toUserId': widget.peerUserId, 'isTyping': false});

    // Add optimistic message
    final clientMessageId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final optimistic = <String, dynamic>{
      '_id': clientMessageId,
      'clientMessageId': clientMessageId,
      'fromUserId': _currentUserId,
      'toUserId': widget.peerUserId,
      'text': text,
      'messageType': 'text',
      'status': 'sending',
      'createdAt': now,
    };

    setState(() {
      _messageMap[clientMessageId] = optimistic;
      _isSending = true;
      _peerHasSeenLatest = false;
    });
    _scrollToBottom();

    try {
      final result = await ApiService.sendMessage(
        widget.peerUserId, 
        text,
        clientMessageId: clientMessageId,
      );
      if (mounted) {
        final serverId = result['_id']?.toString() ?? '';
        setState(() {
          _messageMap.remove(clientMessageId);
          if (serverId.isNotEmpty) {
            _messageMap[serverId] = result;
          } else {
            _messageMap[clientMessageId] = result;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          optimistic['status'] = 'failed';
          _messageMap[clientMessageId] = optimistic;
        });
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1200);
      if (picked == null) return;

      // Add optimistic image message
      final clientMessageId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();
      final optimistic = <String, dynamic>{
        '_id': clientMessageId,
        'clientMessageId': clientMessageId,
        'fromUserId': _currentUserId,
        'toUserId': widget.peerUserId,
        'text': '',
        'messageType': 'image',
        'imageUrl': picked.path, // local path for preview
        'status': 'sending',
        'createdAt': now,
        '_isLocalFile': true,
      };

      setState(() {
        _messageMap[clientMessageId] = optimistic;
        _isUploadingImage = true;
        _peerHasSeenLatest = false;
      });
      _scrollToBottom();

      final result = await ApiService.sendImageMessage(
        widget.peerUserId, 
        picked,
        clientMessageId: clientMessageId,
      );
      if (mounted) {
        final serverId = result['_id']?.toString() ?? '';
        setState(() {
          _messageMap.remove(clientMessageId);
          if (serverId.isNotEmpty && !result.containsKey('error')) {
            _messageMap[serverId] = result;
          } else {
            optimistic['status'] = 'failed';
            _messageMap[clientMessageId] = optimistic;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send image')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _sendVoiceMessage(String path) async {
    final clientMessageId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    
    final optimistic = <String, dynamic>{
      '_id': clientMessageId,
      'clientMessageId': clientMessageId,
      'fromUserId': _currentUserId,
      'toUserId': widget.peerUserId,
      'text': '',
      'messageType': 'voice',
      'voiceUrl': path, // local path for preview / visual
      'status': 'sending',
      'createdAt': now,
      '_isLocalFile': true,
    };

    setState(() {
      _messageMap[clientMessageId] = optimistic;
      _peerHasSeenLatest = false;
    });
    _scrollToBottom();

    try {
      final result = await ApiService.sendVoiceMessage(
        widget.peerUserId, 
        path,
        clientMessageId: clientMessageId,
      );
      if (mounted) {
        final serverId = result['_id']?.toString() ?? '';
        setState(() {
          _messageMap.remove(clientMessageId);
          if (serverId.isNotEmpty) {
            _messageMap[serverId] = result;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          optimistic['status'] = 'failed';
          _messageMap[clientMessageId] = optimistic;
        });
      }
    }
  }

  Future<void> _retryMessage(String tempId) async {
    final msg = _messageMap[tempId];
    if (msg == null) return;

    setState(() {
      msg['status'] = 'sending';
      _messageMap[tempId] = msg;
    });

    try {
      final result = await ApiService.sendMessage(widget.peerUserId, msg['text'] ?? '');
      if (mounted) {
        final id = _extractId(result);
        setState(() {
          _messageMap.remove(tempId);
          if (id.isNotEmpty) _messageMap[id] = result;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          msg['status'] = 'failed';
          _messageMap[tempId] = msg;
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

  // ─────────────────── TIME FORMATTERS ───────────────────

  String _formatMessageTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final ampm = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    } catch (_) {
      return '';
    }
  }

  String _formatDateHeader(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(date.year, date.month, date.day);
      final diff = today.difference(msgDay).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[date.month - 1]} ${date.day}';
    } catch (_) {
      return '';
    }
  }

  bool _shouldShowDateHeader(int index) {
    if (index == 0) return true;
    final msgs = _messages;
    final current = _formatDateHeader(msgs[index]['createdAt']?.toString());
    final previous = _formatDateHeader(msgs[index - 1]['createdAt']?.toString());
    return current != previous;
  }

  bool _isFirstInGroup(int index) {
    if (index == 0) return true;
    final msgs = _messages;
    final currentFrom = _getSenderId(msgs[index]);
    final prevFrom = _getSenderId(msgs[index - 1]);
    if (currentFrom != prevFrom) return true;
    if (_shouldShowDateHeader(index)) return true;
    return false;
  }

  bool _isLastInGroup(int index) {
    final msgs = _messages;
    if (index == msgs.length - 1) return true;
    final currentFrom = _getSenderId(msgs[index]);
    final nextFrom = _getSenderId(msgs[index + 1]);
    if (currentFrom != nextFrom) return true;
    if (_shouldShowDateHeader(index + 1)) return true;
    return false;
  }

  String _getSenderId(Map<String, dynamic> msg) {
    final from = msg['fromUserId'];
    return from is Map ? from['_id']?.toString() ?? '' : from?.toString() ?? '';
  }

  String _cloudinaryVideoToPreview(String videoUrl) {
    if (!videoUrl.contains('res.cloudinary.com') || !videoUrl.contains('/video/upload/')) return '';
    final transformed = videoUrl.replaceFirst('/video/upload/', '/video/upload/so_0/');
    return transformed.replaceFirst(RegExp(r'\.[a-zA-Z0-9]+$'), '.jpg');
  }

  // ─────────────────── BUILD ───────────────────

  @override
  Widget build(BuildContext context) {
    final msgs = _messages;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF1B2036),
                  backgroundImage: widget.peerProfilePic.isNotEmpty
                      ? NetworkImage(widget.peerProfilePic)
                      : null,
                  child: widget.peerProfilePic.isEmpty
                      ? Text(widget.peerUsername[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white))
                      : null,
                ),
                if (_peerOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.peerUsername, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
                Text(
                  _peerOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.poppins(color: _peerOnline ? Colors.greenAccent : Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E)))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: msgs.length + (_peerTyping ? 1 : 0) + (_peerHasSeenLatest ? 1 : 0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    itemBuilder: (context, index) {
                      // Typing indicator at the end
                      if (index >= msgs.length) {
                        if (_peerHasSeenLatest && index == msgs.length) {
                          return _buildSeenIndicator();
                        }
                        if (_peerTyping) {
                          return _buildTypingIndicator();
                        }
                        return const SizedBox.shrink();
                      }

                      final item = msgs[index];
                      final isMine = _getSenderId(item) == _currentUserId;
                      final isFirst = _isFirstInGroup(index);
                      final isLast = _isLastInGroup(index);
                      final showDate = _shouldShowDateHeader(index);
                      final messageType = (item['messageType'] ?? 'text').toString();
                      final status = (item['status'] ?? 'sent').toString();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Date header
                          if (showDate)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDateHeader(item['createdAt']?.toString()),
                                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                                  ),
                                ),
                              ),
                            ),

                          // Message bubble
                          Align(
                            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: status == 'failed'
                                  ? () => _retryMessage(_extractId(item))
                                  : null,
                              child: Container(
                                margin: EdgeInsets.only(
                                  top: isFirst ? 6 : 1.5,
                                  bottom: isLast ? 6 : 1.5,
                                ),
                                padding: messageType == 'image'
                                    ? const EdgeInsets.all(3)
                                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                decoration: BoxDecoration(
                                  color: isMine ? const Color(0xFFFF006E) : const Color(0xFF1B2036),
                                  borderRadius: _bubbleRadius(isMine, isFirst, isLast),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildMessageContent(item, isMine, messageType),
                                    // Time + status
                                    if (isLast)
                                      Padding(
                                        padding: messageType == 'image'
                                            ? const EdgeInsets.only(top: 4, right: 6, bottom: 2)
                                            : const EdgeInsets.only(top: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatMessageTime(item['createdAt']?.toString()),
                                              style: GoogleFonts.poppins(
                                                color: isMine ? Colors.white60 : Colors.white38,
                                                fontSize: 10,
                                              ),
                                            ),
                                            if (isMine) ...[
                                              const SizedBox(width: 4),
                                              _buildStatusIcon(status),
                                            ],
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Input bar
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                children: [
                  // Gallery button
                  GestureDetector(
                    onTap: _isUploadingImage ? null : _sendImage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1B2036),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: _isUploadingImage
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(color: Color(0xFFFF006E), strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_outlined, color: Colors.white70, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: (text) {
                        setState(() => _isTyping = text.isNotEmpty);
                        _socket?.emit('typing', {
                          'toUserId': widget.peerUserId,
                          'isTyping': text.isNotEmpty,
                        });
                      },
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_messageController.text.trim().isNotEmpty)
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF006E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 24),
                      ),
                    )
                  else
                    VoiceRecorderWidget(onRecordingComplete: _sendVoiceMessage),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── BUBBLE RADIUS ───────────────────

  BorderRadius _bubbleRadius(bool isMine, bool isFirst, bool isLast) {
    const r = Radius.circular(18);
    const small = Radius.circular(4);

    if (isMine) {
      return BorderRadius.only(
        topLeft: r,
        bottomLeft: r,
        topRight: isFirst ? r : small,
        bottomRight: isLast ? r : small,
      );
    } else {
      return BorderRadius.only(
        topRight: r,
        bottomRight: r,
        topLeft: isFirst ? r : small,
        bottomLeft: isLast ? r : small,
      );
    }
  }

  // ─────────────────── MESSAGE CONTENT ───────────────────

  Widget _buildMessageContent(Map<String, dynamic> item, bool isMine, String messageType) {
    if (messageType == 'image') {
      return _buildImageMessage(item, isMine);
    }

    final sharedVideo = item['sharedVideo'] is Map<String, dynamic>
        ? item['sharedVideo'] as Map<String, dynamic>
        : null;

    if (messageType == 'reel' && sharedVideo != null) {
      return _buildReelMessageCard(item, isMine);
    }

    if (messageType == 'voice') {
      final voiceUrl = (item['voiceUrl'] ?? '').toString();
      return AudioBubble(audioUrl: voiceUrl, isMine: isMine);
    }



    // Text message
    return Text(
      item['text']?.toString() ?? '',
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
    );
  }

  // ─────────────────── IMAGE MESSAGE ───────────────────

  Widget _buildImageMessage(Map<String, dynamic> item, bool isMine) {
    final imageUrl = (item['imageUrl'] ?? '').toString();
    final isLocal = item['_isLocalFile'] == true;
    final status = (item['status'] ?? 'sent').toString();

    Widget imageWidget;
    if (isLocal) {
      imageWidget = Image.asset(imageUrl, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B2036)),
      );
    } else if (imageUrl.isNotEmpty) {
      imageWidget = Image.network(imageUrl, fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E), strokeWidth: 2));
        },
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B2036),
          child: const Center(child: Icon(Icons.broken_image, color: Colors.white30))),
      );
    } else {
      imageWidget = Container(color: const Color(0xFF1B2036));
    }

    return GestureDetector(
      onTap: imageUrl.isNotEmpty && !isLocal
          ? () => _showFullScreenImage(imageUrl)
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
              if (status == 'sending')
                Container(
                  color: Colors.black38,
                  child: const Center(
                    child: SizedBox(width: 28, height: 28,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────── STATUS ICON ───────────────────

  Widget _buildStatusIcon(String status) {
    if (status == 'sending') {
      return const SizedBox(
        width: 12, height: 12,
        child: CircularProgressIndicator(color: Colors.white60, strokeWidth: 1.5),
      );
    }
    if (status == 'failed') {
      return const Icon(Icons.error_outline, color: Colors.redAccent, size: 14);
    }
    if (status == 'seen') {
      return const Icon(Icons.done_all, color: Color(0xFF60A5FA), size: 14);
    }
    if (status == 'delivered') {
      return const Icon(Icons.done_all, color: Colors.white60, size: 14);
    }
    // sent
    return const Icon(Icons.done, color: Colors.white60, size: 14);
  }

  // ─────────────────── SEEN INDICATOR ───────────────────

  Widget _buildSeenIndicator() {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _seenAtText ?? 'Seen',
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ─────────────────── TYPING INDICATOR ───────────────────

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2036),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDot(delay: 0),
            const SizedBox(width: 4),
            _TypingDot(delay: 200),
            const SizedBox(width: 4),
            _TypingDot(delay: 400),
          ],
        ),
      ),
    );
  }

  // ─────────────────── REEL MESSAGE CARD ───────────────────

  Widget _buildReelMessageCard(Map<String, dynamic> item, bool isMine) {
    final sharedVideo = item['sharedVideo'] as Map<String, dynamic>? ?? {};
    final videoUrl = (sharedVideo['videoUrl'] ?? '').toString();
    final thumbnailUrlRaw = (sharedVideo['thumbnailUrl'] ?? '').toString();
    final thumbnailUrl = thumbnailUrlRaw.isNotEmpty ? thumbnailUrlRaw : _cloudinaryVideoToPreview(videoUrl);
    final caption = (sharedVideo['caption'] ?? '').toString();
    final ownerUsername = (sharedVideo['ownerUsername'] ?? 'user').toString();
    final videoId = (sharedVideo['videoId'] ?? '').toString();

    return GestureDetector(
      onTap: (videoUrl.isEmpty && videoId.isEmpty) ? null : () async {
        Map<String, dynamic> payload = {
          '_id': videoId, 'videoUrl': videoUrl, 'thumbnailUrl': thumbnailUrl,
          'caption': caption,
          'userId': {'_id': sharedVideo['ownerId'] ?? '', 'username': ownerUsername, 'profilePic': ''},
          'likes': [], 'favorites': [], 'commentsCount': 0, 'repostsCount': 0, 'sharesCount': 0,
        };
        if (videoId.isNotEmpty) {
          try {
            final realVideo = await ApiService.getVideoById(videoId);
            if (realVideo.isNotEmpty && realVideo['error'] == null && realVideo['message'] == null) {
              payload = realVideo;
            }
          } catch (_) {}
        }
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenFeedScreen(
          videos: [payload], 
          initialIndex: 0,
          messageIdForStreak: _extractId(item),
        )));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 170, width: 190, color: Colors.black26,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl.isNotEmpty)
                    Image.network(thumbnailUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black26)),
                  const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 44)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Reel from @$ownerUsername',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          if (caption.isNotEmpty)
            Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: isMine ? Colors.white.withValues(alpha: 0.9) : Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────── ANIMATED TYPING DOT ───────────────────

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _animation.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
