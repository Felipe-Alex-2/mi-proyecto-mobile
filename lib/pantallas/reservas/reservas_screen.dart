import 'package:url_launcher/url_launcher.dart';

import '../../servicios/api_service.dart';
import '../../widgets/error_carga.dart';
import '../../widgets/seguimiento_delivery.dart';
import '../../widgets/mensaje_guardado.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../configuracion/tema.dart';
import '../../modelos/reserva.dart';
import '../../servicios/reserva_service.dart';
import '../../servicios/notificacion_service.dart';
import '../inicio/widgets/notificaciones_modal.dart';
import 'widgets/comprobante_pago_sheet.dart';

class ReservasScreen extends StatefulWidget {
  const ReservasScreen({super.key});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = context.read<ReservaService>();
      if (!service.hasLoaded) service.loadReservations();
    });
  }

  void _confirmCancel(BuildContext context, Reserva r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TemaApp.surface,
        title: Text('¿Cancelar reserva ${r.reservationCode}?'),
        content: const Text(
          'Las prendas quedarán liberadas para otros clientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sí, Cancelar',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final updated = await context.read<ReservaService>().cancelReservation(
          r.id,
        );
        if (!context.mounted) return;
        showSaveFeedback(
          context,
          pending: updated.syncPending,
          confirmed: 'Reserva ${r.reservationCode} cancelada.',
          queued: 'Cancelación guardada en el dispositivo. Pendiente de sincronizar.',
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.cream,
      appBar: AppBar(
        backgroundColor: TemaApp.surface,
        elevation: 0,
        foregroundColor: TemaApp.brown,
        title: Text(
          'Mis reservas',
          style: TemaApp.editorial.copyWith(fontSize: 32),
        ),
        actions: [
          Consumer<NotificacionService>(
            builder: (context, notifService, _) {
              final unread = notifService.unreadCount;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(
                    '$unread',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: Colors.red,
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: TemaApp.brown,
                    size: 24,
                  ),
                ),
                tooltip: 'Notificaciones ($unread)',
                onPressed: () =>
                    NotificacionesModal.show(context, notifService),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: TemaApp.brownMedium),
            tooltip: 'Actualizar',
            onPressed: () => context.read<ReservaService>().loadReservations(),
          ),
        ],
      ),
      body: Consumer<ReservaService>(
        builder: (context, resService, _) {
          if (resService.isLoading && resService.reservations.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: TemaApp.terracotta),
            );
          }

          if (resService.errorMessage != null) {
            return ErrorCarga(
              message: resService.errorMessage!,
              onRetry: () => resService.loadReservations(),
            );
          }

          final reservations = resService.reservations;
          if (reservations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 72,
                      color: TemaApp.brownMedium.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No tienes reservas activas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: TemaApp.brown,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Puedes apartar prendas desde tu carrito para probártelas en cualquiera de nuestras sucursales físicas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TemaApp.brownMedium,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: TemaApp.terracotta,
            onRefresh: () => resService.loadReservations(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reservations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final r = reservations[index];
                return _ReservaCard(
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

class _ReservaCard extends StatelessWidget {
  final Reserva reservation;
  final VoidCallback onCancel;

  const _ReservaCard({required this.reservation, required this.onCancel});

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
        return TemaApp.brownMedium;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'SYNC_PENDING':
        return 'Pendiente de envío';
      case 'SYNC_FAILED':
        return 'Revisar sincronización';
      case 'CANCEL_PENDING':
        return 'Cancelación pendiente';
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
        color: TemaApp.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TemaApp.creamLight),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: TemaApp.brown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: reservation.isPaid
                          ? Colors.green.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: reservation.isPaid
                            ? Colors.green.shade300
                            : Colors.amber.shade300,
                      ),
                    ),
                    child: Text(
                      reservation.isPaid
                          ? '✓ Pagado (${reservation.paymentMethod})'
                          : reservation.isPaypal
                          ? '⏳ PayPal pendiente'
                          : '⏳ Pago en Tienda',
                      style: TextStyle(
                        color: reservation.isPaid
                            ? Colors.green.shade800
                            : Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(reservation.status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
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
              color: reservation.isPaid
                  ? Colors.green.shade50
                  : TemaApp.creamLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: reservation.isPaid
                    ? Colors.green.shade300
                    : TemaApp.brownMedium.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  reservation.isPaid
                      ? Icons.check_circle_rounded
                      : Icons.storefront_rounded,
                  size: 18,
                  color: reservation.isPaid
                      ? Colors.green.shade700
                      : TemaApp.terracotta,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reservation.isLocal
                        ? 'Guardada en el dispositivo. Espera la confirmación de disponibilidad antes de acudir a la sucursal.'
                        : reservation.delivery != null &&
                              reservation.delivery!['status'] != 'REJECTED'
                        ? 'Consulta el estado de tu delivery en el seguimiento de esta reserva.'
                        : reservation.isPaid
                        ? 'Pase por la sucursal ${reservation.branchName ?? "seleccionada"} a recoger sus prendas ya pagadas.'
                        : 'Pase por la sucursal ${reservation.branchName ?? "seleccionada"} para probarse las prendas y pagar en tienda.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: reservation.isPaid
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: reservation.isPaid
                          ? Colors.green.shade900
                          : TemaApp.brown,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (reservation.delivery != null)
            SeguimientoDelivery(delivery: reservation.delivery!),
          // Branch & Expiry info
          Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                size: 16,
                color: TemaApp.terracotta,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${reservation.companyName ?? ""} · ${reservation.branchName ?? "Sucursal"} · ${reservation.branchAddress ?? ""}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: TemaApp.brown,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: TemaApp.brownMedium,
              ),
              const SizedBox(width: 6),
              Text(
                reservation.isLocal
                    ? 'Disponibilidad por confirmar'
                    : 'Vence: ${_formatDate(reservation.expiresAt)}',
                style: const TextStyle(
                  color: TemaApp.brownMedium,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: TemaApp.creamLight),
          const SizedBox(height: 10),

          // Items
          Text(
            'Prendas de la reserva (${reservation.totalItems}):',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: TemaApp.brownMedium,
            ),
          ),
          const SizedBox(height: 6),
          ...reservation.items.map(
            (it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    '${it.quantity}x ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: TemaApp.terracotta,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${it.productName ?? "Prenda"} (${it.sizeName ?? ""}/${it.colorName ?? ""})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: TemaApp.brown,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '\$ ${it.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: TemaApp.brownMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reservation.isPaid ? 'Total Pagado:' : 'Total Estimado:',
                style: const TextStyle(
                  fontSize: 13,
                  color: TemaApp.brownMedium,
                ),
              ),
              Text(
                '\$ ${(reservation.totalAmount ?? reservation.totalEstimatedAmount).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: reservation.isPaid
                      ? Colors.green.shade700
                      : TemaApp.terracotta,
                ),
              ),
            ],
          ),

          // Receipt button for paid reservations
          if (reservation.isPaid) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    ComprobantePagoDialog.show(context, reservation),
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text(
                  'Ver Recibo de Pago (Factura)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A365D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ] else if (reservation.isPending || reservation.isConfirmed) ...[
            if (reservation.isPaypal &&
                !reservation.isPaid &&
                !reservation.isLocal)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text('Autorizar PayPal'),
                    onPressed: () async {
                      try {
                        final result = await context.read<ApiService>().post(
                          '/reservations/${reservation.id}/paypal-order',
                        );
                        await launchUrl(
                          Uri.parse(result['approval_url']),
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        final api = context.read<ReservaService>();
                        final order = reservation.paypalOrderId;
                        if (order == null) {
                          await api.loadReservations();
                          return;
                        }
                        await api.capturePayPalReservationOrder(order);
                        await api.loadReservations();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
                    child: const Text('Verificar pago'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(
                  Icons.cancel_outlined,
                  size: 16,
                  color: Colors.red,
                ),
                label: const Text(
                  'Cancelar Reserva',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
