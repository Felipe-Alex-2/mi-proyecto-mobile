import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../servicios/api_service.dart';

class PuntosScreen extends StatefulWidget {
  const PuntosScreen({super.key});
  @override
  State<PuntosScreen> createState() => _PuntosScreenState();
}

class _PuntosScreenState extends State<PuntosScreen> {
  Map<String, dynamic>? _account;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  String? _scope;
  final Map<String, String> _requests = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = context.read<ApiService>();
    final scope = '${api.activeTenantId}';
    if (_scope != scope) {
      _scope = scope;
      _account = null;
      _requests.clear();
      _load();
    }
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<ApiService>().getOnline('/own/loyalty');
      if (mounted) setState(() => _account = Map<String, dynamic>.from(data));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeem(Map<String, dynamic> option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Canjear ${option['name']}'),
        content: Text(
          'Se descontarán ${option['points']} puntos. ${option['id'] == 'MYSTERY' ? 'La prenda se entrega exclusivamente en sucursal.' : 'El cupón se usa una sola vez en carrito o caja.'} Válido durante 30 días.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Canjear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final id = '${option['id']}';
    try {
      await context.read<ApiService>().postOnline(
        '/own/loyalty/redeem',
        body: {'reward': id, 'request_id': _requests.putIfAbsent(id, _uuid)},
      );
      _requests.remove(id);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final balance = (account?['balance'] as num?)?.toInt() ?? 0;
    const statuses = {
      'AVAILABLE': 'Disponible',
      'RESERVED': 'Reservado en una compra',
      'USED': 'Utilizado',
      'CLAIMED': 'Retirado en sucursal',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Mis puntos y canjes')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Reintentar'),
              ),
            ],
            Text(
              '$balance puntos disponibles',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Recibes 1 punto por cada USD 10 pagados en prendas, calculado sobre el total final de cada compra. Los puntos pertenecen a la tienda seleccionada.',
              ),
            ),
            for (final raw in account?['options'] as List? ?? []) ...[
              Builder(
                builder: (context) {
                  final option = Map<String, dynamic>.from(raw);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${option['name']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('${option['points']} puntos · válido 30 días'),
                          if (option['id'] == 'MYSTERY')
                            const Text(
                              'Una prenda sorpresa. Retiro exclusivamente presencial.',
                            ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed:
                                _busy || balance < (option['points'] as num)
                                ? null
                                : () => _redeem(option),
                            child: Text('Canjear ${option['points']} puntos'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            Text('Mis códigos', style: Theme.of(context).textTheme.titleLarge),
            const Text(
              'Ingresa tu cupón al finalizar el carrito o preséntalo en caja junto a tu correo registrado. No se acumula con el 15% por mayor.',
            ),
            for (final r in account?['rewards'] as List? ?? [])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['reward_type'] == 'MYSTERY'
                            ? 'Caja misteriosa · retiro presencial'
                            : 'Cupón ${r['discount_percent']}%',
                      ),
                      Text(statuses[r['status']] ?? '${r['status']}'),
                      if (DateTime.tryParse('${r['expires_at']}')
                              ?.isBefore(DateTime.now()) ??
                          false)
                        const Text('Vencido'),
                      SelectableText(
                        '${r['code']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Vence: ${'${r['expires_at']}'.split('T').first}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text('Movimientos', style: Theme.of(context).textTheme.titleLarge),
            for (final e in account?['entries'] as List? ?? [])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${e['description']}'),
                trailing: Text('${e['points']} puntos'),
              ),
          ],
        ),
      ),
    );
  }
}
