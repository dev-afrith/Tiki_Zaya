import 'dart:io';

import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';

import 'video_processing_service_stub.dart';

class VideoProcessingServiceImpl implements VideoProcessingService {
  @override
  Future<String> trimVideo({required String inputPath, required Duration start, required Duration end, required String outputPath}) async {
    final command = '-y -ss ${_fmt(start)} -to ${_fmt(end)} -i "$inputPath" -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k "$outputPath"';
    await _run(command);
    return outputPath;
  }

  @override
  Future<String> applyEdits({required String inputPath, required String outputPath, Duration? start, Duration? end, double speed = 1.0, double brightness = 0, double contrast = 0, double saturation = 1.0, bool beauty = false, String? musicPath, double musicVolume = 0.7, double originalVolume = 1.0, String? voicePath, bool muteOriginal = false, String? textFilter, String? effect, String? stickerPath, String? overlayText, double textX = 20, double textY = 20, double textSize = 28, String textColor = 'white', int? textStartMs, int? textEndMs}) async {
    final inputs = <String>['-i "$inputPath"'];
    if (musicPath != null && musicPath.isNotEmpty) inputs.add('-i "$musicPath"');
    if (voicePath != null && voicePath.isNotEmpty) inputs.add('-i "$voicePath"');
    if (stickerPath != null && stickerPath.isNotEmpty) inputs.add('-i "$stickerPath"');

    final videoEffects = <String>[];
    final audioEffects = <String>[];

    if (start != null || end != null) {
      final startStr = start != null ? ' -ss ${_fmt(start)}' : '';
      final endStr = end != null ? ' -to ${_fmt(end)}' : '';
      inputs[0] = '-y$startStr$endStr -i "$inputPath"';
    }

    if (speed != 1.0) {
      videoEffects.add('setpts=${(1 / speed).toStringAsFixed(3)}*PTS');
      audioEffects.add(_buildAtempoChain(speed));
    }

    if (brightness != 0 || contrast != 0 || saturation != 1.0) {
      final b = brightness.toStringAsFixed(2);
      final c = (1 + contrast).clamp(0.1, 3.0).toStringAsFixed(2);
      final s = saturation.toStringAsFixed(2);
      videoEffects.add('eq=brightness=$b:contrast=$c:saturation=$s');
    }

    if (beauty) {
      videoEffects.add('smartblur=lr=1:ls=2');
      videoEffects.add('eq=brightness=0.04:contrast=1.08:saturation=1.08');
    }

    switch (effect) {
      case 'Blur':
        videoEffects.add('boxblur=5:1');
        break;
      case 'Glitch':
        videoEffects.add('noise=alls=22:allf=t+u');
        break;
      case 'Fade':
        videoEffects.add('fade=t=in:st=0:d=0.4,fade=t=out:st=4.6:d=0.4');
        break;
      case 'Zoom':
        videoEffects.add('scale=iw*1.08:ih*1.08,crop=iw:ih');
        break;
      default:
        break;
    }

    if (textFilter != null && textFilter.isNotEmpty && textFilter != 'Original') {
      videoEffects.add('hue=s=0');
    }

    if (overlayText != null && overlayText.trim().isNotEmpty) {
      final safeText = overlayText.replaceAll(':', '\\:').replaceAll("'", "\\'");
      final enable = textStartMs != null
          ? ":enable='between(t,${textStartMs / 1000.0},${(textEndMs ?? textStartMs + 3000) / 1000.0})'"
          : '';
      videoEffects.add("drawtext=text='$safeText':fontcolor=$textColor:fontsize=${textSize.toInt()}:x=$textX:y=$textY$enable");
    }

    String? filterComplex;
    String audioMap = '-map 0:a?';
    if (musicPath != null && musicPath.isNotEmpty && voicePath != null && voicePath.isNotEmpty) {
      filterComplex = '[0:a]volume=${muteOriginal ? 0 : originalVolume}[base];[1:a]volume=$musicVolume[music];[2:a]volume=1.0[voice];[base][music][voice]amix=inputs=3:duration=shortest:dropout_transition=2[aout]';
      audioMap = '-map "[aout]"';
    } else if (musicPath != null && musicPath.isNotEmpty) {
      filterComplex = '[0:a]volume=${muteOriginal ? 0 : originalVolume}[base];[1:a]volume=$musicVolume[music];[base][music]amix=inputs=2:duration=shortest:dropout_transition=2[aout]';
      audioMap = '-map "[aout]"';
    } else if (voicePath != null && voicePath.isNotEmpty) {
      filterComplex = '[0:a]volume=${muteOriginal ? 0 : originalVolume}[base];[1:a]volume=1.0[voice];[base][voice]amix=inputs=2:duration=shortest:dropout_transition=2[aout]';
      audioMap = '-map "[aout]"';
    } else if (muteOriginal) {
      audioMap = '-an';
    } else if (audioEffects.isNotEmpty) {
      audioMap = '-af "${audioEffects.join(',')}"';
    }

    String command = '-y ${inputs.join(' ')} ';
    if (filterComplex != null) {
      command += '-filter_complex "$filterComplex" ';
    }
    if (videoEffects.isNotEmpty) {
      command += '-vf "${videoEffects.join(',')}" ';
    }
    command += '$audioMap -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k "$outputPath"';

    if (stickerPath != null && stickerPath.isNotEmpty) {
      command = '-y ${inputs.join(' ')} -filter_complex "[0:v][3:v]overlay=20:20" -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k "$outputPath"';
    }

    await _run(command.replaceAll(RegExp(r'\s+'), ' ').trim());
    return outputPath;
  }

  @override
  Future<String> mergeClips({required List<String> inputs, required String outputPath}) async {
    if (inputs.isEmpty) throw ArgumentError('No clips selected');
    final listFile = '${outputPath}_concat.txt';
    await File(listFile).writeAsString(inputs.map((path) => "file '$path'").join('\n'));
    await _run('-y -f concat -safe 0 -i "$listFile" -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k "$outputPath"');
    return outputPath;
  }

  Future<void> _run(String command) async {
    final session = await FFmpegKit.executeAsync(command);
    final rc = await session.getReturnCode();
    if (rc == null || !ReturnCode.isSuccess(rc)) {
      throw Exception('FFmpeg processing failed');
    }
  }

  String _fmt(Duration d) => d.toString().split('.').first.padLeft(8, '0');

  String _buildAtempoChain(double speed) {
    if (speed == 1.0) return 'atempo=1.0';
    final parts = <String>[];
    var remaining = speed;
    while (remaining > 2.0) {
      parts.add('atempo=2.0');
      remaining /= 2.0;
    }
    if (remaining < 0.5) {
      parts.add('atempo=0.5');
      remaining *= 2.0;
    }
    parts.add('atempo=${remaining.toStringAsFixed(3)}');
    return parts.join(',');
  }
}

VideoProcessingService createVideoProcessingService() => VideoProcessingServiceImpl();
