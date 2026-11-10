import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../configuracion/tema.dart';
import '../../modelos/producto.dart';
import '../../modelos/recomendacion.dart';
import '../../servicios/recomendacion_service.dart';
import '../../servicios/api_service.dart';
import '../../widgets/foto_producto.dart';
import '../../widgets/descarga_carlitos.dart';
import '../catalogo/detalle_producto_screen.dart';

class AsistenteCarlitosScreen extends StatefulWidget {
  const AsistenteCarlitosScreen({super.key});

  @override
  State<AsistenteCarlitosScreen> createState() =>
      _AsistenteCarlitosScreenState();
}

class _AsistenteCarlitosScreenState extends State<AsistenteCarlitosScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showHowItWorks = false;

  final List<String> _quickExamples = [
    'Me gustan los colores oscuros y los pantalones para el invierno',
    'Quiero una prenda roja para verano',
    'Vestido elegante para una fiesta de noche',
    'Ropa casual y cómoda para el día a día',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitQuery(String query) {
    if (query.trim().isEmpty) return;
    _controller.text = query;
    _focusNode.unfocus();
    context.read<RecomendacionService>().getRecommendations(query);
  }

  @override
  Widget build(BuildContext context) {
    final recommendationService = context.watch<RecomendacionService>();
    final isLoading = recommendationService.isLoading;
    final errorMessage = recommendationService.errorMessage;
    final response = recommendationService.lastResponse;
    final localMode =
        recommendationService.isLocalResponse ||
        (context.read<ApiService>().offline?.offline ?? false);
    final examples = localMode
        ? const [
            'Me gusta el azul',
            '¿Cómo pago sin Internet?',
            'Camisa azul talla M',
            'Pantalones hasta 200',
            'Muéstrame el catálogo',
            'Qué puedes hacer',
          ]
        : _quickExamples;

    return Scaffold(
      backgroundColor: TemaApp.cream,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: TemaApp.terracotta, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                localMode ? 'Carlitos · modo local' : 'Asistente IA Carlitos',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: TemaApp.brown,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showHowItWorks ? Icons.help : Icons.help_outline,
              color: TemaApp.terracotta,
            ),
            tooltip: 'Cómo funciona',
            onPressed: () {
              setState(() {
                _showHowItWorks = !_showHowItWorks;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DescargaCarlitos(model: recommendationService.localModel),
            const SizedBox(height: 12),
            // Encabezado principal
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [TemaApp.brown, Color(0xFF5D3A24)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: TemaApp.brown.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: TemaApp.terracotta.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: TemaApp.terracotta,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localMode
                                  ? 'Carlitos · búsqueda local'
                                  : 'Asistente Carlitos · IA',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Recomendador basado en catálogo real',
                              style: TextStyle(
                                color: Color(0xFFDCC8B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Cuéntame qué buscas y buscaré prendas de nuestro catálogo. Sin conexión puedes consultar la copia guardada en este celular.',
                    style: TextStyle(
                      color: Color(0xFFF3EDE7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Panel "Cómo funciona" (Desplegable)
            if (_showHowItWorks) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TemaApp.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: TemaApp.terracotta.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: TemaApp.terracotta,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '¿CÓMO FUNCIONA?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: TemaApp.terracotta,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      number: '01',
                      title: 'Escribes tus preferencias',
                      subtitle:
                          'En lenguaje natural, sin formularios complicados.',
                    ),
                    const SizedBox(height: 10),
                    _buildStepRow(
                      number: '02',
                      title: 'Conexión o búsqueda local',
                      subtitle: 'Con Internet consulto la IA. Sin conexión busco prendas, respondo preguntas frecuentes y, si descargaste el modelo, doy consejos de moda en este celular.',
                    ),
                    const SizedBox(height: 10),
                    _buildStepRow(
                      number: '03',
                      title: 'Búsqueda en inventario real',
                      subtitle: 'Usa productos del catálogo. Offline, el stock y los precios pueden cambiar y se confirman al sincronizar.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Tarjeta de Entrada de Usuario
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TemaApp.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: TemaApp.terracotta.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Qué estás buscando hoy?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: TemaApp.brown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ej: "Me gustan los pantalones oscuros para invierno" o "Quiero una polera roja"',
                    style: TextStyle(color: TemaApp.brownMedium, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 3,
                    minLines: 2,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) => _submitQuery(val),
                    decoration: InputDecoration(
                      hintText: 'Escribe tus gustos aquí...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: TemaApp.creamLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: TemaApp.terracotta.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: TemaApp.terracotta.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: TemaApp.terracotta,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () => _submitQuery(_controller.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TemaApp.terracotta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Carlitos está analizando tus gustos...',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, size: 18),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Encontrar mis recomendaciones',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Pruebas rápidas:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: TemaApp.brownMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: examples.map((example) {
                      return InkWell(
                        onTap: isLoading ? null : () => _submitQuery(example),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: TemaApp.terracotta.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: TemaApp.terracotta.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                size: 12,
                                color: TemaApp.terracotta,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  example,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: TemaApp.brown,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (localMode) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TemaApp.sage,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Modo local · Consulto el catálogo guardado y preguntas frecuentes. Con el modelo descargado también puedo dar consejos de moda. Precios y stock se confirman al sincronizar.',
                  style: TextStyle(color: TemaApp.sageInk, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Mensaje de Error
            if (errorMessage != null && !isLoading) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: TemaApp.errorColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: TemaApp.errorColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Resultados de Recomendaciones
            if (response != null && !isLoading) ...[
              _buildResultsSection(response),
            ] else if (response == null &&
                !isLoading &&
                errorMessage == null) ...[
              _buildInitialState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: TemaApp.terracotta,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: TemaApp.brown,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: TemaApp.brownMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInitialState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: TemaApp.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TemaApp.terracotta.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TemaApp.terracotta.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: TemaApp.terracotta,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tu próximo conjunto puede empezar con una frase',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: TemaApp.brown,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Escribe qué buscas y Carlitos usará inteligencia artificial (Gemini) para interpretar tus gustos y recomendarte prendas disponibles de la tienda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: TemaApp.brownMedium,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(RecomendacionResponse result) {
    final filters = result.matchedFilters;
    final products = result.recommendations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header de Resultados
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TemaApp.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: TemaApp.terracotta.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text(
                    'RECOMENDACIONES PARA TI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: TemaApp.terracotta,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: TemaApp.terracotta.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${products.length} prendas',
                      style: const TextStyle(
                        color: TemaApp.terracotta,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                result.message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: TemaApp.brown,
                ),
              ),
              if (filters.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  context.read<RecomendacionService>().isLocalResponse
                      ? 'Filtros de búsqueda local:'
                      : 'Coincidencias interpretadas por IA:',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: TemaApp.brownMedium,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: filters.entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TemaApp.brown.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TemaApp.brown.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check,
                            size: 12,
                            color: TemaApp.terracotta,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${entry.key.toUpperCase()}: ${entry.value}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: TemaApp.brown,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (products.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: TemaApp.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  color: TemaApp.brownMedium,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  context.read<RecomendacionService>().isLocalResponse
                      ? 'Consulta tu catálogo guardado'
                      : 'No encontramos coincidencias exactas',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: TemaApp.brown,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prueba con una prenda, color, talla o presupuesto.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TemaApp.brownMedium,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(product);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildProductCard(Producto product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleProductoScreen(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: TemaApp.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TemaApp.terracotta.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del producto
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: FotoProducto(url: product.imageUrl)),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${product.totalStock} disp.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${product.category} · ${product.gender}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: TemaApp.brownMedium,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: TemaApp.brown,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '\$ ${product.minPrice.toStringAsFixed(2)}',
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: TemaApp.terracotta,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: TemaApp.terracotta,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
