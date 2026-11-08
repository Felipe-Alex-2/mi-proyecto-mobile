import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

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

  Future<void> _pdf(Map<String, dynamic> p) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      final bytes = await context.read<ApiService>().getBytes(
        '/saas/history/${Uri.encodeComponent(p['id'].toString())}/invoice',
      );
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: ['comprobante-vesta.pdf'],
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
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
              if (p['status'] == 'PAID' &&
                  (p['exchange_code'] != null || items.isNotEmpty)) ...[
                const Text(
                  'Código para cambios / devoluciones:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(p['exchange_code'] ?? p['payment_code'] ?? ''),
                const Text('Plazo: 48 horas desde la emisión del recibo.'),
              ],
              const Divider(),
              Text(p['concept'] ?? ''),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${item['quantity']} × ${item['product_name']} — ${(item['wholesale_discount_percent'] as num? ?? 0) > 0 ? item['original_subtotal'] : item['subtotal']} ${p['currency']}',
                  ),
                ),
              const Divider(),
              if ((p['wholesale_discount_percent'] as num? ?? 0) > 0)
                Text(
                  'Venta por mayor -${p['wholesale_discount_percent']}%: -${p['wholesale_discount_amount']} ${p['currency']}',
                ),
              Text('Total: ${p['amount']} ${p['currency']}'),
              Text('Estado: ${p['status'] == 'PAID' ? 'Pagado' : p['status']}'),
              Text('Forma de pago: ${p['payment_type'] ?? ''}'),
              Text('Referencia: ${p['reference'] ?? p['payment_code']}'),
              Text('Fecha: ${p['paid_at'] ?? p['created_at']}'),
            ],
          ),
        ),
        actions: [
          if (p['status'] == 'PAID')
            TextButton.icon(
              onPressed: () => _pdf(p),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Compartir PDF'),
            ),
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
                    'Aquí aparecerán tus pagos y recargas cuando realices una operación.',
                  ),
                for (final p in _payments)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${p['payment_code']} · ${p['amount']} ${p['currency']}',
                      ),
                      subtitle: Text(
                        '${p['concept']} · ${p['company_name']} · ${p['status'] == 'PAID' ? 'Pagado' : 'Pendiente'}',
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
