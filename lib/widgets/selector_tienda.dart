import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../servicios/api_service.dart';

/// Only public company and branch information is downloaded before registration.
class SelectorTienda extends StatefulWidget {
  final String? tenantId;
  final String? branchId;
  final bool enabled;
  final void Function(String tenantId, String branchId) onSelected;
  const SelectorTienda({
    super.key,
    this.tenantId,
    this.branchId,
    this.enabled = true,
    required this.onSelected,
  });
  @override
  State<SelectorTienda> createState() => _SelectorTiendaState();
}

class _SelectorTiendaState extends State<SelectorTienda> {
  List<Map<String, dynamic>> _companies = [];
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await context.read<ApiService>().get(
        '/saas/directory',
        includeAuth: false,
      );
      if (!mounted) return;
      setState(
        () => _companies = (rows as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList(),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Conéctate a Internet para consultar o cambiar de tienda.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Empresa y sucursal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Elige dónde comprar. Tu historial y comprobantes permanecen en tu cuenta.',
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
          for (final company in _companies)
            ExpansionTile(
              key: ValueKey('${company['id']}-${widget.tenantId}'),
              initiallyExpanded: company['id'] == widget.tenantId,
              title: Text(company['name']),
              subtitle: Text(
                '${(company['branches'] as List).length} sucursal(es)',
              ),
              children: [
                if ((company['branches'] as List).isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sin sucursales disponibles.'),
                  ),
                for (final branch in company['branches'])
                  ListTile(
                    enabled: widget.enabled,
                    leading: Icon(
                      branch['id'] == widget.branchId &&
                              company['id'] == widget.tenantId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(branch['name']),
                    subtitle: Text(branch['city']),
                    selected:
                        branch['id'] == widget.branchId &&
                        company['id'] == widget.tenantId,
                    onTap: widget.enabled
                        ? () => widget.onSelected(company['id'], branch['id'])
                        : null,
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}
