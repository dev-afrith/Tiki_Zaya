import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/services/sound_service.dart';
import 'package:google_fonts/google_fonts.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String path) onRecordingComplete;
  const VoiceRecorderWidget({super.key, required this.onRecordingComplete});

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  bool _isRecording = false;
  bool _isCancelled = false;
  int _seconds = 0;
  Timer? _timer;
  double _dragProgress = 0.0;
  final double _cancelThreshold = -100.0; // Slide left to cancel

  void _startTimer() {
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
      if (_seconds >= 60) {
        _stopRecording();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _isCancelled = false;
      _dragProgress = 0.0;
    });
    await SoundService().startRecording();
    _startTimer();
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _stopTimer();
    setState(() => _isRecording = false);
    
    if (_isCancelled || _seconds < 1) {
      await SoundService().cancelRecording();
    } else {
      final path = await SoundService().stopRecording();
      if (path != null) {
        widget.onRecordingComplete(path);
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRecording) {
      return GestureDetector(
        onLongPress: _startRecording,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFFF006E),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic, color: Colors.white, size: 24),
        ),
      );
    }

    return Expanded(
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2036),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              '0:${_seconds.toString().padLeft(2, '0')}',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragProgress += details.delta.dx;
                  if (_dragProgress < _cancelThreshold) {
                    _isCancelled = true;
                  }
                });
              },
              onHorizontalDragEnd: (details) {
                _stopRecording();
              },
              onLongPressEnd: (details) {
                _stopRecording();
              },
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  Opacity(
                    opacity: _isCancelled ? 1.0 : 0.5,
                    child: Text(
                      _isCancelled ? 'Release to Cancel' : '< Slide to Cancel',
                      style: GoogleFonts.outfit(
                        color: _isCancelled ? Colors.redAccent : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
