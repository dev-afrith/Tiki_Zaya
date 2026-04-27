import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/main.dart'; // To get navigatorKey
import 'package:mobile/screens/notifications_screen.dart';
import 'package:mobile/screens/fullscreen_feed_screen.dart';
import 'package:mobile/screens/chat_screen.dart';
import 'package:mobile/screens/profile_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    final data = message.data;
    // Removed call handling logic
  } catch (_) {}
}

class NotificationService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.saveDeviceToken(token: token, platform: kIsWeb ? 'web' : 'mobile');
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((nextToken) {
        ApiService.saveDeviceToken(token: nextToken, platform: kIsWeb ? 'web' : 'mobile');
      });

      // Handle Foreground Notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final data = message.data;
        if (data['type'] == 'incoming_call') {
          // Calls disabled
          return;
        } else {
          _showInAppNotification(message);
        }
      });

      // Handle Background Clicks
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message.data);
      });

      // Removed CallKit Events listener

      // Process Terminated/Initial Clicks
      RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        Future.delayed(const Duration(milliseconds: 600), () {
          _handleNotificationTap(initialMessage.data);
        });
      }

    } catch (_) {
      _initialized = false;
    }
  }

  static void _showInAppNotification(RemoteMessage message) {
    if (navigatorKey.currentContext == null) return;
    final context = navigatorKey.currentContext!;
    
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text(body, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF161618),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        duration: const Duration(seconds: 4),
        dismissDirection: DismissDirection.horizontal,
        action: SnackBarAction(
          label: 'View',
          textColor: const Color(0xFFFF006E),
          onPressed: () {
            _handleNotificationTap(message.data);
          },
        ),
      ),
    );
  }

  static Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    if (navigatorKey.currentContext == null) return;
    final context = navigatorKey.currentContext!;
    
    final type = data['type']?.toString();
    final entityId = data['entityId']?.toString(); // messageId
    final actorUserId = data['actorUserId']?.toString();
    final actorUsername = data['actorUsername']?.toString() ?? 'User';
    final actorProfilePic = data['actorProfilePic']?.toString() ?? '';
    
    if (type == 'message' || type == 'streak_warning' || type == 'streak_increment') {
      if (actorUserId != null && actorUserId.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatThreadScreen(
          peerUserId: actorUserId,
          peerUsername: actorUsername,
          peerProfilePic: actorProfilePic,
        )));
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
    } else if (type == 'follow') {
      if (entityId != null && entityId.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: entityId)));
      }
    } else if (type == 'like' || type == 'comment' || type == 'repost') {
      if (entityId != null && entityId.isNotEmpty) {
        try {
          final videoMap = await ApiService.getVideoById(entityId);
          if (videoMap.isNotEmpty && !videoMap.containsKey('error')) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenFeedScreen(
              videos: [videoMap],
              initialIndex: 0,
            )));
            return;
          }
        } catch (_) {}
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    }
  }
}
