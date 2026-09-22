import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../models/recommendation.dart';
import '../../services/recommendation_service.dart';
import '../catalog/product_detail_screen.dart';

class AssistantCarlitosScreen extends StatefulWidget {
  const AssistantCarlitosScreen({super.key});

  @override
  State<AssistantCarlitosScreen> createState() => _AssistantCarlitosScreenState();
}

class _AssistantCarlitosScreenState extends State<AssistantCarlitosScreen> {
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
    context.read<RecommendationService>().getRecommendations(query);
  }

  @override
  Widget build(BuildContext context) {
    final recommendationService = context.watch<RecommendationService>();
    final isLoading = recommendationService.isLoading;
    final errorMessage = recommendationService.errorMessage;
    final response = recommendationService.lastResponse;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppTheme.terracotta, size: 20),
            SizedBox(width: 8),
            Text(
              'Asistente IA Carlitos',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppTheme.brown,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showHowItWorks ? Icons.help : Icons.help_outline,
              color: AppTheme.terracotta,
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
            // Encabezado principal
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.brown, Color(0xFF5D3A24)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brown.withValues(alpha: 0.25),
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
                          color: AppTheme.terracotta.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.terracotta, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asistente Carlitos · IA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
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
                    'Cuéntame qué buscas o qué estilo te gusta y encontraré prendas exactas de nuestro inventario que coincidan con tu preferencia.',
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
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.terracotta, size: 18),
                        SizedBox(width: 8),
                        Text(
                          '¿CÓMO FUNCIONA?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: AppTheme.terracotta,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      number: '01',
                      title: 'Escribes tus preferencias',
                      subtitle: 'En lenguaje natural, sin formularios complicados.',
                    ),
                    const SizedBox(height: 10),
                    _buildStepRow(
                      number: '02',
                      title: 'Gemini interpreta tus gustos',
                      subtitle: 'Detecta prendas, colores, temporadas, tallas y clima.',
                    ),
                    const SizedBox(height: 10),
                    _buildStepRow(
                      number: '03',
                      title: 'Búsqueda en inventario real',
                      subtitle: 'Solo te muestra productos existentes y disponibles.',
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
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.15)),
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
                      color: AppTheme.brown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ej: "Me gustan los pantalones oscuros para invierno" o "Quiero una polera roja"',
                    style: TextStyle(
                      color: AppTheme.brownMedium,
                      fontSize: 12,
                    ),
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
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.creamLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.terracotta.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.terracotta.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.terracotta, width: 1.5),
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
                        backgroundColor: AppTheme.terracotta,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Carlitos está analizando tus gustos...'),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Encontrar mis recomendaciones',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                      color: AppTheme.brownMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickExamples.map((example) {
                      return InkWell(
                        onTap: isLoading ? null : () => _submitQuery(example),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.terracotta.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.terracotta.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 12, color: AppTheme.terracotta),
                              const SizedBox(width: 6),
                              Text(
                                example.length > 28 ? '${example.substring(0, 26)}...' : example,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.brown,
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
                    const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
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
            ] else if (response == null && !isLoading && errorMessage == null) ...[
              _buildInitialState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow({required String number, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.terracotta,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.brown),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.brownMedium),
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.terracotta.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.terracotta, size: 36),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tu próximo conjunto puede empezar con una frase',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.brown,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Escribe qué buscas y Carlitos usará inteligencia artificial (Gemini) para interpretar tus gustos y recomendarte prendas disponibles de la tienda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.brownMedium,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(RecommendationResponse result) {
    final filters = result.matchedFilters;
    final products = result.recommendations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header de Resultados
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECOMENDACIONES PARA TI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppTheme.terracotta,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.terracotta.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${products.length} prendas',
                      style: const TextStyle(
                        color: AppTheme.terracotta,
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
                  color: AppTheme.brown,
                ),
              ),
              if (filters.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Coincidencias interpretadas por IA:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.brownMedium,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: filters.entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.brown.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.brown.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, size: 12, color: AppTheme.terracotta),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.key.toUpperCase()}: ${entry.value}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.brown,
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
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.search_off_rounded, color: AppTheme.brownMedium, size: 40),
                SizedBox(height: 10),
                Text(
                  'No encontramos coincidencias exactas',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.brown),
                ),
                SizedBox(height: 4),
                Text(
                  'Prueba describiendo otro color, prenda, temporada o una descripción más general.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.brownMedium, fontSize: 12),
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

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.12)),
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
                  Positioned.fill(
                    child: _buildProductImage(product.imageUrl),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                      color: AppTheme.brownMedium,
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
                      color: AppTheme.brown,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$ ${product.minPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.terracotta,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.terracotta),
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

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: AppTheme.brown.withValues(alpha: 0.06),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.checkroom_rounded, color: AppTheme.brownMedium, size: 28),
              SizedBox(height: 4),
              Text(
                'VESTA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppTheme.brownMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (imageUrl.startsWith('data:image')) {
      try {
        final commaIdx = imageUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? imageUrl.substring(commaIdx + 1) : imageUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallbackImage(),
        );
      } catch (_) {
        return _buildFallbackImage();
      }
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _buildFallbackImage(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppTheme.creamLight,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.terracotta),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: AppTheme.brown.withValues(alpha: 0.06),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppTheme.brownMedium, size: 28),
      ),
    );
  }
}
