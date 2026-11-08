import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../servicios/api_service.dart';
import '../../utilidades/request_id.dart';
import 'historial_compras_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  String? _error;
  String? _message;
  bool _busy = false;
  bool _loading = true;
  int _amount = 10;
  String? _awaiting;
  final Map<int, String> _attempts = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaiting != null && !_busy) {
      _verify(_awaiting!);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final value = await context.read<ApiService>().getOnline('/wallet');
      if (mounted) setState(() => _data = Map<String, dynamic>.from(value));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('No se pudo abrir PayPal Sandbox.');
    }
  }

  Future<void> _topup({String? retryId, int? amount}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final selected = amount ?? _amount;
      final row = await context.read<ApiService>().postOnline(
        '/wallet/topups',
        body: {
          'amount': selected,
          'request_id': retryId ?? _attempts.putIfAbsent(selected, requestId),
        },
      );
      _awaiting = row['id'];
      _attempts.remove(selected);
      await _load();
      if (row['status'] == 'PAID') {
        if (mounted) {
          setState(() => _message = 'Esta recarga ya está confirmada.');
        }
        return;
      }
      await _open(row['approval_url']);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify(String id) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final value = await context.read<ApiService>().postOnline(
        '/wallet/topups/$id/capture',
      );
      if (mounted) {
        setState(() {
          _data = Map<String, dynamic>.from(value);
          _message = 'Recarga confirmada. Tu comprobante está en Mis compras y comprobantes.';
          _awaiting = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi wallet')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading || _busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_message!),
            ),
          Text(
            _data == null
                ? 'Consultando saldo…'
                : 'USD ${(_data!['balance'] as num).toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const Text(
            'Saldo disponible en esta empresa. Se usa para pagar tus prendas; las recargas no generan puntos.',
          ),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistorialComprasScreen()),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Mis compras y comprobantes'),
          ),
          const SizedBox(height: 24),
          Text(
            'Recargar con PayPal Sandbox',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              for (final amount in [10, 50, 100])
                ChoiceChip(
                  label: Text('USD $amount'),
                  selected: _amount == amount,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _amount = amount),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : () => _topup(),
            icon: const Icon(Icons.add_card),
            label: Text('Pagar USD $_amount en PayPal'),
          ),
          const Text(
            'Después de aprobar el pago vuelve a la app y verifica la recarga. El saldo se acredita únicamente al confirmar el cobro.',
          ),
          const SizedBox(height: 24),
          Text(
            'Recargas pendientes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final row in _data?['pending'] as List? ?? [])
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recarga USD ${row['amount']}'),
                    if (row['approval_url'] != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                try {
                                  _awaiting = row['id'];
                                  await _open(row['approval_url']);
                                } catch (e) {
                                  if (mounted) setState(() => _error = '$e');
                                }
                              },
                        child: const Text('Abrir PayPal Sandbox'),
                      ),
                    if (row['order_id'] != null)
                      FilledButton(
                        onPressed: _busy ? null : () => _verify(row['id']),
                        child: const Text('Ya pagué · Verificar recarga'),
                      )
                    else
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _topup(
                                retryId: row['request_id'],
                                amount: (row['amount'] as num).toInt(),
                              ),
                        child: const Text('Reintentar recarga'),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Movimientos', style: Theme.of(context).textTheme.titleLarge),
          for (final entry in _data?['entries'] as List? ?? [])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${entry['description']}'),
              subtitle: Text('${entry['created_at']}'.split('T').first),
              trailing: Text(
                'USD ${(entry['amount'] as num).toStringAsFixed(2)}',
              ),
            ),
        ],
      ),
    ),
  );
}
