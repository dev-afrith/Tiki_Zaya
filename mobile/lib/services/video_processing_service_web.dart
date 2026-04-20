import 'video_processing_service_stub.dart';

class VideoProcessingServiceImpl implements VideoProcessingService {
  @override
  Future<String> trimVideo({required String inputPath, required Duration start, required Duration end, required String outputPath}) {
    throw UnsupportedError('Video export is supported on mobile only.');
  }

  @override
  Future<String> applyEdits({required String inputPath, required String outputPath, Duration? start, Duration? end, double speed = 1.0, double brightness = 0, double contrast = 0, double saturation = 1.0, bool beauty = false, String? musicPath, double musicVolume = 0.7, double originalVolume = 1.0, String? voicePath, bool muteOriginal = false, String? textFilter, String? effect, String? stickerPath, String? overlayText, double textX = 20, double textY = 20, double textSize = 28, String textColor = 'white', int? textStartMs, int? textEndMs}) {
    throw UnsupportedError('Video export is supported on mobile only.');
  }

  @override
  Future<String> mergeClips({required List<String> inputs, required String outputPath}) {
    throw UnsupportedError('Video export is supported on mobile only.');
  }
}

VideoProcessingService createVideoProcessingService() => VideoProcessingServiceImpl();
