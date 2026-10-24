import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../servicios/api_service.dart';

class HistorialComprasScreen extends StatefulWidget {
  const HistorialComprasScreen({super.key});
  @override
  State<HistorialComprasScreen> createState() => _HistorialComprasScreenState();
}

class _HistorialComprasScreenState extends State<HistorialComprasScreen> {
  List<Map<String, dynamic>> _payments = [];
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await context.read<ApiService>().get('/saas/history');
      if (mounted) {
        setState(
          () => _payments = (rows as List)
              .map((r) => Map<String, dynamic>.from(r))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _receipt(Map<String, dynamic> p) {
    List items = [];
    try {
      items = jsonDecode(p['items_detail'] ?? '[]') as List;
    } catch (_) {}
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Comprobante ${p['payment_code']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p['company_name'] ?? ''),
              Text(p['branch_name'] ?? ''),
              const Divider(),
              Text(p['concept'] ?? ''),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${item['quantity']} × ${item['product_name']} — ${item['subtotal']} ${p['currency']}',
                  ),
                ),
              const Divider(),
              Text('Total: ${p['amount']} ${p['currency']}'),
              Text('Estado: ${p['status'] == 'PAID' ? 'Pagado' : p['status']}'),
              Text('Forma de pago: ${p['payment_type'] ?? ''}'),
              Text('Referencia: ${p['reference'] ?? p['payment_code']}'),
              Text('Fecha: ${p['paid_at'] ?? p['created_at']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis compras y comprobantes')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Tus comprobantes de todas las empresas y sucursales se conservan en esta cuenta.',
                ),
                const SizedBox(height: 16),
                if (_error != null) Text(_error!),
                if (_payments.isEmpty && _error == null)
                  const Text(
                    'Todavía no tienes comprobantes de caja. Las reservas pagadas están en Mis reservas.',
                  ),
                for (final p in _payments)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${p['payment_code']} · ${p['amount']} ${p['currency']}',
                      ),
                      subtitle: Text(
                        '${p['company_name']} · ${p['branch_name']}',
                      ),
                      trailing: const Icon(Icons.receipt_long_outlined),
                      onTap: () => _receipt(p),
                    ),
                  ),
              ],
            ),
          ),
  );
}
