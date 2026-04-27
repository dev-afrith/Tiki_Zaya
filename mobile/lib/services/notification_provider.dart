import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class NotificationProvider extends ChangeNotifier {
  int _unreadNotifications = 0;
  int _unreadMessages = 0;

  int get unreadNotifications => _unreadNotifications;
  int get unreadMessages => _unreadMessages;

  io.Socket? _socket;

  /// Fetch initial counts from the backend
  Future<void> fetchCounts() async {
    try {
      final notificationsCount = await ApiService.getUnreadNotificationCount();
      final messagesCount = await ApiService.getUnreadMessagesCount();
      
      _unreadNotifications = notificationsCount;
      _unreadMessages = (messagesCount['unreadTotal'] is num) ? (messagesCount['unreadTotal'] as num).toInt() : 0;
      notifyListeners();

      _initSocket();
    } catch (e) {
      debugPrint('Error fetching badge counts: $e');
    }
  }

  Future<void> _initSocket() async {
    if (_socket != null && _socket!.connected) return;
    
    final token = await ApiService.getToken();
    if (token == null) return;

    _socket = io.io(
      ApiService.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket?.onConnect((_) {
      debugPrint('NotificationProvider Socket connected');
    });

    _socket?.on('new_notification', (data) {
      if (data != null && data['unreadCount'] != null) {
        _unreadNotifications = (data['unreadCount'] as num).toInt();
        notifyListeners();
      }
    });

    _socket?.on('new_message', (data) {
      // Refresh message count when a new message comes in globally
      fetchCounts();
    });

    _socket?.connect();
  }

  /// Update the notification count manually (e.g. from Socket.io)
  void setUnreadNotifications(int count) {
    if (_unreadNotifications != count) {
      _unreadNotifications = count;
      notifyListeners();
    }
  }

  /// Update the message count manually (e.g. from Socket.io)
  void setUnreadMessages(int count) {
    if (_unreadMessages != count) {
      _unreadMessages = count;
      notifyListeners();
    }
  }

  /// Optimistically decrement notification count
  void decrementUnreadNotifications() {
    if (_unreadNotifications > 0) {
      _unreadNotifications--;
      notifyListeners();
    }
  }

  /// Clear all notifications (when marked all read)
  void clearUnreadNotifications() {
    if (_unreadNotifications > 0) {
      _unreadNotifications = 0;
      notifyListeners();
    }
  }
}
