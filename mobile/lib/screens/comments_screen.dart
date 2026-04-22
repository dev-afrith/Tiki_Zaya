import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';

class CommentsSheet extends StatefulWidget {
  final String videoId;
  final VoidCallback? onGamificationChanged;
  const CommentsSheet({super.key, required this.videoId, this.onGamificationChanged});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoading = true;
  Map<String, dynamic>? _replyTo;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final me = await ApiService.getUser();
      final comments = await ApiService.getComments(widget.videoId);
      if (mounted) {
        setState(() {
          _currentUserId = (me?['id'] ?? me?['_id'] ?? '').toString();
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteComment({
    required String commentId,
    required int commentIndex,
    int? replyIndex,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('Delete Comment?', style: TextStyle(color: Colors.white)),
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

    try {
      await ApiService.deleteComment(commentId);
      if (!mounted) return;

      setState(() {
        if (replyIndex == null) {
          _comments.removeAt(commentIndex);
        } else {
          final comment = Map<String, dynamic>.from(_comments[commentIndex]);
          final replies = List<dynamic>.from(comment['replies'] ?? []);
          replies.removeAt(replyIndex);
          comment['replies'] = replies;
          _comments[commentIndex] = comment;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete comment')),
      );
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      final comment = _replyTo != null
          ? await ApiService.addCommentReply(widget.videoId, text, _replyTo!['_id'].toString())
          : await ApiService.addComment(widget.videoId, text);

      if (!mounted) return;

      setState(() {
        if (_replyTo != null) {
          final parentIndex = _comments.indexWhere((item) => item['_id'] == _replyTo!['_id']);
          if (parentIndex != -1) {
            final parent = Map<String, dynamic>.from(_comments[parentIndex]);
            final replies = List<dynamic>.from(parent['replies'] ?? []);
            replies.add(comment);
            parent['replies'] = replies;
            parent['replyCount'] = (parent['replyCount'] ?? 0) + 1;
            _comments[parentIndex] = parent;
          }
        } else {
          _comments.insert(0, comment);
        }
        _commentController.clear();
        _replyTo = null;
      });
      widget.onGamificationChanged?.call();
    } catch (e) {
      debugPrint('Comment error: $e');
    }
  }

  Future<void> _toggleCommentLike(String commentId, int commentIndex, {int? replyIndex}) async {
    try {
      final result = await ApiService.toggleCommentLike(commentId);
      if (!mounted) return;

      setState(() {
        if (replyIndex == null) {
          final comment = Map<String, dynamic>.from(_comments[commentIndex]);
          final likes = List<dynamic>.from(comment['likes'] ?? []);
          if (result['liked'] == true) {
            likes.add('me');
          } else if (likes.isNotEmpty) {
            likes.removeLast();
          }
          comment['likes'] = likes;
          _comments[commentIndex] = comment;
        } else {
          final comment = Map<String, dynamic>.from(_comments[commentIndex]);
          final replies = List<dynamic>.from(comment['replies'] ?? []);
          final reply = Map<String, dynamic>.from(replies[replyIndex]);
          final likes = List<dynamic>.from(reply['likes'] ?? []);
          if (result['liked'] == true) {
            likes.add('me');
          } else if (likes.isNotEmpty) {
            likes.removeLast();
          }
          reply['likes'] = likes;
          replies[replyIndex] = reply;
          comment['replies'] = replies;
          _comments[commentIndex] = comment;
        }
      });
    } catch (e) {
      debugPrint('Comment like error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_comments.length} Comments',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E)))
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = Map<String, dynamic>.from(_comments[index]);
                          final user = comment['userId'];
                          final username = user is Map ? user['username'] ?? 'User' : 'User';
                          final commentOwnerId = user is Map ? (user['_id'] ?? '').toString() : '';
                          final likes = (comment['likes'] as List?) ?? [];
                          final replies = (comment['replies'] as List?) ?? [];

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFFFF006E).withValues(alpha: 0.3),
                                      child: Text(
                                        username[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFFFF006E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '@$username',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (commentOwnerId == _currentUserId)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: GestureDetector(
                                                onTap: () => _confirmDeleteComment(
                                                  commentId: comment['_id'].toString(),
                                                  commentIndex: index,
                                                ),
                                                child: const Icon(Icons.delete_outline, color: Colors.white38, size: 16),
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            comment['text'] ?? '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _toggleCommentLike(comment['_id'].toString(), index),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      likes.isNotEmpty ? Icons.favorite : Icons.favorite_border,
                                                      color: likes.isNotEmpty ? const Color(0xFFFF006E) : Colors.white54,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${likes.length}',
                                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _replyTo = comment;
                                                  });
                                                },
                                                child: const Text(
                                                  'Reply',
                                                  style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (replies.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 40),
                                    child: Column(
                                      children: replies.asMap().entries.map((entry) {
                                        final reply = Map<String, dynamic>.from(entry.value);
                                        final replyUser = reply['userId'];
                                        final replyUsername = replyUser is Map ? replyUser['username'] ?? 'User' : 'User';
                                        final replyOwnerId = replyUser is Map ? (replyUser['_id'] ?? '').toString() : '';
                                        final replyLikes = (reply['likes'] as List?) ?? [];

                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundColor: Colors.white12,
                                                child: Text(
                                                  replyUsername[0].toUpperCase(),
                                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '@$replyUsername',
                                                      style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    if (replyOwnerId == _currentUserId)
                                                      Align(
                                                        alignment: Alignment.centerRight,
                                                        child: GestureDetector(
                                                          onTap: () => _confirmDeleteComment(
                                                            commentId: reply['_id'].toString(),
                                                            commentIndex: index,
                                                            replyIndex: entry.key,
                                                          ),
                                                          child: const Icon(Icons.delete_outline, color: Colors.white38, size: 14),
                                                        ),
                                                      ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      reply['text'] ?? '',
                                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    GestureDetector(
                                                      onTap: () => _toggleCommentLike(reply['_id'].toString(), index, replyIndex: entry.key),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            replyLikes.isNotEmpty ? Icons.favorite : Icons.favorite_border,
                                                            color: replyLikes.isNotEmpty ? const Color(0xFFFF006E) : Colors.white54,
                                                            size: 14,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            '${replyLikes.length}',
                                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              border: const Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_replyTo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text(
                          'Replying to @${(_replyTo!['userId'] is Map ? _replyTo!['userId']['username'] : 'User')}',
                          style: const TextStyle(color: Color(0xFFFF006E), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _replyTo = null),
                          child: const Icon(Icons.close, color: Colors.white54, size: 16),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _replyTo != null ? 'Write a reply...' : 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _postComment,
                      icon: const Icon(Icons.send, color: Color(0xFFFF006E)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
