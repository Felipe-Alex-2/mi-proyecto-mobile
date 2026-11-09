import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../servicios/autenticacion_service.dart';

class OpcionesEntrega extends StatefulWidget {
  final String branchId;
  final bool enabled;
  final VoidCallback onChanged;
  final bool deliveryOnly;
  const OpcionesEntrega({
    super.key,
    required this.branchId,
    required this.enabled,
    required this.onChanged,
    this.deliveryOnly = false,
  });
  @override
  State<OpcionesEntrega> createState() => OpcionesEntregaState();
}

class OpcionesEntregaState extends State<OpcionesEntrega> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final maps = TextEditingController();
  bool delivery = false;
  @override
  void initState() {
    super.initState();
    delivery = widget.deliveryOnly;
    final user = context.read<AutenticacionService>().currentUser;
    name.text = user?.fullName ?? '';
    phone.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    for (final c in [name, phone, address, maps]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? validatedPayload() {
    if (!delivery) return null;
    if (!(form.currentState?.validate() ?? false)) {
      throw Exception('Completa los datos de entrega.');
    }
    return {
      'fulfillment': 'DELIVERY',
      'delivery_maps_url': maps.text.trim(),
      'delivery_recipient': name.text.trim(),
      'delivery_phone': phone.text.trim(),
      'delivery_address': address.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            widget.deliveryOnly
                ? 'Datos para el delivery'
                : '3. ¿Cómo recibes tu compra?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (!widget.deliveryOnly)
            DropdownButtonFormField<bool>(
              isExpanded: true,
              initialValue: delivery,
              decoration: const InputDecoration(labelText: 'Entrega'),
              items: const [
                DropdownMenuItem(
                  value: false,
                  child: Text('Pasar a recoger en sucursal'),
                ),
                DropdownMenuItem(
                  value: true,
                  child: Text('Delivery a mi ubicación'),
                ),
              ],
              onChanged: !widget.enabled
                  ? null
                  : (value) {
                      setState(() {
                        delivery = value ?? false;
                      });
                      widget.onChanged();
                    },
            ),
          if (delivery) ...[
            TextFormField(
              controller: name,
              enabled: widget.enabled,
              maxLength: 150,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Nombre de quien recibe',
              ),
              validator: (v) =>
                  (v?.trim().length ?? 0) < 2 ? 'Ingresa el nombre' : null,
            ),
            TextFormField(
              controller: phone,
              enabled: widget.enabled,
              maxLength: 50,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(labelText: 'Número de celular'),
              validator: (v) => (v?.trim().length ?? 0) < 7
                  ? 'Ingresa un celular de contacto'
                  : null,
            ),
            TextFormField(
              controller: address,
              enabled: widget.enabled,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Dirección y referencias',
                hintText: 'Calle, número, zona y referencia',
              ),
              validator: (v) =>
                  (v?.trim().length ?? 0) < 5 ? 'Completa la dirección' : null,
            ),
            TextFormField(
              controller: maps,
              enabled: widget.enabled,
              maxLength: 2048,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link de Google Maps',
                hintText: 'Pega el enlace de Compartir ubicación',
              ),
              validator: (v) => Uri.tryParse(v?.trim() ?? '')?.scheme != 'https'
                  ? 'Pega un enlace HTTPS de Google Maps'
                  : null,
              onChanged: (_) => widget.onChanged(),
            ),
            const Text(
              'Envía tus datos y espera la aceptación de la sucursal. Al aceptar apartarán tu pedido y te avisarán cuando salga la moto. El envío se calcula en web y se paga en efectivo al recibir.',
            ),
          ],
        ],
      ),
    );
  }
}
