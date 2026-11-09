import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SeguimientoDelivery extends StatelessWidget {
  final Map<String, dynamic> delivery;
  const SeguimientoDelivery({super.key, required this.delivery});
  static const labels = {
    'AWAITING_PAYMENT': 'Pendiente de pago',
    'REQUESTED': 'Esperando aceptación de la sucursal',
    'ACCEPTED': 'Pedido aceptado y apartado',
    'REJECTED': 'Disponible para recoger en sucursal',
    'OUT_FOR_DELIVERY': 'La moto salió con tu pedido',
    'DELIVERED': 'Entregado',
    'FAILED': 'No se pudo entregar',
  };
  String date(dynamic raw) {
    final value = DateTime.tryParse('$raw')?.toLocal();
    return value == null
        ? ''
        : '${value.day}/${value.month} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labels[delivery['status']] ?? '${delivery['status']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('${delivery['recipient']} · ${delivery['phone']}'),
          Text('${delivery['address']}'),
          if (delivery['fee_usd'] == null)
            const Text(
              'El costo del envío se calculará en la sucursal al confirmar la salida de la moto.',
            )
          else
            Text(
              delivery['fee_collection'] == 'CASH_ON_DELIVERY'
                  ? 'Envío: USD ${(delivery['fee_usd'] as num).toStringAsFixed(2)} · ${delivery['shipping_payment_status'] == 'PAID' ? 'Cobrado en efectivo' : 'Pagar en efectivo al recibir'}'
                  : 'Envío pagado: USD ${(delivery['fee_usd'] as num).toStringAsFixed(2)}',
            ),
          if (delivery['status'] == 'REJECTED')
            Text(
              delivery['fee_collection'] == 'CASH_ON_DELIVERY'
                  ? 'Tus prendas siguen pagadas para retirar en sucursal.'
                  : 'Tus prendas siguen pagadas para retirar. El costo del envío se devolvió a tu wallet.',
            ),
          if (delivery['estimated_minutes_min'] != null &&
              (delivery['status'] == 'REQUESTED' ||
                  delivery['status'] == 'ACCEPTED'))
            Text(
              'Llegada estimada: ${delivery['estimated_minutes_min']}–${delivery['estimated_minutes_max']} min desde la aceptación. Puede variar por tráfico.',
            ),
          if (delivery['departed_at'] != null)
            Text(
              'Salida: ${date(delivery['departed_at'])}\n${delivery['estimated_arrival_at'] != null ? 'Llegada aproximada: ${date(delivery['estimated_arrival_at'])}' : 'Tiempo de llegada pendiente de confirmar'}',
            ),
          if ('${delivery['courier'] ?? ''}'.isNotEmpty)
            Text('Repartidor: ${delivery['courier']}'),
          if (delivery['directions_url'] != null ||
              delivery['destination_maps_url'] != null)
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(
                  delivery['directions_url'] ??
                      delivery['destination_maps_url'],
                ),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Ver ruta de entrega'),
            ),
          ExpansionTile(
            title: const Text('Seguimiento'),
            children: [
              for (final event in (delivery['history'] as List? ?? []))
                ListTile(
                  title: Text(labels[event['status']] ?? '${event['status']}'),
                  subtitle: Text(
                    '${date(event['at'])}\n${event['note'] ?? ''}',
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
