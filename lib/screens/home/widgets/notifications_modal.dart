import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/notification_item.dart';
import '../../../services/notification_service.dart';

class NotificationsModal {
  static void show(
    BuildContext context,
    NotificationService notifService, {
    Function(int)? onNavigateToTab,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: notifService,
          builder: (ctx, _) {
            final items = notifService.notifications;
            final unread = notifService.unreadCount;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.75,
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_active_rounded, color: AppTheme.terracotta, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'Notificaciones',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.brown,
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$unread nueva${unread > 1 ? "s" : ""}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (unread > 0)
                        TextButton(
                          onPressed: () => notifService.markAllAsRead(),
                          child: const Text(
                            'Marcar leídas',
                            style: TextStyle(fontSize: 12, color: AppTheme.terracotta, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 8),

                  // Notification items list
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 54, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'No tienes notificaciones por el momento',
                              style: TextStyle(fontSize: 14, color: AppTheme.brownMedium, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final item = items[index];
                          return _NotificationCard(
                            item: item,
                            onTap: () {
                              if (!item.isRead) {
                                notifService.markAsRead(item.id);
                              }
                              if (item.reservationId != null) {
                                Navigator.pop(ctx);
                                if (onNavigateToTab != null) {
                                  onNavigateToTab(3); // Reservas tab
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${item.createdAt.day.toString().padLeft(2, '0')}/${item.createdAt.month.toString().padLeft(2, '0')} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.white : const Color(0xFFFAF5EF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isRead ? Colors.grey.shade200 : AppTheme.terracotta.withValues(alpha: 0.3),
            width: item.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade700,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                            color: AppTheme.brown,
                          ),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: item.isRead ? AppTheme.brownMedium : AppTheme.brown,
                      height: 1.3,
                    ),
                  ),
                  if (item.reservationId != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.terracotta,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Ver Reserva',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Toca para revisar estado',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.terracotta,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
