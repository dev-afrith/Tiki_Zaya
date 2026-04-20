import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';

class ArchivedContentsScreen extends StatefulWidget {
  const ArchivedContentsScreen({super.key});

  @override
  State<ArchivedContentsScreen> createState() => _ArchivedContentsScreenState();
}

class _ArchivedContentsScreenState extends State<ArchivedContentsScreen> {
  bool _isLoading = true;
  List<dynamic> _videos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getArchivedVideos();
      if (!mounted) return;
      setState(() {
        _videos = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreVideo(String id) async {
    try {
      await ApiService.unarchiveVideo(id);
      if (!mounted) return;
      setState(() {
        _videos.removeWhere((v) => (v['_id'] ?? '').toString() == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reel restored from archive')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to restore reel')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Archived Contents', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF006E)))
          : _videos.isEmpty
              ? const Center(
                  child: Text('No archived reels', style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    final id = (video['_id'] ?? '').toString();
                    final caption = (video['caption'] ?? '').toString();
                    final thumbnail = (video['thumbnailUrl'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 76,
                              height: 76,
                              color: Colors.white10,
                              child: thumbnail.isNotEmpty
                                  ? Image.network(
                                      thumbnail,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.play_arrow, color: Colors.white54),
                                    )
                                  : const Icon(Icons.play_arrow, color: Colors.white54),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              caption.isNotEmpty ? caption : 'Untitled reel',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: id.isEmpty ? null : () => _restoreVideo(id),
                            child: const Text('Restore', style: TextStyle(color: Color(0xFFFF006E))),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
