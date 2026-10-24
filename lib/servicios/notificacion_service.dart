import 'sesion_notifier.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../modelos/notificacion_item.dart';
import 'api_service.dart';

class NotificacionService extends SesionNotifier {
  final ApiService _apiService;
  List<NotificacionItem> _notifications = [];
  bool _isLoading = false;
  Timer? _pollingTimer;

  NotificacionService(this._apiService);

  Future<void>? _pendingLoad;
  String? _lastPayload;
  int _generation = 0;
  bool _disposed = false;

  List<NotificacionItem> get notifications => _notifications;
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
    _generation++;
    _pendingLoad = null;
    _isLoading = false;
  }

  void clearSession() {
    stopPolling();
    _notifications = [];
    _lastPayload = null;
  }

  Future<void> loadNotifications({bool silent = false}) {
    if (_disposed) return Future.value();
    if (_pendingLoad != null) return _pendingLoad!;
    final generation = _generation;
    return _pendingLoad =
        _loadNotifications(silent: silent, generation: generation).whenComplete(
          () {
            if (generation == _generation) _pendingLoad = null;
          },
        );
  }

  Future<void> _loadNotifications({
    required bool silent,
    required int generation,
  }) async {
    bool changed = false;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final data = await _apiService.get('/notifications');
      if (_disposed || generation != _generation) return;
      if (data is List && jsonEncode(data) != _lastPayload) {
        _lastPayload = jsonEncode(data);
        changed = true;
        _notifications = data
            .map(
              (item) => NotificacionItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      if (!_disposed && generation == _generation) {
        if (!silent) _isLoading = false;
        if (!silent || changed) notifyListeners();
      }
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiService.patch('/notifications/$notificationId/read');
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        final current = _notifications[idx];
        _notifications[idx] = NotificacionItem(
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
        return NotificacionItem(
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
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
