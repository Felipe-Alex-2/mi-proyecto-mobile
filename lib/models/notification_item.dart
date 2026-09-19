class NotificationItem {
  final String id;
  final String userId;
  final String? reservationId;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    this.reservationId,
    required this.title,
    required this.message,
    this.notificationType = 'RESERVATION_ACCEPTED',
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      reservationId: json['reservation_id'],
      title: json['title'] ?? 'Notificación',
      message: json['message'] ?? '',
      notificationType: json['notification_type'] ?? 'RESERVATION_ACCEPTED',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
