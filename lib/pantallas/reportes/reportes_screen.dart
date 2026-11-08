import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:share_plus/share_plus.dart';

import '../../servicios/api_service.dart';
import '../../servicios/autenticacion_service.dart';

const reportLabels = {
  'company': 'Empresa',
  'companies': 'Empresas',
  'branch': 'Sucursal',
  'city': 'Ciudad',
  'units': 'Unidades',
  'sales': 'Cobros realizados',
  'amount': 'Importe cobrado',
  'currency': 'Moneda',
  'scope': 'Ámbito',
  'product': 'Prenda',
  'products': 'Prendas',
  'quantity': 'Cantidad',
  'threshold': 'Umbral',
  'alerts': 'Alertas',
  'sku': 'SKU',
  'status': 'Estado',
  'reservations': 'Reservas',
  'customer': 'Cliente',
  'email': 'Correo',
  'registered_at': 'Fecha de registro',
  'category': 'Categoría',
  'season': 'Temporada',
  'supplier': 'Proveedor',
  'records': 'Registros',
  'variants_in_stock': 'Variantes con stock',
  'total_units': 'Unidades totales',
  'most_stock_branch': 'Mayor inventario',
  'branches': 'Sucursales',
  'total': 'Total',
};
String reportLabel(String key) =>
    reportLabels[key] ??
    (key.startsWith('leader_')
        ? 'Mayor venta (${key.substring(7)})'
        : key.startsWith('total_')
        ? 'Total (${key.substring(6)})'
        : key.replaceAll('_', ' '));
