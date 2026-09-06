import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../services/catalog_service.dart';
import 'product_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogService>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        foregroundColor: AppTheme.brown,
        title: const Row(
          children: [
            Icon(Icons.checkroom_rounded, color: AppTheme.terracotta, size: 22),
            SizedBox(width: 8),
            Text(
              'Catálogo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.brown,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<CatalogService>(
            builder: (_, catalog, __) => IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.brownMedium),
              tooltip: 'Actualizar',
              onPressed: catalog.loadProducts,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(child: _buildProductList()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Consumer<CatalogService>(
      builder: (_, catalog, __) => Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              onChanged: catalog.setSearch,
              decoration: InputDecoration(
                hintText: 'Buscar prendas...',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppTheme.brownMedium),
                suffixIcon: catalog.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppTheme.brownMedium,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          catalog.setSearch('');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            // Category chips
            if (catalog.categories.length > 1)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: catalog.categories.map((cat) {
                    final isSelected = catalog.selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: AppTheme.terracotta,
                        backgroundColor: AppTheme.creamLight,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.brownMedium,
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.terracotta
                              : AppTheme.terracotta.withValues(alpha: 0.2),
                        ),
                        onSelected: (_) => catalog.setCategory(cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return Consumer<CatalogService>(
      builder: (_, catalog, __) {
        if (catalog.status == CatalogStatus.loading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.terracotta),
                SizedBox(height: 16),
                Text(
                  'Cargando catálogo...',
                  style: TextStyle(color: AppTheme.brownMedium),
                ),
              ],
            ),
          );
        }

        if (catalog.status == CatalogStatus.error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 64,
                    color: AppTheme.brownMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo cargar el catálogo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.brown,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    catalog.errorMessage ?? 'Error desconocido',
                    style: const TextStyle(
                      color: AppTheme.brownMedium,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: catalog.loadProducts,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final products = catalog.products;

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: AppTheme.brownMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sin resultados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.brown,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Prueba con otra búsqueda o categoría',
                  style: TextStyle(color: AppTheme.brownMedium, fontSize: 14),
                ),
                if (catalog.searchQuery.isNotEmpty ||
                    catalog.selectedCategory != 'Todos')
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        catalog.clearFilters();
                      },
                      icon: const Icon(Icons.filter_list_off_rounded),
                      label: const Text('Limpiar filtros'),
                    ),
                  ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: products.length,
          itemBuilder: (_, index) => _ProductCard(product: products[index]),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.terracotta.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product image
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: _buildImage(),
              ),
            ),
            // Product info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.brown,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.category,
                      style: const TextStyle(
                        color: AppTheme.brownMedium,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _priceText(),
                            style: const TextStyle(
                              color: AppTheme.terracotta,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StockBadge(available: product.isAvailable),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Color dots
                    if (product.availableColors.isNotEmpty)
                      _ColorDots(colors: product.availableColors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priceText() {
    if (product.variants.isEmpty) return '\$0';
    if (product.minPrice == product.maxPrice) {
      return '\$${product.minPrice.toStringAsFixed(0)}';
    }
    return '\$${product.minPrice.toStringAsFixed(0)} - \$${product.maxPrice.toStringAsFixed(0)}';
  }

  Widget _buildImage() {
    final url = product.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: AppTheme.creamLight,
        child: const Icon(
          Icons.checkroom_rounded,
          size: 40,
          color: AppTheme.terracotta,
        ),
      );
    }
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return Container(
          color: AppTheme.creamLight,
          child: const Icon(
            Icons.broken_image_rounded,
            size: 40,
            color: AppTheme.brownMedium,
          ),
        );
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppTheme.creamLight,
        child: const Icon(
          Icons.checkroom_rounded,
          size: 40,
          color: AppTheme.terracotta,
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final bool available;
  const _StockBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: available
            ? AppTheme.successColor.withValues(alpha: 0.1)
            : AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: available
              ? AppTheme.successColor.withValues(alpha: 0.4)
              : AppTheme.errorColor.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        available ? 'Stock' : 'Sin stock',
        style: TextStyle(
          color: available ? AppTheme.successColor : AppTheme.errorColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ColorDots extends StatelessWidget {
  final List<String> colors;
  const _ColorDots({required this.colors});

  static const _colorMap = {
    'negro': Color(0xFF111827),
    'blanco': Color(0xFFF8FAFC),
    'rojo': Color(0xFFEF4444),
    'azul': Color(0xFF3B82F6),
    'verde': Color(0xFF22C55E),
    'amarillo': Color(0xFFEAB308),
    'naranja': Color(0xFFF97316),
    'morado': Color(0xFF8B5CF6),
    'gris': Color(0xFF6B7280),
    'rosa': Color(0xFFEC4899),
    'celeste': Color(0xFF38BDF8),
    'cafe': Color(0xFF92400E),
    'beige': Color(0xFFD4A373),
    'terracota': Color(0xFF8B4513),
  };

  Color _colorFor(String name) {
    final lower = name.toLowerCase();
    for (final entry in _colorMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return const Color(0xFF8B7355);
  }

  @override
  Widget build(BuildContext context) {
    final shown = colors.take(5).toList();
    return Row(
      children: [
        ...shown.map(
          (c) => Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: _colorFor(c),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.terracotta.withValues(alpha: 0.2),
              ),
            ),
          ),
        ),
        if (colors.length > 5)
          Text(
            '+${colors.length - 5}',
            style: const TextStyle(color: AppTheme.brownMedium, fontSize: 10),
          ),
      ],
    );
  }
}
