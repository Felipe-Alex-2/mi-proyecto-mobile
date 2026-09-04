import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/product.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _selectedColor;
  String? _selectedSize;

  @override
  void initState() {
    super.initState();
    final colors = widget.product.availableColors;
    final sizes = widget.product.availableSizes;
    if (colors.isNotEmpty) _selectedColor = colors.first;
    if (sizes.isNotEmpty) _selectedSize = sizes.first;
  }

  List<ProductVariant> get _filteredVariants {
    return widget.product.variants.where((v) {
      final matchColor = _selectedColor == null || v.color == _selectedColor;
      final matchSize = _selectedSize == null || v.size == _selectedSize;
      return matchColor && matchSize;
    }).toList();
  }

  int get _totalStockForSelection =>
      _filteredVariants.fold(0, (sum, v) => sum + v.totalStock);

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, product),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(product),
                  const SizedBox(height: 24),
                  if (product.availableColors.isNotEmpty) ...[
                    _buildColorSelector(product),
                    const SizedBox(height: 20),
                  ],
                  if (product.availableSizes.isNotEmpty) ...[
                    _buildSizeSelector(product),
                    const SizedBox(height: 20),
                  ],
                  _buildStockSection(product),
                  const SizedBox(height: 20),
                  _buildVariantsSection(product),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, Product product) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: const Color(0xFF121826),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeroImage(product),
      ),
    );
  }

  Widget _buildHeroImage(Product product) {
    final url = product.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: const Color(0xFF121826),
        child: const Center(
          child: Icon(Icons.checkroom_rounded, size: 80, color: Color(0xFF3B82F6)),
        ),
      );
    }
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    return Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
      return Container(
        color: const Color(0xFF121826),
        child: const Center(
          child: Icon(Icons.checkroom_rounded, size: 80, color: Color(0xFF3B82F6)),
        ),
      );
    });
  }

  Widget _buildHeader(Product product) {
    final isAvailable = _filteredVariants.any((v) => v.isAvailable);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StockStatusBadge(available: isAvailable),
          ],
        ),
        const SizedBox(height: 12),
        if (product.description.isNotEmpty)
          Text(
            product.description,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
          ),
        const SizedBox(height: 16),
        _buildPriceRow(product),
      ],
    );
  }

  Widget _buildPriceRow(Product product) {
    if (_filteredVariants.isEmpty) {
      return const Text(
        'Sin precio disponible',
        style: TextStyle(color: Color(0xFF94A3B8)),
      );
    }
    final prices = _filteredVariants.map((v) => v.price).toList()..sort();
    final minP = prices.first;
    final maxP = prices.last;
    return Row(
      children: [
        Text(
          minP == maxP
              ? '\$${minP.toStringAsFixed(0)}'
              : '\$${minP.toStringAsFixed(0)} – \$${maxP.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3B82F6),
          ),
        ),
        const Spacer(),
        Text(
          'Stock total: $_totalStockForSelection',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildColorSelector(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Color', _selectedColor),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: product.availableColors.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                      : const Color(0xFF1A2234),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3B82F6) : Colors.white12,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  color,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSizeSelector(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Talla', _selectedSize),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: product.availableSizes.map((size) {
            final isSelected = _selectedSize == size;
            return GestureDetector(
              onTap: () => setState(() => _selectedSize = size),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                      : const Color(0xFF1A2234),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3B82F6) : Colors.white12,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    size,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStockSection(Product product) {
    if (_filteredVariants.isEmpty) return const SizedBox.shrink();

    // Aggregate stock per branch for the filtered variants
    final branchMap = <String, int>{};
    for (final variant in _filteredVariants) {
      for (final stock in variant.stocks) {
        branchMap[stock.branchName] = (branchMap[stock.branchName] ?? 0) + stock.quantity;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2234),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.store_outlined, color: Color(0xFF3B82F6), size: 18),
              SizedBox(width: 8),
              Text(
                'Disponibilidad por sucursal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (branchMap.isEmpty)
            const Text(
              'Sin información de stock',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            )
          else
            ...branchMap.entries.map(
              (entry) => _BranchStockRow(
                branchName: entry.key,
                quantity: entry.value,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVariantsSection(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Variantes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._filteredVariants.map((v) => _VariantTile(variant: v)),
        if (_filteredVariants.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2234),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 18),
                SizedBox(width: 8),
                Text(
                  'No hay variantes para esta combinación',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title, String? selected) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        if (selected != null) ...[
          const SizedBox(width: 8),
          Text(
            selected,
            style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 14),
          ),
        ],
      ],
    );
  }
}

class _StockStatusBadge extends StatelessWidget {
  final bool available;
  const _StockStatusBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: available
            ? const Color(0xFF22C55E).withValues(alpha: 0.15)
            : const Color(0xFFEF4444).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: available
              ? const Color(0xFF22C55E).withValues(alpha: 0.4)
              : const Color(0xFFEF4444).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: available ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            available ? 'Disponible' : 'Agotado',
            style: TextStyle(
              color: available ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchStockRow extends StatelessWidget {
  final String branchName;
  final int quantity;

  const _BranchStockRow({required this.branchName, required this.quantity});

  @override
  Widget build(BuildContext context) {
    final isLow = quantity > 0 && quantity <= 5;
    final isOut = quantity == 0;

    Color quantityColor;
    if (isOut) {
      quantityColor = const Color(0xFFF87171);
    } else if (isLow) {
      quantityColor = const Color(0xFFFBBF24);
    } else {
      quantityColor = const Color(0xFF4ADE80);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              branchName,
              style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: quantityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: quantityColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              isOut ? 'Sin stock' : '$quantity uds.',
              style: TextStyle(
                color: quantityColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantTile extends StatelessWidget {
  final ProductVariant variant;
  const _VariantTile({required this.variant});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2234),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: variant.isAvailable ? Colors.white10 : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${variant.color} · Talla ${variant.size}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: variant.isAvailable ? Colors.white : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SKU: ${variant.sku}',
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${variant.price.toStringAsFixed(0)}',
                style: TextStyle(
                  color: variant.isAvailable ? const Color(0xFF3B82F6) : const Color(0xFF475569),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${variant.totalStock} en stock',
                style: TextStyle(
                  color: variant.isAvailable ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
