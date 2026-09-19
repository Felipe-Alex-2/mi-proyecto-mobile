import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/cart.dart';
import '../../models/reservation.dart';
import '../../services/api_service.dart';
import '../../services/cart_service.dart';
import '../../services/reservation_service.dart';
import '../reservations/reservations_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartService>().loadCart();
    });
  }

  void _showReservationSheet(BuildContext context, CartResponse cart) async {
    final resService = context.read<ReservationService>();
    final cartService = context.read<CartService>();

    // Load active branches
    final branches = await resService.getActiveBranches();
    if (!context.mounted) return;

    if (branches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sucursales disponibles en este momento')),
      );
      return;
    }

    String selectedBranchId = branches.first.id;
    final notesController = TextEditingController();
    bool isSubmitting = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
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
                        'Reservar para Prueba (CU13)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.brown,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.brownMedium),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Podrás probarte las ${cart.totalItems} prendas en la sucursal seleccionada durante 48 horas sin costo.',
                    style: const TextStyle(color: AppTheme.brownMedium, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Selecciona la sucursal *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.brown),
                  ),
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
                      return DropdownMenuItem(
                        value: b.id,
                        child: Text('${b.name} (${b.city})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          selectedBranchId = val;
                          sheetError = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Comentarios o notas (Opcional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.brown),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ej. Pasaré por la tarde, talla ajustada...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              sheetError!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() {
                                isSubmitting = true;
                                sheetError = null;
                              });
                              try {
                                final itemsPayload = cart.items
                                    .map((it) => {
                                          'variant_id': it.variantId,
                                          'quantity': it.quantity,
                                        })
                                    .toList();

                                final newRes = await resService.createReservation(
                                  branchId: selectedBranchId,
                                  items: itemsPayload,
                                  customerNotes: notesController.text,
                                );

                                // Reload cart as reserved items were cleared
                                await cartService.loadCart();

                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);

                                _showSuccessDialog(context, newRes);
                              } catch (e) {
                                final cleanErr = (e is ApiException)
                                    ? e.message
                                    : '$e'
                                        .replaceAll('Exception: ', '')
                                        .replaceAll('ApiException: ', '');
                                setSheetState(() {
                                  isSubmitting = false;
                                  sheetError = cleanErr;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(cleanErr),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.terracotta,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Confirmar Reserva Gratuita',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
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

  void _showSuccessDialog(BuildContext context, Reservation r) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('¡Reserva Creada!', style: TextStyle(color: AppTheme.brown, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Código de Reserva: ${r.reservationCode}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.terracotta),
              ),
              const SizedBox(height: 8),
              Text('Sucursal: ${r.branchName ?? "Seleccionada"}'),
              const SizedBox(height: 4),
              Text('Total estimado: Bs ${r.totalEstimatedAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              const Text(
                'Presenta este código en la tienda física para que el personal prepare tus prendas para prueba en probador.',
                style: TextStyle(color: AppTheme.brownMedium, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReservationsScreen()),
                );
              },
              child: const Text('Ver Mis Reservas', style: TextStyle(color: AppTheme.terracotta, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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
            Icon(Icons.shopping_bag_outlined, color: AppTheme.terracotta, size: 22),
            SizedBox(width: 8),
            Text(
              'Mi Carrito (CU12)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.brown),
            ),
          ],
        ),
        actions: [
          Consumer<CartService>(
            builder: (_, cartService, _) {
              if (cartService.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.brownMedium),
                tooltip: 'Vaciar carrito',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text('¿Vaciar carrito?'),
                      content: const Text('Se eliminarán todas las prendas añadidas.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    cartService.clearCart();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<CartService>(
        builder: (context, cartService, _) {
          if (cartService.isLoading && cartService.cart == null) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.terracotta));
          }

          final cart = cartService.cart;
          if (cart == null || cart.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 72, color: AppTheme.brownMedium.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    const Text(
                      'Tu carrito está vacío',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.brown),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Explora el catálogo y agrega prendas que desees probar o comprar en tienda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.brownMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return _CartItemCard(
                      item: item,
                      onIncrement: () => cartService.updateQuantity(item.id, item.quantity + 1),
                      onDecrement: () {
                        if (item.quantity > 1) {
                          cartService.updateQuantity(item.id, item.quantity - 1);
                        } else {
                          cartService.removeItem(item.id);
                        }
                      },
                      onQuantityChanged: (newQty) {
                        if (newQty <= 0) {
                          cartService.removeItem(item.id);
                        } else {
                          cartService.updateQuantity(item.id, newQty);
                        }
                      },
                      onRemove: () => cartService.removeItem(item.id),
                    );
                  },
                ),
              ),

              // Bottom Summary & Reserve CTA
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total estimado:',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.brownMedium),
                          ),
                          Text(
                            'Bs ${cart.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.terracotta),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showReservationSheet(context, cart),
                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                          label: const Text(
                            'Reservar para Probar en Tienda',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.terracotta,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  Future<void> _showQuantityDialog(
    BuildContext context,
    CartItem item,
    ValueChanged<int> onQuantityChanged,
  ) async {
    final controller = TextEditingController(text: '${item.quantity}');
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          item.productName ?? 'Modificar cantidad',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.brown),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa la cantidad deseada (solo números):',
              style: TextStyle(fontSize: 13, color: AppTheme.brownMedium),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.brown),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: '1',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.terracotta, width: 2),
                ),
              ),
              onSubmitted: (val) {
                final numVal = int.tryParse(val.trim());
                if (numVal != null) {
                  Navigator.pop(ctx, numVal);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.brownMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final numVal = int.tryParse(controller.text.trim());
              if (numVal != null) {
                Navigator.pop(ctx, numVal);
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (result != null) {
      onQuantityChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.creamLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / Icon
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 70,
              height: 70,
              color: AppTheme.creamLight,
              child: _buildItemImage(item.imageUrl),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName ?? 'Prenda',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.brown),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Talla: ${item.sizeName ?? "N/A"} · Color: ${item.colorName ?? "N/A"}',
                  style: const TextStyle(color: AppTheme.brownMedium, fontSize: 12),
                ),
                if (item.sku != null)
                  Text(
                    'SKU: ${item.sku}',
                    style: const TextStyle(color: AppTheme.brownMedium, fontSize: 11),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Bs ${item.price.toStringAsFixed(2)} c/u',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.terracotta, fontSize: 13),
                ),
              ],
            ),
          ),

          // Quantity controls & Remove
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.brownMedium),
                onPressed: onRemove,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QtyButton(icon: Icons.remove, onPressed: onDecrement),
                  InkWell(
                    onTap: () => _showQuantityDialog(context, item, onQuantityChanged),
                    borderRadius: BorderRadius.circular(6),
                    child: Tooltip(
                      message: 'Toca para escribir cantidad',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.creamLight.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.brownMedium.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.brown,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _QtyButton(icon: Icons.add, onPressed: onIncrement),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(String? url) {
    if (url == null || url.isEmpty) {
      return const Icon(Icons.checkroom_rounded, color: AppTheme.terracotta, size: 32);
    }
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return const Icon(Icons.checkroom_rounded, color: AppTheme.terracotta, size: 32);
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.checkroom_rounded, color: AppTheme.terracotta, size: 32),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _QtyButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppTheme.creamLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 14, color: AppTheme.brown),
        onPressed: onPressed,
      ),
    );
  }
}


