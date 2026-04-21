import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../services/video_processing_service.dart';

class VideoEditorScreen extends StatefulWidget {
  final String videoSource;

  const VideoEditorScreen({super.key, required this.videoSource});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  static const String _brandLogoAsset = 'assets/branding/logo.png';

  final TextEditingController _textController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  final VideoProcessingService _processor = createVideoProcessingService();

  VideoPlayerController? _controller;
  EditorTool _activeTool = EditorTool.trim;
  bool _loading = true;
  bool _playing = true;
  bool _processing = false;
  String? _message;

  double _trimStart = 0;
  double _trimEnd = 0;
  double _speed = 1.0;
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 1.0;
  final double _musicVolume = 0.7;
  final double _originalVolume = 1.0;
  bool _beauty = false;
  final bool _muteOriginal = false;
  int _filterIndex = 0;
  int _effectIndex = 0;

  String? _musicPath;
  String? _voicePath;
  String? _stickerPath;
  final List<_TextOverlay> _texts = [];
  final List<_StickerOverlay> _stickers = [];
  final List<String> _clipPaths = [];

  static const List<_FilterPreset> _filters = [
    _FilterPreset('Original', 0.0, 0.0, 1.0, false),
    _FilterPreset('Vivid', 0.04, 0.14, 1.2, false),
    _FilterPreset('Warm', 0.06, 0.06, 1.1, false),
    _FilterPreset('Vintage', 0.03, -0.02, 0.88, false),
    _FilterPreset('Noir', 0.0, 0.28, 0.0, false),
    _FilterPreset('Beauty', 0.05, 0.08, 1.06, true),
  ];

