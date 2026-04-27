import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';

class FeedProvider extends ChangeNotifier {
  List<dynamic> _videos = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;

  List<dynamic> get videos => _videos;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> fetchFeed({bool reset = false}) async {
    if (reset) {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
      _error = null;
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final data = await ApiService.getFeed(page: _currentPage, limit: 10);
      final items = (data['videos'] as List?) ?? [];
      final totalPages = (data['totalPages'] is num) ? (data['totalPages'] as num).toInt() : 1;

      if (reset) {
        _videos = items;
      } else {
        _videos.addAll(items);
      }

      _currentPage++;
      _hasMore = _currentPage <= totalPages && items.isNotEmpty;
      _error = null;
    } catch (e) {
      _error = 'Failed to load feed';
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Update video data silently without triggering a global rebuild
  void updateVideoSilently(String videoId, Map<String, dynamic> updates) {
    final index = _videos.indexWhere((v) => v['_id'] == videoId);
    if (index != -1) {
      final video = Map<String, dynamic>.from(_videos[index]);
      updates.forEach((key, value) {
        video[key] = value;
      });
      _videos[index] = video;
    }
  }

  // Optimistic UI updates
  Future<void> toggleLike(String videoId, String userId) async {
    final index = _videos.indexWhere((v) => v['_id'] == videoId);
    if (index == -1) return;

    final video = Map<String, dynamic>.from(_videos[index]);
    final likes = List<String>.from(video['likes'] ?? []);
    
    final wasLiked = likes.contains(userId);
    if (wasLiked) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }

    video['likes'] = likes;
    _videos[index] = video;
    notifyListeners();

    try {
      final result = await ApiService.toggleLike(videoId);
      // Synchronize with server response just in case
      if (result.containsKey('likes')) {
        video['likes'] = result['likes'];
        _videos[index] = video;
        notifyListeners();
      }
    } catch (e) {
      // Rollback on error
      if (wasLiked) {
        likes.add(userId);
      } else {
        likes.remove(userId);
      }
      video['likes'] = likes;
      _videos[index] = video;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleFavorite(String videoId, String userId) async {
    final index = _videos.indexWhere((v) => v['_id'] == videoId);
    if (index == -1) return;

    final video = Map<String, dynamic>.from(_videos[index]);
    final favorites = List<String>.from(video['favorites'] ?? []);
    
    final wasFavorited = favorites.contains(userId);
    if (wasFavorited) {
      favorites.remove(userId);
    } else {
      favorites.add(userId);
    }

    video['favorites'] = favorites;
    _videos[index] = video;
    notifyListeners();

    try {
      final result = await ApiService.toggleFavorite(videoId);
      if (result.containsKey('favorites')) {
         video['favorites'] = result['favorites'];
         _videos[index] = video;
         notifyListeners();
      }
    } catch (e) {
      // Rollback
      if (wasFavorited) {
        favorites.add(userId);
      } else {
        favorites.remove(userId);
      }
      video['favorites'] = favorites;
      _videos[index] = video;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleRepost(String videoId) async {
    final index = _videos.indexWhere((v) => v['_id'] == videoId);
    if (index == -1) return;

    final video = Map<String, dynamic>.from(_videos[index]);
    final currentCount = (video['repostsCount'] ?? 0) as int;
    
    // We don't have a list of user IDs for reposts in the current video model, 
    // so we just increment/decrement the count optimistically.
    // This is a bit tricky without knowing the current user's repost state.
    // For now, let's assume we can't do it perfectly without more info, 
    // but we can at least update the count.
    
    try {
      final result = await ApiService.toggleRepost(videoId);
      video['repostsCount'] = result['repostsCount'] ?? currentCount;
      _videos[index] = video;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
