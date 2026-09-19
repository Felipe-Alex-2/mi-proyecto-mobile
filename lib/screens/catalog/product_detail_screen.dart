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
  String? _selectedVariantId;
  String? _selectedColor;
  String? _selectedSize;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    final colors = widget.product.availableColors;
    final sizes = widget.product.availableSizes;
    if (colors.isNotEmpty) {
      _selectedColor = colors.first;
    }
    if (sizes.isNotEmpty) {
      _selectedSize = sizes.first;
    }
  }

  List<ProductVariant> get _filteredVariants {
    return widget.product.variants.where((v) {
      final matchColor = _selectedColor == null || v.color.trim().toLowerCase() == _selectedColor!.trim().toLowerCase();
      final matchSize = _selectedSize == null || v.size.trim().toLowerCase() == _selectedSize!.trim().toLowerCase();
      return matchColor && matchSize;
    }).toList();
  }

  ProductVariant? get _selectedVariant {
    if (_selectedVariantId != null) {
      for (final v in widget.product.variants) {
        if (v.id == _selectedVariantId) return v;
      }
    }
    final list = _filteredVariants;
    if (list.isNotEmpty) return list.first;
    return widget.product.variants.isNotEmpty ? widget.product.variants.first : null;
  }

  int get _totalStockForSelection =>
      _filteredVariants.fold(0, (sum, v) => sum + v.totalStock);

  void _showFloatingFeedback({
    required String message,
    required bool isSuccess,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    // Limpia snacks previos para respuesta instantánea
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
          child: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addToCart() async {
    final variant = _selectedVariant;
    if (variant == null) {
      _showFloatingFeedback(
        message: 'Selecciona una variante disponible',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isAddingToCart = true);
    try {
      await context.read<CartService>().addToCart(variant.id, quantity: 1);
      if (!mounted) return;
      _showFloatingFeedback(
        message: '¡${widget.product.name} agregada al carrito!',
        isSuccess: true,
        actionLabel: 'Ver Carrito',
        onAction: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showFloatingFeedback(
        message: 'Error al agregar: $e',
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _showReserveDialog() async {
    final variant = _selectedVariant;
    if (variant == null) {
      _showFloatingFeedback(
        message: 'Selecciona una variante disponible para reservar',
        isSuccess: false,
      );
      return;
    }

    final resService = context.read<ReservationService>();
    final branches = await resService.getActiveBranches();
    if (!mounted) return;

    if (branches.isEmpty) {
      _showFloatingFeedback(
        message: 'No hay sucursales disponibles en este momento',
        isSuccess: false,
      );
      return;
    }

    // Default branch preference: priorizar la que tenga stock de la variante actual
    String selectedBranchId = branches.first.id;
    final branchesWithStock = variant.stocks.where((s) => s.quantity > 0).map((s) => s.branchId).toSet();
    final matchingBranch = branches.firstWhere(
      (b) => branchesWithStock.contains(b.id),
      orElse: () => branches.first,
    );
    selectedBranchId = matchingBranch.id;

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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.terracotta.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.checkroom_rounded, color: AppTheme.terracotta, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.product.name} • Color: ${variant.color} • Talla: ${variant.size}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.terracotta, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Sucursal donde deseas probártela *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.brown)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranchId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.storefront_rounded, color: AppTheme.terracotta, size: 20),
                    ),
                    items: branches.map((b) {
                      final hasLocalStock = branchesWithStock.contains(b.id);
                      return DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          '${b.name} (${b.city})${hasLocalStock ? " • Disponible" : " • Sin stock"}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: hasLocalStock ? FontWeight.bold : FontWeight.normal,
                            color: hasLocalStock ? AppTheme.brown : AppTheme.brownMedium,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedBranchId = val);
                    },
                  ),
                  if (!branchesWithStock.contains(selectedBranchId)) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.red.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Esta sucursal no tiene stock disponible',
                              style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                              if (!branchesWithStock.contains(selectedBranchId)) {
                                _showFloatingFeedback(
                                  message: 'Esta sucursal no tiene stock disponible',
                                  isSuccess: false,
                                );
                                return;
                              }
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

                                if (!mounted) return;
                                showDialog(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    backgroundColor: AppTheme.surface,
                                    title: const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('¡Reserva Confirmada!'),
                                      ],
                                    ),
                                    content: Text('Código: ${newRes.reservationCode}\nTus prendas estarán reservadas por 48 horas en la sucursal seleccionada.'),
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
                                _showFloatingFeedback(
                                  message: '$e',
                                  isSuccess: false,
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
    final curVar = _selectedVariant;
    final curPrice = (curVar != null && curVar.price > 0)
        ? curVar.price
        : (product.basePrice > 0 ? product.basePrice : product.minPrice);
    final availableStock = curVar != null ? curVar.totalStock : _totalStockForSelection;

    return Row(
      children: [
        Text(
          'Bs ${curPrice.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.terracotta),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: availableStock > 0 ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: availableStock > 0 ? Colors.green.shade300 : Colors.red.shade300),
          ),
          child: Text(
            availableStock > 0 ? 'Disponible' : 'No disponible',
            style: TextStyle(
              color: availableStock > 0 ? Colors.green.shade800 : Colors.red.shade800,
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
        _sectionTitle('Seleccionar Color', _selectedColor),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: product.availableColors.map((color) {
            final isSelected = _selectedColor?.trim().toLowerCase() == color.trim().toLowerCase();
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = color;
                  for (final v in widget.product.variants) {
                    if (v.color.trim().toLowerCase() == color.trim().toLowerCase()) {
                      _selectedVariantId = v.id;
                      if (v.size.isNotEmpty) _selectedSize = v.size;
                      break;
                    }
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.terracotta : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.terracotta : AppTheme.creamLight,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.terracotta.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      color,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.brown,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
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
        _sectionTitle('Seleccionar Talla', _selectedSize),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: product.availableSizes.map((size) {
            final isSelected = _selectedSize?.trim().toLowerCase() == size.trim().toLowerCase();
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSize = size;
                  for (final v in widget.product.variants) {
                    final colorMatches = _selectedColor == null || v.color.trim().toLowerCase() == _selectedColor!.trim().toLowerCase();
                    if (v.size.trim().toLowerCase() == size.trim().toLowerCase() && colorMatches) {
                      _selectedVariantId = v.id;
                      if (v.color.isNotEmpty) _selectedColor = v.color;
                      break;
                    }
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.terracotta : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.terracotta : AppTheme.creamLight,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.terracotta.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
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
            final badgeColor = isAvailable ? Colors.green.shade700 : Colors.red.shade700;
            final badgeText = isAvailable ? 'Disponible' : 'No disponible';

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
            final isSelected = _selectedVariant?.id == variant.id;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedVariantId = variant.id;
                  _selectedColor = variant.color.isNotEmpty ? variant.color : null;
                  _selectedSize = variant.size.isNotEmpty ? variant.size : null;
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: _VariantTile(
                variant: variant,
                isSelected: isSelected,
                fallbackPrice: product.basePrice,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, String? selected) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.brown)),
        if (selected != null && selected.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(selected, style: const TextStyle(color: AppTheme.terracotta, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ],
    );
  }
}

class _VariantTile extends StatelessWidget {
  final ProductVariant variant;
  final bool isSelected;
  final double fallbackPrice;

  const _VariantTile({
    required this.variant,
    this.isSelected = false,
    this.fallbackPrice = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.terracotta.withValues(alpha: 0.08) : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppTheme.terracotta : AppTheme.creamLight,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.terracotta),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '${variant.color.isNotEmpty ? variant.color : "Estándar"} · Talla ${variant.size.isNotEmpty ? variant.size : "U"}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.terracotta : AppTheme.brown,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text('SKU: ${variant.sku}', style: const TextStyle(color: AppTheme.brownMedium, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Bs ${(variant.price > 0 ? variant.price : fallbackPrice).toStringAsFixed(2)}',
                style: const TextStyle(color: AppTheme.terracotta, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                variant.isAvailable ? 'Disponible' : 'No disponible',
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
