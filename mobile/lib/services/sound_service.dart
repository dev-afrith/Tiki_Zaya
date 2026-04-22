import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final _audioRecorder = AudioRecorder();
  String? _currentPath;

  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        _currentPath = p.join(
          directory.path,
          'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );

        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );

        await _audioRecorder.start(config, path: _currentPath!);
      }
    } catch (e) {
      print('Start Recording Error: $e');
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      return path;
    } catch (e) {
      print('Stop Recording Error: $e');
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      final path = await stopRecording();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
  }

  Future<bool> isRecording() => _audioRecorder.isRecording();

  void dispose() {
    _audioRecorder.dispose();
  }
}
