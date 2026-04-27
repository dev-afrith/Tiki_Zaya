import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static Future<void> checkAndShowDialog(BuildContext context, {bool silent = false}) async {
    try {
      final update = await ApiService.checkForUpdate();
      
      final bool available = update['updateAvailable'] == true;
      if (!available && silent) return;

      if (!context.mounted) return;

      final latestVersion = (update['latestVersion'] ?? '1.0.0').toString();
      final localVersion = (update['localVersion'] ?? '1.0.0').toString();
      final changelog = (update['changelog'] ?? '').toString();
      final apkUrl = (update['apkUrl'] ?? '').toString();

      showDialog(
        context: context,
        barrierDismissible: !available, // Force update if you want, but user said "Update Now" and "Cancel"
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF161616),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                available ? Icons.system_update_rounded : Icons.check_circle_outline_rounded,
                color: available ? const Color(0xFFFF006E) : Colors.greenAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                available ? 'Update Available' : 'Current Version',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Installed: $localVersion', style: const TextStyle(color: Colors.white54, fontSize: 13)),
              Text('Latest:    $latestVersion', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 16),
              if (available && changelog.isNotEmpty) ...[
                const Text('What\'s New:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        changelog,
                        style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ),
                ),
              ],
              if (available && apkUrl.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('Note: No update file found in this release. Please check back later.', 
                    style: TextStyle(color: Color(0xFFFF9E00), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              if (!available)
                const Text('You are using the latest version of Tiki Zaya.', style: TextStyle(color: Colors.white60, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(available ? 'Later' : 'Close', style: const TextStyle(color: Colors.white38)),
            ),
            if (available && apkUrl.isNotEmpty)
              ElevatedButton(
                onPressed: () async {
                  final uri = Uri.tryParse(apkUrl);
                  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF006E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Update Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      );
    } catch (_) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to check for updates')),
        );
      }
    }
  }
}
