import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../services/cart_service.dart';
import '../../services/reservation_service.dart';
import '../cart/cart_screen.dart';
import '../reservations/reservations_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _selectedColor;
  String? _selectedSize;
  bool _isAddingToCart = false;

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

  ProductVariant? get _selectedVariant {
    final list = _filteredVariants;
    return list.isNotEmpty ? list.first : (widget.product.variants.isNotEmpty ? widget.product.variants.first : null);
  }

  int get _totalStockForSelection =>
      _filteredVariants.fold(0, (sum, v) => sum + v.totalStock);

  void _addToCart() async {
    final variant = _selectedVariant;
    if (variant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una variante disponible')),
      );
      return;
    }

    setState(() => _isAddingToCart = true);
    try {
      await context.read<CartService>().addToCart(variant.id, quantity: 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${widget.product.name} agregada al carrito!'),
          backgroundColor: Colors.green.shade700,
          action: SnackBarAction(
            label: 'Ver Carrito',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agregar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _showReserveDialog() async {
    final variant = _selectedVariant;
    if (variant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una variante disponible para reservar')),
      );
      return;
    }

    final resService = context.read<ReservationService>();
    final branches = await resService.getActiveBranches();
    if (!mounted) return;

    if (branches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sucursales disponibles')),
      );
      return;
    }

    String selectedBranchId = branches.first.id;
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reservar para Prueba en Tienda',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.brown),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.brownMedium),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prenda: ${widget.product.name} (Talla: ${variant.size}, Color: ${variant.color})',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.terracotta, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text('Sucursal donde deseas probártela *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.brown)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranchId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text('${b.name} (${b.city})'))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedBranchId = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Nota adicional (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.brown)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ej. Pasaré el sábado por la mañana...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              try {
                                final newRes = await resService.createReservation(
                                  branchId: selectedBranchId,
                                  items: [
                                    {'variant_id': variant.id, 'quantity': 1}
                                  ],
                                  customerNotes: notesCtrl.text,
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);

                                showDialog(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    backgroundColor: AppTheme.surface,
                                    title: const Text('¡Reserva Confirmada!'),
                                    content: Text('Código: ${newRes.reservationCode}\nTus prendas estarán reservadas por 48 horas.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(dCtx);
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ReservationsScreen()));
                                        },
                                        child: const Text('Ver Mis Reservas', style: TextStyle(color: AppTheme.terracotta, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.terracotta,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Confirmar Reserva', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: AppTheme.cream,
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
                  _buildBranchAvailabilitySection(),
                  const SizedBox(height: 20),
                  _buildVariantsSection(product),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildStickyBottomBar(),
    );
  }

  Widget _buildStickyBottomBar() {
    final hasStock = _totalStockForSelection > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Reserve button (CU13)
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: hasStock ? _showReserveDialog : null,
                icon: const Icon(Icons.event_seat_rounded, size: 18),
                label: const Text('Reservar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.terracotta,
                  side: const BorderSide(color: AppTheme.terracotta),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Add to Cart button (CU12)
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: hasStock && !_isAddingToCart ? _addToCart : null,
                icon: _isAddingToCart
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                label: Text(
                  hasStock ? 'Agregar al Carrito' : 'Agotado',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.terracotta,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, Product product) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppTheme.surface,
      foregroundColor: AppTheme.brown,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
          tooltip: 'Ir al Carrito',
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(background: _buildHeroImage(product)),
    );
  }

  Widget _buildHeroImage(Product product) {
    final url = product.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: AppTheme.creamLight,
        child: const Center(
          child: Icon(Icons.checkroom_rounded, size: 80, color: AppTheme.terracotta),
        ),
      );
    }
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return Container(color: AppTheme.creamLight);
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: AppTheme.creamLight,
        child: const Icon(Icons.checkroom_rounded, size: 80, color: AppTheme.terracotta),
      ),
    );
  }

  Widget _buildHeader(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.category.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.terracotta.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              product.category.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.terracotta,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          product.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.brown),
        ),
        if (product.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(product.description, style: const TextStyle(color: AppTheme.brownMedium, fontSize: 14, height: 1.4)),
        ],
        const SizedBox(height: 16),
        _buildPriceRow(product),
      ],
    );
  }

  Widget _buildPriceRow(Product product) {
    if (_filteredVariants.isEmpty) {
      return const Text('Sin precio disponible', style: TextStyle(color: AppTheme.brownMedium));
    }
    final prices = _filteredVariants.map((v) => v.price).toList()..sort();
    final minP = prices.first;
    final maxP = prices.last;

    return Row(
      children: [
        // Price displayed in Bolivianos (Bs)
        Text(
          minP == maxP
              ? 'Bs ${minP.toStringAsFixed(2)}'
              : 'Bs ${minP.toStringAsFixed(2)} – Bs ${maxP.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.terracotta),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _totalStockForSelection > 0 ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _totalStockForSelection > 0 ? Colors.green.shade300 : Colors.red.shade300),
          ),
          child: Text(
            _totalStockForSelection > 0 ? '$_totalStockForSelection en stock' : 'Sin stock',
            style: TextStyle(
              color: _totalStockForSelection > 0 ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
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
                  color: isSelected ? AppTheme.terracotta.withValues(alpha: 0.1) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.terracotta : AppTheme.creamLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  color,
                  style: TextStyle(
                    color: isSelected ? AppTheme.terracotta : AppTheme.brown,
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.terracotta : AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? AppTheme.terracotta : AppTheme.creamLight),
                ),
                child: Text(
                  size,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.brown,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBranchAvailabilitySection() {
    final variant = _selectedVariant;
    if (variant == null || variant.stocks.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.creamLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.storefront_rounded, size: 18, color: AppTheme.terracotta),
              SizedBox(width: 6),
              Text(
                'Disponibilidad por Sucursal (CU10)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.brown),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...variant.stocks.map((s) {
            final isAvailable = s.quantity > 0;
            final isLow = s.quantity > 0 && s.quantity <= 5;
            final badgeColor = !isAvailable
                ? Colors.red.shade700
                : (isLow ? Colors.orange.shade800 : Colors.green.shade700);
            final badgeText = !isAvailable
                ? 'Sin stock'
                : (isLow ? 'Pocas unidades (${s.quantity})' : 'Disponible (${s.quantity} uds.)');

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.branchName, style: const TextStyle(fontSize: 13, color: AppTheme.brown)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVariantsSection(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Variantes disponibles (${product.variants.length})', null),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: product.variants.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final variant = product.variants[index];
            return _VariantTile(variant: variant);
          },
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, String? selected) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.brown)),
        if (selected != null) ...[
          const SizedBox(width: 8),
          Text(selected, style: const TextStyle(color: AppTheme.terracotta, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ],
    );
  }
}

class _VariantTile extends StatelessWidget {
  final ProductVariant variant;

  const _VariantTile({required this.variant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.creamLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${variant.color} · Talla ${variant.size}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.brown, fontSize: 13),
                ),
                Text('SKU: ${variant.sku}', style: const TextStyle(color: AppTheme.brownMedium, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Price in Bs
              Text(
                'Bs ${variant.price.toStringAsFixed(2)}',
                style: const TextStyle(color: AppTheme.terracotta, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '${variant.totalStock} uds.',
                style: TextStyle(
                  color: variant.isAvailable ? Colors.green.shade700 : Colors.red.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


