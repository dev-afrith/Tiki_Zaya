import 'video_processing_service_stub.dart';
import 'video_processing_service_io.dart' if (dart.library.html) 'video_processing_service_web.dart' as impl;

export 'video_processing_service_stub.dart';

VideoProcessingService createVideoProcessingService() => impl.createVideoProcessingService();
