import 'package:flutter/material.dart';

import '../../../configuracion/tema.dart';
import '../../../modelos/reserva.dart';

class ComprobantePagoDialog extends StatelessWidget {
  final Reserva reservation;
  final VoidCallback? onGoToReservations;

  const ComprobantePagoDialog({
    super.key,
    required this.reservation,
    this.onGoToReservations,
  });

  static Future<void> show(
    BuildContext context,
    Reserva reservation, {
    VoidCallback? onGoToReservations,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ComprobantePagoDialog(
        reservation: reservation,
        onGoToReservations: onGoToReservations,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paidDate = (reservation.receiptDate ?? reservation.createdAt)
        .toLocal();
    final deadline = reservation.changeDeadline?.toLocal();
    final dateStr =
        '${paidDate.day.toString().padLeft(2, '0')}/${paidDate.month.toString().padLeft(2, '0')}/${paidDate.year} ${paidDate.hour.toString().padLeft(2, '0')}:${paidDate.minute.toString().padLeft(2, '0')}';
    final total = reservation.totalAmount ?? reservation.totalEstimatedAmount;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Receipt Top Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1A365D), // Deep Navy
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.checkroom_rounded,
                            color: Colors.amber,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'FASHION STORE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: reservation.isPaid
                          ? Colors.green.shade600
                          : Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          reservation.isPaid
                              ? 'PAGO CONFIRMADO · ${reservation.paymentMethod}'
                              : 'RESERVA · PAGO PENDIENTE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'RECIBO / FACTURA DE VENTA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'N° REC-${reservation.reservationCode}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Receipt Body (Scrollable if many items)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reservation.isPaid) ...[
                      const Text(
                        'CÓDIGO PARA CAMBIOS / DEVOLUCIONES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: TemaApp.brown,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        reservation.changeCode,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: TemaApp.terracotta,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Presenta este código en caja. Plazo: 48 horas desde la emisión del recibo.',
                        style: TextStyle(
                          fontSize: 12,
                          color: TemaApp.brownMedium,
                        ),
                      ),
                      if (deadline != null)
                        Text(
                          'Límite: ${deadline.day.toString().padLeft(2, '0')}/${deadline.month.toString().padLeft(2, '0')}/${deadline.year} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: TemaApp.brownMedium,
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                    // Meta Info Table
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TemaApp.creamLight.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TemaApp.creamLight),
                      ),
                      child: Column(
                        children: [
                          _buildMetaRow('Fecha:', dateStr),
                          const Divider(height: 12, color: Colors.black12),
                          _buildMetaRow(
                            'Cliente:',
                            reservation.customerName ?? 'Cliente Registrado',
                          ),
                          const Divider(height: 12, color: Colors.black12),
                          _buildMetaRow(
                            'Sucursal Retiro:',
                            reservation.branchName ?? 'Sucursal',
                          ),
                          if (reservation.branchAddress != null) ...[
                            const SizedBox(height: 2),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                reservation.branchAddress!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: TemaApp.brownMedium,
                                ),
                              ),
                            ),
                          ],
                          const Divider(height: 12, color: Colors.black12),
                          _buildMetaRow(
                            'Método de Pago:',
                            reservation.paymentMethod == 'WALLET'
                                ? 'Wallet'
                                : reservation.isCash
                                ? 'Efectivo'
                                : 'PayPal',
                            valueColor: const Color(0xFF0070BA),
                          ),
                          if (reservation.paypalOrderId != null) ...[
                            const SizedBox(height: 4),
                            _buildMetaRow(
                              'ID Orden PayPal:',
                              reservation.paypalOrderId!,
                              isCode: true,
                            ),
                          ],
                          if (reservation.paypalCaptureId != null) ...[
                            const SizedBox(height: 4),
                            _buildMetaRow(
                              'ID Captura:',
                              reservation.paypalCaptureId!,
                              isCode: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Items Header
                    const Text(
                      'DETALLE DE PRENDAS COMPRADAS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: TemaApp.brown,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Items List
                    ...reservation.items.map((item) {
                      final itemSubtotal =
                          (reservation.wholesaleDiscountPercent > 0
                              ? (item.originalPrice ?? item.price)
                              : item.price) *
                          item.quantity;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: TemaApp.terracotta.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${item.quantity}x',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: TemaApp.terracotta,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName ?? 'Prenda de Colección',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: TemaApp.brown,
                                    ),
                                  ),
                                  Text(
                                    '${item.sizeName ?? ""} · ${item.colorName ?? ""}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: TemaApp.brownMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$${itemSubtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: TemaApp.brown,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.black12,
                    ),
                    const SizedBox(height: 10),

                    if (reservation.wholesaleDiscountPercent > 0) ...[
                      Text(
                        'Venta por mayor −${reservation.wholesaleDiscountPercent}%: −${reservation.wholesaleDiscountAmount.toStringAsFixed(2)} ${reservation.currency}',
                        style: const TextStyle(
                          color: TemaApp.terracotta,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (reservation.couponDiscountAmount > 0) ...[
                      Text(
                        'Cupón de puntos −${reservation.couponDiscountPercent}%: −${reservation.couponDiscountAmount.toStringAsFixed(2)} ${reservation.currency}',
                        style: const TextStyle(
                          color: TemaApp.terracotta,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (reservation.deliveryFee > 0)
                      Text(
                        'Envío: USD ${reservation.deliveryFee.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    // Financial Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal:',
                          style: TextStyle(
                            color: TemaApp.brownMedium,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${(reservation.subtotalBeforeWholesale ?? total).toStringAsFixed(2)} ${reservation.currency}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Impuestos (0%):',
                          style: TextStyle(
                            color: TemaApp.brownMedium,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '0.00 ${reservation.currency}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL PAGADO:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1A365D),
                            ),
                          ),
                          Text(
                            '${total.toStringAsFixed(2)} ${reservation.currency}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Pickup Notice
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A365D).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF1A365D).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            color: Color(0xFF1A365D),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reservation.delivery != null &&
                                      reservation.delivery!['status'] !=
                                          'REJECTED'
                                  ? 'Prendas y envío pagados. Sigue el estado del delivery en Mis Reservas. Código ${reservation.reservationCode}.'
                                  : 'Pase por la sucursal ${reservation.branchName ?? "seleccionada"} y presente su código ${reservation.reservationCode} para retirar sus prendas inmediatamente.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A365D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (onGoToReservations != null) {
                          onGoToReservations!();
                        }
                      },
                      icon: const Icon(Icons.event_note_rounded, size: 18),
                      label: const Text('Ver Mis Reservas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TemaApp.terracotta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(
    String label,
    String value, {
    Color? valueColor,
    bool isCode = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: TemaApp.brownMedium,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isCode ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: valueColor ?? TemaApp.brown,
              fontFamily: isCode ? 'monospace' : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