  static const List<String> _effects = ['None', 'Blur', 'Glitch', 'Fade', 'Zoom'];
  static const List<double> _speeds = [0.5, 1.0, 1.5, 2.0];
  static const List<double> _logoStickerSizes = [72, 88, 104, 120, 136, 152, 168, 184];

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _initializePreview() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoSource));
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();
      setState(() {
        _trimEnd = _controller!.value.duration.inMilliseconds / 1000;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _message = 'Failed to load video preview.';
      });
    }
  }

  void _togglePlay() {
    if (_controller == null) return;
    setState(() {
      if (_playing) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _playing = !_playing;
    });
  }

  void _undoLast() {
    setState(() {
      if (_texts.isNotEmpty) {
        _texts.removeLast();
      } else if (_stickers.isNotEmpty) {
        _stickers.removeLast();
      } else if (_clipPaths.isNotEmpty) {
        _clipPaths.removeLast();
      }
      _message = 'Undid last change';
    });
  }

  void _selectTool(EditorTool tool) {
    setState(() {
      _activeTool = tool;
      if (tool != EditorTool.text) {
        _textController.clear();
      }
    });
  }

  Future<void> _pickMusic() async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    if (result?.files.single.path != null) {
      setState(() {
        _musicPath = result!.files.single.path!;
        _message = 'Music track added';
      });
    }
  }

  Future<void> _pickVoice() async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    if (result?.files.single.path != null) {
      setState(() {
        _voicePath = result!.files.single.path!;
        _message = 'Voice track added';
      });
    }
  }

  Future<void> _recordVoice() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _message = 'Microphone permission is required.');
      return;
    }

    final isRecording = await _recorder.isRecording();
    if (!isRecording) {
      final path = '${Directory.systemTemp.path}/tikizaya_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() => _message = 'Recording voice-over... tap again to stop');
      return;
    }

    final path = await _recorder.stop();
    if (path != null) {
      setState(() {
        _voicePath = path;
        _message = 'Voice-over saved';
      });
    }
  }

  Future<void> _pickClips() async {
    final result = await FilePicker.pickFiles(allowMultiple: true, type: FileType.video);
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _clipPaths
        ..clear()
        ..addAll(result.files.where((file) => file.path != null).map((file) => file.path!).toList());
      _message = 'Selected ${_clipPaths.length} clips';
    });
  }

  void _applyFilter(int index) {
    final preset = _filters[index];
    setState(() {
      _filterIndex = index;
      _brightness = preset.brightness;
      _contrast = preset.contrast;
      _saturation = preset.saturation;
      _beauty = preset.beauty;
    });
  }

  void _addSticker(double size) {
    setState(() {
      _stickers.add(_StickerOverlay(position: const Offset(120, 160), size: size));
      _stickerPath = _brandLogoAsset;
      _message = 'Logo sticker added';
    });
  }

  void _addText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _texts.add(_TextOverlay(
        text: text,
        position: const Offset(120, 150),
        startMs: 0,
        endMs: _controller?.value.duration.inMilliseconds ?? 3000,
      ));
      _textController.clear();
      _activeTool = EditorTool.text;
      _message = 'Text overlay added';
    });
  }

  Future<void> _exportVideo() async {
    if (_controller == null || _processing) return;

    setState(() {
      _processing = true;
      _message = 'Exporting video...';
    });

    try {
      final outputPath = '${Directory.systemTemp.path}/tikizaya_export_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final textOverlay = _texts.isNotEmpty ? _texts.last : null;
      final result = await _processor.applyEdits(
        inputPath: widget.videoSource,
        outputPath: outputPath,
        start: _trimStart > 0 ? Duration(milliseconds: (_trimStart * 1000).round()) : null,
        end: _trimEnd > 0 ? Duration(milliseconds: (_trimEnd * 1000).round()) : null,
        speed: _speed,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        beauty: _beauty,
        musicPath: _musicPath,
        musicVolume: _musicVolume,
        originalVolume: _originalVolume,
        voicePath: _voicePath,
        muteOriginal: _muteOriginal,
        effect: _effects[_effectIndex],
        stickerPath: _stickerPath,
        overlayText: textOverlay?.text,
        textX: textOverlay?.position.dx ?? 20,
        textY: textOverlay?.position.dy ?? 20,
        textStartMs: textOverlay?.startMs,
        textEndMs: textOverlay?.endMs,
      );

      if (!mounted) return;
      Navigator.pop(context, {
        'exportPath': result,
        'trimStart': _trimStart,
        'trimEnd': _trimEnd,
        'speed': _speed,
        'musicPath': _musicPath,
        'voicePath': _voicePath,
        'beauty': _beauty,
        'texts': _texts.map((text) => text.toMap()).toList(),
        'stickers': _stickers.map((sticker) => sticker.toMap()).toList(),
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Export failed: $error');
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _mergeClips() async {
    if (_clipPaths.isEmpty || _processing) return;
    setState(() {
      _processing = true;
      _message = 'Merging clips...';
    });
    try {
      final outputPath = '${Directory.systemTemp.path}/tikizaya_merge_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final result = await _processor.mergeClips(inputs: _clipPaths, outputPath: outputPath);
      if (!mounted) return;
      Navigator.pop(context, {'exportPath': result});
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Merge failed: $error');
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = _controller;
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildTopBar(context),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          color: Colors.black,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_loading)
                                const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E)))
                              else if (_message != null && video == null)
                                Center(
                                  child: Text(
                                    _message!,
                                    style: const TextStyle(color: Colors.white70),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else if (video != null)
                                GestureDetector(
                                  onTap: _togglePlay,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Center(
                                        child: AspectRatio(
                                          aspectRatio: video.value.aspectRatio,
                                          child: VideoPlayer(video),
                                        ),
                                      ),
                                      if (!_playing)
                                        const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 72)),
                                      for (final text in _texts) _buildTextOverlay(text),
                                      for (final sticker in _stickers) _buildStickerOverlay(sticker),
                                    ],
                                  ),
                                ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 16,
                                child: _buildQuickActions(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _iconCircle(Icons.close_rounded, () => Navigator.pop(context)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'TikiZaya Editor',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          _iconCircle(Icons.undo_rounded, _undoLast),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(child: _pillButton('Music', Icons.music_note_rounded, _pickMusic)),
        const SizedBox(width: 10),
        Expanded(child: _pillButton('Voice', Icons.mic_rounded, _recordVoice)),
        const SizedBox(width: 10),
        Expanded(child: _pillButton('Merge', Icons.layers_rounded, _pickClips)),
      ],
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolStrip(),
            if (_activeTool == EditorTool.trim) _buildTrimPanel(),
            if (_activeTool == EditorTool.filters) _buildFilterPanel(),
            if (_activeTool == EditorTool.speed) _buildSpeedPanel(),
            if (_activeTool == EditorTool.effects) _buildEffectsPanel(),
            if (_activeTool == EditorTool.beauty) _buildBeautyPanel(),
            if (_activeTool == EditorTool.text) _buildTextPanel(),
            if (_activeTool == EditorTool.stickers) _buildStickerPanel(),
            if (_activeTool == EditorTool.merge) _buildMergePanel(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processing ? null : _exportVideo,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFFF006E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_processing ? 'Processing...' : 'Export Video'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolStrip() {
    final tools = [
      _ToolSpec(EditorTool.trim, 'Trim', Icons.content_cut_rounded),
      _ToolSpec(EditorTool.music, 'Music', Icons.music_note_rounded),
      _ToolSpec(EditorTool.voice, 'Voice', Icons.mic_rounded),
      _ToolSpec(EditorTool.filters, 'Filters', Icons.auto_awesome_rounded),
      _ToolSpec(EditorTool.text, 'Text', Icons.text_fields_rounded),
      _ToolSpec(EditorTool.stickers, 'Logo', Icons.image_outlined),
      _ToolSpec(EditorTool.speed, 'Speed', Icons.speed_rounded),
      _ToolSpec(EditorTool.effects, 'Effects', Icons.blur_on_rounded),
      _ToolSpec(EditorTool.beauty, 'Beauty', Icons.face_retouching_natural_rounded),
      _ToolSpec(EditorTool.merge, 'Merge', Icons.layers_rounded),
    ];

    return SizedBox(
      height: 86,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tool = tools[index];
          final selected = _activeTool == tool.tool;
          return GestureDetector(
            onTap: () {
              _selectTool(tool.tool);
              if (tool.tool == EditorTool.music) {
                _pickMusic();
              } else if (tool.tool == EditorTool.voice) {
                _recordVoice();
              } else if (tool.tool == EditorTool.merge) {
                _pickClips();
              }
            },
            child: Container(
              width: 74,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFF006E).withValues(alpha: 0.18) : Colors.white10,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? const Color(0xFFFF006E) : Colors.white12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tool.icon, color: selected ? const Color(0xFFFF006E) : Colors.white70),
                  const SizedBox(height: 6),
                  Text(tool.label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrimPanel() {
    final durationMs = _controller?.value.duration.inMilliseconds ?? 1000;
    final duration = math.max(1.0, durationMs / 1000.0);
    return _panel(
      'Trim',
      Column(
        children: [
          RangeSlider(
            values: RangeValues(_trimStart.clamp(0, duration), _trimEnd.clamp(0, duration)),
            min: 0,
            max: duration,
            activeColor: const Color(0xFFFF006E),
            labels: RangeLabels(_trimStart.toStringAsFixed(1), _trimEnd.toStringAsFixed(1)),
            onChanged: (values) => setState(() {
              _trimStart = values.start;
              _trimEnd = values.end;
            }),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Start ${_trimStart.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white70)),
              Text('End ${_trimEnd.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return _panel(
      'Filters',
      SizedBox(
        height: 90,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final selected = index == _filterIndex;
            return ChoiceChip(
              label: Text(_filters[index].name),
              selected: selected,
              selectedColor: const Color(0xFFFF006E),
              backgroundColor: Colors.white10,
              labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
              onSelected: (_) => _applyFilter(index),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpeedPanel() {
    return _panel(
      'Speed',
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _speeds.map((speed) {
          final selected = _speed == speed;
          return ChoiceChip(
            label: Text('${speed}x'),
            selected: selected,
            selectedColor: const Color(0xFFFF006E),
            backgroundColor: Colors.white10,
            labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
            onSelected: (_) => setState(() => _speed = speed),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEffectsPanel() {
    return _panel(
      'Effects',
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _effects.asMap().entries.map((entry) {
          final selected = _effectIndex == entry.key;
          return ChoiceChip(
            label: Text(entry.value),
            selected: selected,
            selectedColor: const Color(0xFFFF006E),
            backgroundColor: Colors.white10,
            labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
            onSelected: (_) => setState(() => _effectIndex = entry.key),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBeautyPanel() {
    return _panel(
      'Beauty',
      Column(
        children: [
          _slider('Brightness', _brightness, (value) => setState(() => _brightness = value), min: -0.2, max: 0.2),
          _slider('Contrast', _contrast, (value) => setState(() => _contrast = value), min: -0.2, max: 0.3),
          _slider('Saturation', _saturation, (value) => setState(() => _saturation = value), min: 0.0, max: 1.5),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Beauty mode', style: TextStyle(color: Colors.white70)),
            value: _beauty,
            onChanged: (value) => setState(() => _beauty = value),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPanel() {
    return _panel(
      'Text',
      Column(
        children: [
          TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type text overlay...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _addText,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF006E)),
                  child: const Text('Add Text'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickVoice(),
                  child: const Text('Add Voice', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickerPanel() {
    return _panel(
      'Logo Stickers',
      SizedBox(
        height: 180,
        child: GridView.count(
          crossAxisCount: 4,
          childAspectRatio: 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _logoStickerSizes.map((size) {
            return GestureDetector(
              onTap: () => _addSticker(size),
              child: Card(
                color: Colors.white10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Image.asset(
                          _brandLogoAsset,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${size.toInt()}px', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMergePanel() {
    return _panel(
      'Merge clips',
      Column(
        children: [
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _clipPaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Container(
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Center(
                    child: Text('Clip ${index + 1}', style: const TextStyle(color: Colors.white70)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _mergeClips,
              child: const Text('Merge selected clips', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextOverlay(_TextOverlay overlay) {
    return Positioned(
      left: overlay.position.dx,
      top: overlay.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            overlay.position = Offset(overlay.position.dx + details.delta.dx, overlay.position.dy + details.delta.dy);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            overlay.text,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerOverlay(_StickerOverlay overlay) {
    return Positioned(
      left: overlay.position.dx,
      top: overlay.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            overlay.position = Offset(overlay.position.dx + details.delta.dx, overlay.position.dy + details.delta.dy);
          });
        },
        child: SizedBox(
          width: overlay.size,
          height: overlay.size,
          child: Image.asset(
            _brandLogoAsset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }

  Widget _iconCircle(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _pillButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _panel(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged, {required double min, required double max}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
        Slider(value: value, min: min, max: max, activeColor: const Color(0xFFFF006E), onChanged: onChanged),
      ],
    );
  }
}

enum EditorTool { trim, music, voice, filters, text, stickers, speed, effects, beauty, merge }

class _ToolSpec {
  final EditorTool tool;
  final String label;
  final IconData icon;

  _ToolSpec(this.tool, this.label, this.icon);
}

class _FilterPreset {
  final String name;
  final double brightness;
  final double contrast;
  final double saturation;
  final bool beauty;

  const _FilterPreset(this.name, this.brightness, this.contrast, this.saturation, this.beauty);
}

class _TextOverlay {
  final String text;
  Offset position;
  final int startMs;
  final int endMs;

  _TextOverlay({required this.text, required this.position, required this.startMs, required this.endMs});

  Map<String, dynamic> toMap() => {
        'text': text,
        'position': {'dx': position.dx, 'dy': position.dy},
        'startMs': startMs,
        'endMs': endMs,
      };
}

class _StickerOverlay {
  Offset position;
  double size;

  _StickerOverlay({required this.position, required this.size});

  Map<String, dynamic> toMap() => {
        'asset': 'assets/branding/logo.png',
        'size': size,
        'position': {'dx': position.dx, 'dy': position.dy},
      };
}