String reportCsv(Map<String, dynamic> report) {
  String cell(dynamic value) {
    var text = '${value ?? ''}';
    if (RegExp(r'^[=+@\-\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final columns = (report['columns'] as List).cast<String>();
  return '\ufeff${[columns.map((key) => cell(reportLabel(key))).join(','), ...(report['rows'] as List).map((row) => columns.map((key) => cell(row[key])).join(','))].join('\r\n')}';
}

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});
  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final _transcript = TextEditingController();
  final _email = TextEditingController();
  final _search = TextEditingController();
  final _threshold = TextEditingController(text: '5');
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _tts = FlutterTts();
  final _speech = SpeechToText();
  bool _busy = false,
      _listening = false,
      _speaking = false,
      _global = false,
      _ai = false;
  String? _error;
  Map<String, dynamic>? _report;
  List<dynamic> _branches = [];
  String _branch = '', _status = '', _type = 'inventory_by_branch';
  static const types = {
    'inventory_by_branch': 'Stock disponible por sucursal',
    'sales_by_branch': 'Ventas cobradas por sucursal',
    'products_by_category': 'Productos por categoría',
    'products_by_season': 'Productos por temporada',
    'low_stock': 'Alertas de stock bajo',
    'reservations_status': 'Estado de reservas',
    'reservations_by_branch': 'Reservas por sucursal',
    'products_by_supplier': 'Catálogo por proveedor',
    'products_detail': 'Detalle de prendas en stock',
    'companies_list': 'Empresas existentes',
    'branches_list': 'Sucursales de todas las empresas',
    'payments_detail': 'Detalle de pagos',
    'wallet_topups': 'Recargas de wallet',
    'registered_customers': 'Clientes registrados',
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final user = context.read<AutenticacionService>().currentUser!;
    setState(() {
      _email.text = user.email;
      _global = true;
      _ai = user.isSaasAdmin;
      _branch = '';
    });
    final api = context.read<ApiService>();
    try {
      final rows = await api.getOnline('/reports/branches');
      if (mounted) setState(() => _branches = rows as List);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudieron consultar las sucursales: $e');
      }
    }
    if (!user.isSaasAdmin) {
      try {
        final sub = await api.getOnline('/saas/subscription');
        if (mounted) setState(() => _ai = sub['ai_reports'] == true);
      } catch (_) {}
    }
  }

  void _stopReading() {
    _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _generate({bool voice = false}) async {
    if (_busy) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      setState(() => _error = 'Escribe un correo válido para enviar el PDF.');
      return;
    }
    _stopReading();
    setState(() {
      _busy = true;
      _error = null;
      _report = null;
    });
    try {
      final api = context.read<ApiService>();
      final body = <String, dynamic>{
        'all_companies': _global,
        'email_to': _email.text.trim(),
        if (!_global && _branch.isNotEmpty) 'branch_id': _branch,
      };
      if (voice) {
        body['transcript'] = _transcript.text.trim();
      } else {
        body.addAll({
          'report_type': _type,
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
          'low_stock_threshold': int.tryParse(_threshold.text) ?? 5,
          if (_status.isNotEmpty) 'status': _status,
          if (_type.startsWith('sales_') && _from.text.isNotEmpty)
            'date_from': _from.text,
          if (_type.startsWith('sales_') && _to.text.isNotEmpty)
            'date_to': _to.text,
        });
      }
      final data = await api.postOnline(
        voice ? '/reports/voice' : '/reports/generate',
        body: body,
      );
      if (mounted) {
        setState(
          () => _report = Map<String, dynamic>.from(
            voice ? data['report'] : data,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _listen() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    _stopReading();
    try {
      final ready = await _speech.initialize(
        onError: (e) {
          if (mounted) {
            setState(() {
              _error = 'No se pudo usar el micrófono. Revisa sus permisos.';
              _listening = false;
            });
          }
        },
        onStatus: (s) {
          if (mounted && s != 'listening') setState(() => _listening = false);
        },
      );
      if (!ready) {
        throw Exception(
          'El dictado no está disponible. Puedes escribir la consulta.',
        );
      }
      final locales = await _speech.locales();
      final spanish = locales
          .where((l) => l.localeId.startsWith('es'))
          .firstOrNull;
      if (!mounted) return;
      setState(() => _listening = true);
      await _speech.listen(
        listenOptions: SpeechListenOptions(localeId: spanish?.localeId),
        onResult: (result) {
          if (mounted) {
            setState(() => _transcript.text = result.recognizedWords);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _listening = false;
        });
      }
    }
  }

  Future<void> _read() async {
    final report = _report;
    if (report == null) return;
    if (_speaking) {
      _stopReading();
      return;
    }
    try {
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(.45);
      await _tts.awaitSpeakCompletion(true);
      if (!mounted) return;
      setState(() => _speaking = true);
      await _tts.speak('${report['narration'] ?? report['title']}');
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo leer el reporte: $e');
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _export() async {
    if (_report == null) return;
    try {
      final bytes = Uint8List.fromList(utf8.encode(reportCsv(_report!)));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'text/csv')],
          fileNameOverrides: ['reporte-vesta.csv'],
          sharePositionOrigin: Rect.fromLTWH(
            0,
            0,
            MediaQuery.sizeOf(context).width,
            100,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo exportar el CSV: $e');
    }
  }

  Future<void> _retryEmail() async {
    final id = _report?['report_id'];
    if (id == null || _busy) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      setState(() => _error = 'Escribe un correo válido para enviar el PDF.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await context.read<ApiService>().postOnline(
        '/reports/$id/email',
        body: {'email_to': _email.text.trim()},
      );
      if (mounted) setState(() => _report = Map<String, dynamic>.from(value));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.cancel();
    for (final c in [_transcript, _search, _threshold, _from, _to, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes empresariales')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Gmail / correo de destino',
              hintText: 'nombre@gmail.com',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy || current?['report_id'] == null
                ? null
                : _retryEmail,
            icon: const Icon(Icons.mail_outline),
            label: const Text('Mandar al Gmail'),
          ),
          const Text(
            'Puedes cambiar el correo. Al generar se envía el PDF a esta dirección.',
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Todas las empresas y sucursales'),
            value: _global,
            onChanged: _busy
                ? null
                : (v) {
                    _stopReading();
                    setState(() {
                      _global = v;
                      _branch = '';
                      _report = null;
                      if (!v && _type == 'sales_by_company') {
                        _type = 'sales_by_branch';
                      }
                    });
                  },
          ),
          if (!_global)
            DropdownButtonFormField<String>(
              key: ValueKey('branch_$_branch'),
              initialValue: _branch,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sucursal'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Todas las sucursales'),
                ),
                ..._branches.map(
                  (b) => DropdownMenuItem(
                    value: '${b['id']}',
                    child: Text('${b['company_name']} · ${b['name']}'),
                  ),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      _stopReading();
                      setState(() {
                        _branch = v ?? '';
                        _report = null;
                      });
                    },
            ),
          const SizedBox(height: 20),
          Text('Reporte manual', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('type_$_type'),
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tipo de reporte'),
            items: [
              for (final type in types.entries)
                DropdownMenuItem(value: type.key, child: Text(type.value)),
              if (_global)
                const DropdownMenuItem(
                  value: 'sales_by_company',
                  child: Text('Ventas cobradas por empresa'),
                ),
            ],
            onChanged: _busy ? null : (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 12),
          if (_type.startsWith('sales_')) ...[
            TextField(
              controller: _from,
              decoration: const InputDecoration(
                labelText: 'Desde (AAAA-MM-DD)',
                hintText: '2026-11-01',
              ),
            ),
            TextField(
              controller: _to,
              decoration: const InputDecoration(
                labelText: 'Hasta (AAAA-MM-DD)',
                hintText: '2026-11-30',
              ),
            ),
            const Text('Las monedas se comparan por separado.'),
          ] else if (_type == 'low_stock')
            TextField(
              controller: _threshold,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Umbral de stock'),
            )
          else if (_type.startsWith('reservations_'))
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: [
                for (final status in {
                  '': 'Todos',
                  'PENDING': 'Pendiente',
                  'CONFIRMED': 'Confirmada',
                  'COMPLETED': 'Completada',
                  'CANCELLED': 'Cancelada',
                }.entries)
                  DropdownMenuItem(
                    value: status.key,
                    child: Text(status.value),
                  ),
              ],
              onChanged: (v) => setState(() => _status = v!),
            )
          else if (_type != 'registered_customers')
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Buscar producto (opcional)',
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _generate(),
            child: const Text('Generar reporte'),
          ),
          const SizedBox(height: 24),
          Text(
            'Reporte por voz o texto',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!_ai)
            const Text(
              'Consultas frecuentes disponibles. La interpretación avanzada requiere configurar Gemini.',
            ),
          TextField(
            controller: _transcript,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Tu consulta',
              hintText: 'Lista las empresas existentes. Mis pagos de este mes.',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _listen,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
                label: Text(_listening ? 'Detener' : 'Hablar'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _generate(voice: true),
                child: const Text('Procesar texto'),
              ),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: 24),
            Text(
              '${current['title']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (current['email_message'] != null)
              Text('${current['email_message']}'),
            if (current['email_status'] == 'FAILED')
              TextButton(
                onPressed: _busy ? null : _retryEmail,
                child: const Text('Reintentar envío al Gmail indicado'),
              ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _read,
                  icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
                  label: Text(_speaking ? 'Detener lectura' : 'Leer reporte'),
                ),
                OutlinedButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar CSV'),
                ),
              ],
            ),
            for (final entry in (current['summary'] as Map).entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${reportLabel('${entry.key}')}: ${entry.value}'),
              ),
            if ((current['rows'] as List).isEmpty)
              const Text('No hay registros para estos filtros.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    for (final key in current['columns'])
                      DataColumn(label: Text(reportLabel('$key'))),
                  ],
                  rows: [
                    for (final row in current['rows'])
                      DataRow(
                        cells: [
                          for (final key in current['columns'])
                            DataCell(Text('${row[key] ?? '—'}')),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
