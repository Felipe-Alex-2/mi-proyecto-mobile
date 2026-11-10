import 'package:flutter/material.dart';

import '../servicios/carlitos_modelo_local.dart';

class DescargaCarlitos extends StatefulWidget {
  final CarlitosModeloLocal model;
  const DescargaCarlitos({super.key, required this.model});

  @override
  State<DescargaCarlitos> createState() => _DescargaCarlitosState();
}

class _DescargaCarlitosState extends State<DescargaCarlitos> {
  @override
  void initState() {
    super.initState();
    widget.model.prepare();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final model = widget.model;
      return Card(
        child: ExpansionTile(
          leading: const Icon(Icons.offline_bolt_outlined),
          title: Text(
            model.ready ? 'IA local descargada' : 'Carlitos sin Internet',
          ),
          subtitle: Text(
            model.generating
                ? 'Pensando en este celular…'
                : model.downloading
                ? 'Descargando ${(model.downloaded / 1048576).toStringAsFixed(0)} / 409 MiB'
                : 'Preguntas frecuentes disponibles · modelo opcional',
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            const Text(
              'La búsqueda por talla, color y las preguntas frecuentes funcionan sin descargar nada. '
              'Para conversar sobre moda puedes descargar Qwen 0.5B (409 MiB) una vez con Internet. '
              'Después responde en este celular sin enviar tu consulta. Necesita espacio y memoria disponibles; '
              'sus consejos pueden equivocarse y no confirman compras ni existencias.',
            ),
            if (model.downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (model.downloaded / CarlitosModeloLocal.byteSize).clamp(
                  0,
                  1,
                ),
              ),
              TextButton.icon(
                onPressed: model.pause,
                icon: const Icon(Icons.pause),
                label: const Text('Pausar descarga'),
              ),
            ] else if (model.ready)
              TextButton.icon(
                onPressed: model.generating ? null : model.remove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar modelo y liberar espacio'),
              )
            else
              FilledButton.icon(
                onPressed: model.download,
                icon: const Icon(Icons.download),
                label: const Text('Descargar / reanudar · 409 MiB'),
              ),
            if (model.error != null)
              Text(
                model.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    },
  );
}
