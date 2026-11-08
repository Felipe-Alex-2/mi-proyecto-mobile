import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../servicios/sin_conexion_service.dart';

class EstadoSinConexion extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  const EstadoSinConexion({
    super.key,
    required this.child,
    required this.navigatorKey,
  });
  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SinConexionService>();
    final show =
        sync.offline ||
        sync.serverUnavailable ||
        sync.pendingCount > 0 ||
        sync.needsLogin;
    return Column(
      children: [
        if (show)
          Material(
            color: sync.hasFailures
                ? const Color(0xFFFBE2DA)
                : const Color(0xFFF4E8CF),
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: () => showModalBottomSheet(
                  context: navigatorKey.currentState!.overlay!.context,
                  isScrollControlled: true,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: sync,
                    child: const _ColaSheet(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sync.offline ? Icons.cloud_off : Icons.sync,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sync.needsLogin
                              ? 'Vuelve a iniciar sesión para sincronizar'
                              : '${sync.offline
                                    ? "Modo offline · datos guardados"
                                    : sync.serverUnavailable
                                    ? "Servidor temporalmente no disponible"
                                    : sync.syncing
                                    ? "Sincronizando…"
                                    : "Cambios pendientes"} · ${sync.pendingCount} pendiente(s)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

class _ColaSheet extends StatelessWidget {
  const _ColaSheet();
  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SinConexionService>();
    return SafeArea(
      child: SizedBox(
        height: 450,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cambios guardados en el dispositivo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Se envían en orden al recuperar la conexión. El servidor confirma stock y precios. Los pagos requieren autorización en línea.',
                style: TextStyle(fontSize: 13),
              ),
              Expanded(
                child: ListView(
                  children: sync.operations
                      .map(
                        (row) => ListTile(
                          leading: Icon(
                            row['state'] == 'blocked'
                                ? Icons.error_outline
                                : Icons.schedule,
                          ),
                          title: Text(
                            '${row['path']}'.startsWith('/reservations')
                                ? 'Reserva / pedido'
                                : row['path'] == '/users/me'
                                ? 'Perfil'
                                : 'Carrito',
                          ),
                          subtitle: Text(
                            row['error'] as String? ??
                                'Pendiente de sincronización',
                          ),
                          trailing: row['state'] == 'blocked'
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip:
                                      'Descartar este cambio y los posteriores',
                                  onPressed: sync.syncing
                                      ? null
                                      : () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                    '¿Descartar cambios pendientes?',
                                                  ),
                                                  content: const Text(
                                                    'Se eliminará este cambio y los posteriores que puedan depender de él. Los datos ya confirmados se conservan.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'Volver',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'Descartar',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                          if (confirmed == true) {
                                            await sync.discardFrom(
                                              row['seq'] as int,
                                            );
                                          }
                                        },
                                )
                              : null,
                        ),
                      )
                      .toList(),
                ),
              ),
              FilledButton.icon(
                onPressed: sync.syncing ? null : sync.retry,
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar ahora'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
