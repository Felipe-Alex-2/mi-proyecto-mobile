import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SeguimientoDelivery extends StatelessWidget {
  final Map<String, dynamic> delivery;
  const SeguimientoDelivery({super.key, required this.delivery});
  static const labels = {
    'AWAITING_PAYMENT': 'Pendiente de pago',
    'REQUESTED': 'Esperando aceptación de la sucursal',
    'ACCEPTED': 'Aceptado · preparando tu pedido',
    'REJECTED': 'Disponible para recoger en sucursal',
    'OUT_FOR_DELIVERY': 'Tu delivery salió · en camino',
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
          Text(
            'Envío pagado: USD ${(delivery['fee_usd'] as num).toStringAsFixed(2)} · ${delivery['distance_km']} km',
          ),
          if (delivery['status'] == 'REJECTED')
            const Text(
              'Tus prendas siguen pagadas para retirar. El costo del envío se devolvió a tu wallet.',
            ),
          if (delivery['status'] == 'REQUESTED' ||
              delivery['status'] == 'ACCEPTED')
            Text(
              'Llegada estimada: ${delivery['estimated_minutes_min']}–${delivery['estimated_minutes_max']} min desde la aceptación. Puede variar por tráfico.',
            ),
          if (delivery['departed_at'] != null)
            Text(
              'Salida: ${date(delivery['departed_at'])}\nLlegada aproximada: ${date(delivery['estimated_arrival_at'])}',
            ),
          if ('${delivery['courier'] ?? ''}'.isNotEmpty)
            Text('Repartidor: ${delivery['courier']}'),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(delivery['directions_url']),
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
