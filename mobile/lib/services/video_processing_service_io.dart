import 'dart:io';

import 'video_processing_service_stub.dart';

class VideoProcessingServiceImpl implements VideoProcessingService {
  @override
  Future<String> trimVideo({required String inputPath, required Duration start, required Duration end, required String outputPath}) async {
    await _copyToOutput(inputPath, outputPath);
    return outputPath;
  }

  @override
  Future<String> applyEdits({required String inputPath, required String outputPath, Duration? start, Duration? end, double speed = 1.0, double brightness = 0, double contrast = 0, double saturation = 1.0, bool beauty = false, String? musicPath, double musicVolume = 0.7, double originalVolume = 1.0, String? voicePath, bool muteOriginal = false, String? textFilter, String? effect, String? stickerPath, String? overlayText, double textX = 20, double textY = 20, double textSize = 28, String textColor = 'white', int? textStartMs, int? textEndMs}) async {
    await _copyToOutput(inputPath, outputPath);
    return outputPath;
  }

  @override
  Future<String> mergeClips({required List<String> inputs, required String outputPath}) async {
    if (inputs.isEmpty) throw ArgumentError('No clips selected');
    await _copyToOutput(inputs.first, outputPath);
    return outputPath;
  }

  Future<void> _copyToOutput(String inputPath, String outputPath) async {
    final input = File(inputPath);
    if (!await input.exists()) {
      throw Exception('Input video not found');
    }
    await input.copy(outputPath);
  }
}

VideoProcessingService createVideoProcessingService() => VideoProcessingServiceImpl();
