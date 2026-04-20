import 'package:flutter/material.dart';
import 'package:mobile/screens/home_screen.dart';

class FullscreenFeedScreen extends StatefulWidget {
  final List<dynamic> videos;
  final int initialIndex;
  final Map<String, dynamic>? currentUser;

  const FullscreenFeedScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
    this.currentUser,
  });

  @override
  State<FullscreenFeedScreen> createState() => _FullscreenFeedScreenState();
}

class _FullscreenFeedScreenState extends State<FullscreenFeedScreen> {
  late final PageController _controller;
  late int _focusedIndex;

  @override
  void initState() {
    super.initState();
    _focusedIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              itemCount: widget.videos.length,
              onPageChanged: (index) {
                setState(() {
                  _focusedIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return FeedPost(
                  video: widget.videos[index],
                  shouldPlay: _focusedIndex == index,
                  isFullscreen: true,
                  currentUser: widget.currentUser,
                  onRequestFullscreen: null,
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
