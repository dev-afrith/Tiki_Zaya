import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile/services/api_service.dart';
import 'package:mobile/screens/video_editor_screen.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _captionController = TextEditingController();
  XFile? _selectedFile;
  File? _thumbnailFile;
  bool _isUploading = false;
  bool _isCompressing = false;
  double _processingProgress = 0;
  String? _message;
  final List<Map<String, dynamic>> _drafts = [];
  Duration? _selectedDuration;
  bool _isOverDurationLimit = false;

  Map<String, dynamic>? _editingMetadata;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final draftsStr = prefs.getString('video_drafts');
    if (draftsStr != null) {
      setState(() {
        _drafts.addAll(List<Map<String, dynamic>>.from(jsonDecode(draftsStr)));
      });
    }
  }

  Future<void> _saveDraft() async {
    if (_selectedFile == null) return;
    
    final draft = {
      'path': _selectedFile!.path,
      'caption': _captionController.text,
      'timestamp': DateTime.now().toIso8601String(),
      'editingMetadata': _editingMetadata,
    };

    final prefs = await SharedPreferences.getInstance();
    _drafts.add(draft);
    await prefs.setString('video_drafts', jsonEncode(_drafts));
    
    setState(() {
      _message = '📝 Saved to drafts!';
      _selectedFile = null;
      _captionController.clear();
      _editingMetadata = null;
    });
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 90),
    );
    
    if (video != null) {
      setState(() {
        _selectedFile = video;
        _message = null;
        _processingProgress = 0;
        _editingMetadata = null;
        _selectedDuration = null;
        _isOverDurationLimit = false;
      });
      _generateThumbnail();
      await _loadDurationPreview();
    }
  }

  Future<void> _loadDurationPreview() async {
    if (_selectedFile == null || kIsWeb) return;

    final controller = VideoPlayerController.file(File(_selectedFile!.path));
    try {
      await controller.initialize();
      final duration = controller.value.duration;
      if (!mounted) return;
      setState(() {
        _selectedDuration = duration;
        _isOverDurationLimit = duration.inSeconds > 90;
        _message = _isOverDurationLimit ? 'Video must be 90 seconds or less' : 'Video ready to post';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Could not read video duration';
        });
      }
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _generateThumbnail() async {
    if (_selectedFile == null || kIsWeb) return;
    try {
      final thumbnail = await VideoCompress.getFileThumbnail(_selectedFile!.path);
      setState(() { _thumbnailFile = thumbnail; });
    } catch (e) {
      debugPrint('Thumbnail error: $e');
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedFile == null) return;
    if (_selectedDuration != null && _selectedDuration!.inSeconds > 90) {
      setState(() {
        _message = 'Video must be 90 seconds or less';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _isCompressing = !kIsWeb; // No native compression on Web
      _message = null;
      _processingProgress = 0;
    });

    try {
      XFile fileToUpload = _selectedFile!;
      
      // 1. COMPRESSION (Mobile only)
      if (!kIsWeb) {
        final MediaInfo? info = await VideoCompress.compressVideo(
          _selectedFile!.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );
        if (info != null && info.file != null) {
          fileToUpload = XFile(info.file!.path);
        }
      }

      setState(() {
        _isCompressing = false;
        _processingProgress = 0;
      });

      // 2. UPLOAD
      final result = await ApiService.uploadVideoWithProgress(
        videoFile: fileToUpload,
        caption: _captionController.text.trim(),
        videoDurationSeconds: _selectedDuration?.inSeconds ?? 0,
        editingMetadata: _editingMetadata,
        onProgress: (progress) {
          setState(() { _processingProgress = progress; });
        },
      );

      if (result.containsKey('video') || result.containsKey('message')) {
        setState(() {
          _message = '✅ Video uploaded successfully!';
          _selectedFile = null;
          _thumbnailFile = null;
          _selectedDuration = null;
          _isOverDurationLimit = false;
          _captionController.clear();
          _editingMetadata = null;
        });
      } else {
        final errorMsg = result['error']?.toString() ?? result['data']?['message']?.toString() ?? 'Upload failed';
        setState(() {
          _message = '❌ $errorMsg';
        });
      }
    } catch (e) {
      setState(() {
        _message = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
        _isCompressing = false;
      });
      if (!kIsWeb) {
        VideoCompress.deleteAllCache();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('New Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_selectedFile != null && !_isUploading)
            TextButton(
              onPressed: _saveDraft,
              child: const Text('Save Draft', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            
            // Video Preview / Picker
            GestureDetector(
              onTap: () => _showPickerOptions(),
              child: Container(
                width: double.infinity,
                height: 380,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  image: !kIsWeb && _thumbnailFile != null
                    ? DecorationImage(image: FileImage(_thumbnailFile!), fit: BoxFit.cover, opacity: 0.6)
                    : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_thumbnailFile == null) ...[
                      const Icon(Icons.video_call_outlined, size: 64, color: Color(0xFFFF006E)),
                      const SizedBox(height: 12),
                      const Text('Select or Record Video', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ] else ...[
                      const Icon(Icons.play_circle_fill, size: 64, color: Colors.white70),
                      const SizedBox(height: 12),
                      const Text('Video Ready', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
            ),

            if (_selectedDuration != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _isOverDurationLimit ? Colors.redAccent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _isOverDurationLimit ? Colors.redAccent.withValues(alpha: 0.35) : Colors.white12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isOverDurationLimit ? Icons.error_outline : Icons.timelapse,
                      color: _isOverDurationLimit ? Colors.redAccent : const Color(0xFFFF006E),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Duration preview: ${_formatDuration(_selectedDuration!)}',
                        style: TextStyle(
                          color: _isOverDurationLimit ? Colors.redAccent : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _isOverDurationLimit ? 'Trim required' : 'Ready',
                      style: TextStyle(
                        color: _isOverDurationLimit ? Colors.redAccent : Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Edit Video Button
            if (_selectedFile != null && !_isUploading)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (kIsWeb) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Video editing is available on mobile only. Upload your video directly!'),
                            backgroundColor: Color(0xFFFF006E),
                          ),
                        );
                        return;
                      }
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoEditorScreen(videoSource: _selectedFile!.path),
                        ),
                      );
                      if (result != null && result is Map<String, dynamic>) {
                        final exportPath = result['exportPath']?.toString();
                        if (exportPath != null && exportPath.isNotEmpty) {
                          setState(() {
                            _selectedFile = XFile(exportPath);
                            _message = 'Trimmed video loaded';
                          });
                          await _generateThumbnail();
                          await _loadDurationPreview();
                        }
                        setState(() { _editingMetadata = result; });
                      }
                    },
                    icon: const Icon(Icons.auto_fix_high, color: Color(0xFFFF006E)),
                    label: Text(
                      _isOverDurationLimit ? 'Trim Video' : 'Edit Video',
                      style: const TextStyle(color: Color(0xFFFF006E), fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF006E)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Caption Textfield
            TextField(
              controller: _captionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe your video... #hashtags @mentions',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 24),

            // Progress/Status
            if (_isUploading) ...[
              LinearProgressIndicator(
                value: _isCompressing ? null : _processingProgress,
                backgroundColor: Colors.white10,
                color: const Color(0xFFFF006E),
              ),
              const SizedBox(height: 12),
              Text(
                _isCompressing ? 'Compressing video...' : 'Uploading: ${(_processingProgress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70),
              ),
            ],

            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: TextStyle(color: _message!.contains('❌') ? Colors.redAccent : Colors.greenAccent)),
            ],

            const SizedBox(height: 32),

            // Action Button — High Visibility
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: (_isUploading || _selectedFile == null || _isOverDurationLimit)
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFFF006E), Color(0xFFB86EF5)],
                        ),
                  color: (_isUploading || _selectedFile == null || _isOverDurationLimit)
                      ? Colors.white.withValues(alpha: 0.08)
                      : null,
                  boxShadow: (_isUploading || _selectedFile == null || _isOverDurationLimit)
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFFFF006E).withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: ElevatedButton(
                  onPressed: (_isUploading || _selectedFile == null || _isOverDurationLimit) ? null : _handleUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _isUploading ? 'PLEASE WAIT...' : 'SHARE VIDEO',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: (_isUploading || _selectedFile == null || _isOverDurationLimit)
                          ? Colors.white38
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Record with Camera', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _pickVideo(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Select from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _pickVideo(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
