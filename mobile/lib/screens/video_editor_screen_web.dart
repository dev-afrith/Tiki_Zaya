import 'package:flutter/material.dart';

class VideoEditorScreen extends StatelessWidget {
  final String videoSource;

  const VideoEditorScreen({super.key, required this.videoSource});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('TikiZaya Editor'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.video_library_outlined, color: Colors.white54, size: 64),
              SizedBox(height: 16),
              Text(
                'Video editing export is available on mobile only.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
