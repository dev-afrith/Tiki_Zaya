import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Centralized video controller pool that keeps at most 3 controllers alive:
/// [current - 1], [current], [current + 1].
///
/// This dramatically reduces memory usage and prevents the OOM crashes
/// that happen when each FeedPost creates its own permanent controller.
class VideoPreloadManager {
  /// Cache of initialized controllers keyed by feed index.
  final Map<int, VideoPlayerController> _controllers = {};

  /// URLs keyed by feed index — used to detect when feed data changes.
  final Map<int, String> _urls = {};

  /// The index currently focused (playing).
  int _currentIndex = 0;

  /// The maximum number of controllers to keep alive simultaneously.
  static const int _windowSize = 3;

  /// Get the currently focused index.
  int get currentIndex => _currentIndex;

  /// Update the feed focus to [index] and manage the controller window.
  ///
  /// This will:
  /// 1. Pause the old current controller
  /// 2. Pre-initialize controllers for [index-1, index, index+1]
  /// 3. Dispose controllers outside this window
  /// 4. Play the controller at [index]
  Future<void> setCurrentIndex(int index, List<dynamic> videos) async {
    final oldIndex = _currentIndex;
    _currentIndex = index;

    // Pause the previously playing controller
    if (oldIndex != index) {
      _controllers[oldIndex]?.pause();
    }

    // Determine the window of indices to keep
    final windowStart = (index - 1).clamp(0, videos.length - 1);
    final windowEnd = (index + 1).clamp(0, videos.length - 1);

    // Dispose controllers outside the window
    final keysToRemove = <int>[];
    for (final key in _controllers.keys) {
      if (key < windowStart || key > windowEnd) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      await _disposeController(key);
    }

    // Pre-initialize controllers within the window
    for (int i = windowStart; i <= windowEnd; i++) {
      if (i < videos.length) {
        await _ensureController(i, videos[i]);
      }
    }

    // Play the current one
    final current = _controllers[index];
    if (current != null && current.value.isInitialized && !current.value.isPlaying) {
      current.play();
    }
  }

  /// Get the controller for a specific index (may be null if not yet ready).
  VideoPlayerController? getController(int index) {
    return _controllers[index];
  }

  /// Check if the controller for [index] is initialized and ready.
  bool isReady(int index) {
    final controller = _controllers[index];
    return controller != null && controller.value.isInitialized;
  }

  /// Ensure a controller exists for the given index and URL.
  Future<void> _ensureController(int index, dynamic videoData) async {
    final url = _extractUrl(videoData);
    if (url.isEmpty) return;

    // If controller already exists with same URL, skip
    if (_controllers.containsKey(index) && _urls[index] == url) {
      return;
    }

    // If URL changed, dispose old controller first
    if (_controllers.containsKey(index)) {
      await _disposeController(index);
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controllers[index] = controller;
      _urls[index] = url;

      await controller.initialize();
      controller.setLooping(true);

      // Only auto-play if this is the current index
      if (index == _currentIndex) {
        controller.play();
      }
    } catch (e) {
      debugPrint('[VideoPreloadManager] Failed to initialize controller at $index: $e');
      // Remove failed controller
      _controllers.remove(index);
      _urls.remove(index);
    }
  }

  /// Dispose a single controller by index.
  Future<void> _disposeController(int index) async {
    final controller = _controllers.remove(index);
    _urls.remove(index);
    if (controller != null) {
      try {
        await controller.pause();
        await controller.dispose();
      } catch (_) {}
    }
  }

  /// Extract video URL from the video data map.
  String _extractUrl(dynamic videoData) {
    if (videoData is Map) {
      return (videoData['videoUrl'] ?? '').toString();
    }
    return '';
  }

  /// Dispose all controllers. Call this when the feed screen is disposed.
  Future<void> disposeAll() async {
    for (final index in _controllers.keys.toList()) {
      await _disposeController(index);
    }
    _controllers.clear();
    _urls.clear();
  }

  /// Pause all controllers (e.g., when app goes to background).
  void pauseAll() {
    for (final controller in _controllers.values) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  /// Resume the current controller.
  void resumeCurrent() {
    final controller = _controllers[_currentIndex];
    if (controller != null && controller.value.isInitialized && !controller.value.isPlaying) {
      controller.play();
    }
  }
}
