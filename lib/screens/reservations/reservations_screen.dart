import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReservationService>().loadReservations();
    });
  }

  void _confirmCancel(BuildContext context, Reservation r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('¿Cancelar reserva ${r.reservationCode}?'),
        content: const Text('Las prendas quedarán liberadas para otros clientes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<ReservationService>().cancelReservation(r.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reserva ${r.reservationCode} cancelada')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        foregroundColor: AppTheme.brown,
        title: const Row(
          children: [
            Icon(Icons.event_note_rounded, color: AppTheme.terracotta, size: 22),
            SizedBox(width: 8),
            Text(
              'Mis Reservas (CU13)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.brown),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.brownMedium),
            tooltip: 'Actualizar',
            onPressed: () => context.read<ReservationService>().loadReservations(),
          ),
        ],
      ),
      body: Consumer<ReservationService>(
        builder: (context, resService, _) {
          if (resService.isLoading && resService.reservations.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.terracotta));
          }

          final reservations = resService.reservations;
          if (reservations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_available_rounded, size: 72, color: AppTheme.brownMedium.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    const Text(
                      'No tienes reservas activas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.brown),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Puedes apartar prendas desde tu carrito para probártelas en cualquiera de nuestras sucursales físicas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.brownMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.terracotta,
            onRefresh: () => resService.loadReservations(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reservations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final r = reservations[index];
                return _ReservationCard(
                  reservation: r,
                  onCancel: () => _confirmCancel(context, r),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onCancel;

  const _ReservationCard({required this.reservation, required this.onCancel});

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange.shade800;
      case 'CONFIRMED':
        return Colors.blue.shade700;
      case 'COMPLETED':
        return Colors.green.shade700;
      case 'CANCELLED':
        return Colors.red.shade700;
      case 'EXPIRED':
        return Colors.grey.shade600;
      default:
        return AppTheme.brownMedium;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pendiente';
      case 'CONFIRMED':
        return 'Confirmada';
      case 'COMPLETED':
        return 'Completada';
      case 'CANCELLED':
        return 'Cancelada';
      case 'EXPIRED':
        return 'Vencida';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(reservation.status);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.creamLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Code & Status & Payment Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reservation.reservationCode,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.brown),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: reservation.isPaid ? Colors.green.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: reservation.isPaid ? Colors.green.shade300 : Colors.amber.shade300),
                    ),
                    child: Text(
                      reservation.isPaid ? '✓ Pagado (PayPal)' : '⏳ Pago en Tienda',
                      style: TextStyle(
                        color: reservation.isPaid ? Colors.green.shade800 : Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(reservation.status),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Pickup instruction notice banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: reservation.isPaid ? Colors.green.shade50 : AppTheme.creamLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: reservation.isPaid ? Colors.green.shade300 : AppTheme.brownMedium.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  reservation.isPaid ? Icons.check_circle_rounded : Icons.storefront_rounded,
                  size: 18,
                  color: reservation.isPaid ? Colors.green.shade700 : AppTheme.terracotta,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reservation.isPaid
                        ? 'Pase por la sucursal ${reservation.branchName ?? "seleccionada"} a recoger sus prendas ya pagadas.'
                        : 'Pase por la sucursal ${reservation.branchName ?? "seleccionada"} para probarse las prendas y pagar en tienda.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: reservation.isPaid ? FontWeight.bold : FontWeight.w500,
                      color: reservation.isPaid ? Colors.green.shade900 : AppTheme.brown,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Branch & Expiry info
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 16, color: AppTheme.terracotta),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${reservation.branchName ?? "Sucursal"} · ${reservation.branchAddress ?? ""}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.brown),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: AppTheme.brownMedium),
              const SizedBox(width: 6),
              Text(
                'Vence: ${_formatDate(reservation.expiresAt)}',
                style: const TextStyle(color: AppTheme.brownMedium, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.creamLight),
          const SizedBox(height: 10),

          // Items
          Text(
            'Prendas de la reserva (${reservation.totalItems}):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.brownMedium),
          ),
          const SizedBox(height: 6),
          ...reservation.items.map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text('${it.quantity}x ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.terracotta, fontSize: 13)),
                    Expanded(
                      child: Text(
                        '${it.productName ?? "Prenda"} (${it.sizeName ?? ""}/${it.colorName ?? ""})',
                        style: const TextStyle(fontSize: 13, color: AppTheme.brown),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Bs ${it.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.brownMedium),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reservation.isPaid ? 'Total Pagado:' : 'Total Estimado:',
                style: const TextStyle(fontSize: 13, color: AppTheme.brownMedium),
              ),
              Text(
                'Bs ${(reservation.totalAmount ?? reservation.totalEstimatedAmount).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: reservation.isPaid ? Colors.green.shade700 : AppTheme.terracotta,
                ),
              ),
            ],
          ),

          // Cancel button if PENDING or CONFIRMED and NOT paid
          if (reservation.isPaid) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              child: Text(
                'Pedido pagado vía PayPal · Presentar código en mostrador de sucursal',
                style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600),
              ),
            ),
          ] else if (reservation.isPending || reservation.isConfirmed) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                label: const Text('Cancelar Reserva', style: TextStyle(color: Colors.red, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

