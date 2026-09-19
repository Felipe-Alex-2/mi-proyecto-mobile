import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_item.dart';
import 'api_service.dart';

class NotificationService extends ChangeNotifier {
  final ApiService _apiService;
  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  Timer? _pollingTimer;

  NotificationService(this._apiService) {
    startPolling();
  }

  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void startPolling() {
    _pollingTimer?.cancel();
    // Poll every 12 seconds for real-time notification updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      loadNotifications(silent: true);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> loadNotifications({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final data = await _apiService.get('/notifications');
      if (data is List) {
        _notifications = data
            .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiService.patch('/notifications/$notificationId/read');
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        final current = _notifications[idx];
        _notifications[idx] = NotificationItem(
          id: current.id,
          userId: current.userId,
          reservationId: current.reservationId,
          title: current.title,
          message: current.message,
          notificationType: current.notificationType,
          isRead: true,
          createdAt: current.createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.patch('/notifications/read-all');
      _notifications = _notifications.map((n) {
        return NotificationItem(
          id: n.id,
          userId: n.userId,
          reservationId: n.reservationId,
          title: n.title,
          message: n.message,
          notificationType: n.notificationType,
          isRead: true,
          createdAt: n.createdAt,
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
