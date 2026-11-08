import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servicios/api_service.dart';
import '../servicios/autenticacion_service.dart';

class OpcionesEntrega extends StatefulWidget {
  final String branchId;
  final bool enabled;
  final VoidCallback onChanged;
  const OpcionesEntrega({
    super.key,
    required this.branchId,
    required this.enabled,
    required this.onChanged,
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
  bool delivery = false, loading = false;
  String? error;
  Map<String, dynamic>? quote;
  @override
  void initState() {
    super.initState();
    final user = context.read<AutenticacionService>().currentUser;
    name.text = user?.fullName ?? '';
    phone.text = user?.phone ?? '';
  }

  @override
  void didUpdateWidget(covariant OpcionesEntrega oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      quote = null;
      error = null;
    }
  }

  @override
  void dispose() {
    for (final c in [name, phone, address, maps]) {
      c.dispose();
    }
    super.dispose();
  }

  void clearQuote() {
    quote = null;
    error = null;
  }

  double get fee => delivery ? (quote?['fee_usd'] as num?)?.toDouble() ?? 0 : 0;
  Map<String, dynamic>? validatedPayload() {
    if (!delivery) return null;
    if (!(form.currentState?.validate() ?? false)) {
      throw Exception('Completa los datos de entrega.');
    }
    final expiry = DateTime.tryParse('${quote?['expires_at']}');
    if (quote == null || expiry == null || !expiry.isAfter(DateTime.now())) {
      throw Exception(
        'Calcula el envío antes de pagar. La cotización dura 10 minutos.',
      );
    }
    return {
      'fulfillment': 'DELIVERY',
      'delivery_quote_id': quote!['id'],
      'delivery_recipient': name.text.trim(),
      'delivery_phone': phone.text.trim(),
      'delivery_address': address.text.trim(),
    };
  }

  Future<void> calculate() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() {
      loading = true;
      error = null;
      quote = null;
    });
    widget.onChanged();
    final branch = widget.branchId, destination = maps.text.trim();
    try {
      final result = await context.read<ApiService>().postOnline(
        '/own/deliveries/quote',
        body: {'branch_id': branch, 'destination_maps_url': destination},
      );
      if (!mounted ||
          branch != widget.branchId ||
          destination != maps.text.trim()) {
        return;
      }
      setState(() => quote = Map<String, dynamic>.from(result));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
        widget.onChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<ApiService>().offline?.offline ?? false;
    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            '3. ¿Cómo recibes tu compra?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
            onChanged: !widget.enabled || loading
                ? null
                : (value) {
                    setState(() {
                      delivery = value ?? false;
                      error = null;
                    });
                    widget.onChanged();
                  },
          ),
          if (delivery) ...[
            if (offline)
              const Text(
                'El delivery necesita Internet para cotizar y confirmar el pago.',
              ),
            TextFormField(
              controller: name,
              enabled: widget.enabled && !loading,
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
              enabled: widget.enabled && !loading,
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
              enabled: widget.enabled && !loading,
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
              enabled: widget.enabled && !loading,
              maxLength: 2048,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link de Google Maps',
                hintText: 'Pega el enlace de Compartir ubicación',
              ),
              validator: (v) => Uri.tryParse(v?.trim() ?? '')?.scheme != 'https'
                  ? 'Pega un enlace HTTPS de Google Maps'
                  : null,
              onChanged: (_) {
                setState(() => quote = null);
                widget.onChanged();
              },
            ),
            OutlinedButton.icon(
              onPressed: !widget.enabled || loading || offline
                  ? null
                  : calculate,
              icon: const Icon(Icons.route),
              label: Text(
                loading ? 'Calculando recorrido…' : 'Calcular envío y tiempo',
              ),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (quote != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Origen: ${quote!['branch_name']}'),
                      Text('${quote!['distance_km']} km por calles · Bs 4/km'),
                      Text(
                        'Envío: USD ${fee.toStringAsFixed(2)} (Bs ${quote!['fee_bob']})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Cambio: Bs ${quote!['bob_per_usd']} por USD 1. Se cobra junto con las prendas.',
                      ),
                      Text(
                        'Llegada estimada: ${quote!['estimated_minutes_min']}–${quote!['estimated_minutes_max']} min desde la aceptación. Puede variar por tráfico.',
                      ),
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse(quote!['directions_url']),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Ver recorrido en Google Maps'),
                      ),
                    ],
                  ),
                ),
              ),
            const Text(
              'La sucursal debe aceptar el envío. Si lo rechaza, recoges tus prendas pagadas y el envío vuelve a tu wallet.',
            ),
          ],
        ],
      ),
    );
  }
}
