import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

  void _showReservationSheet(
    BuildContext context,
    CartResponse cart, {
    String initialPaymentMethod = 'PAYPAL',
  }) async {
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
    String selectedPaymentMethod = initialPaymentMethod; // 'PAYPAL' or 'EFECTIVO'
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
            final isPayPal = selectedPaymentMethod == 'PAYPAL';
            final selectedBranch = branches.firstWhere(
              (b) => b.id == selectedBranchId,
              orElse: () => branches.first,
            );

            return SingleChildScrollView(
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
                        'Confirmar Pedido / Reserva',
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
                  const SizedBox(height: 6),
                  Text(
                    'Prendas: ${cart.totalItems} | Total: Bs ${cart.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppTheme.brownMedium, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  // Branch selector
                  const Text(
                    '1. Selecciona la sucursal de retiro *',
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
                  const SizedBox(height: 18),

                  // Payment method selector
                  const Text(
                    '2. Modalidad de Pago *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.brown),
                  ),
                  const SizedBox(height: 10),

                  // PayPal Option
                  InkWell(
                    onTap: () {
                      setSheetState(() {
                        selectedPaymentMethod = 'PAYPAL';
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPayPal ? const Color(0xFF0070BA).withValues(alpha: 0.08) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPayPal ? const Color(0xFF0070BA) : Colors.grey.shade300,
                          width: isPayPal ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPayPal ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isPayPal ? const Color(0xFF0070BA) : Colors.grey.shade400,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Row(
                                  children: [
                                    Icon(Icons.payment_rounded, color: Color(0xFF0070BA), size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Pagar por PayPal (Sandbox)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF0070BA),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Paga en línea con tu cuenta Sandbox. Tu reserva quedará pagada y lista para recoger en la sucursal.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.brownMedium),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // In-Store / Cash Option
                  InkWell(
                    onTap: () {
                      setSheetState(() {
                        selectedPaymentMethod = 'EFECTIVO';
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !isPayPal ? AppTheme.terracotta.withValues(alpha: 0.08) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !isPayPal ? AppTheme.terracotta : Colors.grey.shade300,
                          width: !isPayPal ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            !isPayPal ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: !isPayPal ? AppTheme.terracotta : Colors.grey.shade400,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Row(
                                  children: [
                                    Icon(Icons.storefront_rounded, color: AppTheme.terracotta, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Reservar para Probar en Tienda',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.brown,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Reserva gratis por 48h sin pago previo. Te pruebas las prendas en sucursal y abonas en caja.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.brownMedium),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  const Text(
                    'Comentarios o notas (Opcional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.brown),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ej. Pasaré por la tarde, separar en mostrador...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  if (sheetError != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sheetError!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
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

                                if (isPayPal) {
                                  // PayPal flow
                                  final orderData = await resService.createPayPalReservationOrder(
                                    branchId: selectedBranchId,
                                    items: itemsPayload,
                                    customerNotes: notesController.text,
                                  );

                                  final approvalUrl = orderData['approval_url'] as String?;
                                  final orderId = orderData['order_id'] as String?;

                                  if (approvalUrl == null || orderId == null) {
                                    throw Exception('No se pudo generar el enlace de pago de PayPal');
                                  }

                                  // Launch PayPal sandbox checkout in external browser
                                  final uri = Uri.parse(approvalUrl);
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);

                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);

                                  // Show pending capture dialog
                                  _showPayPalPendingDialog(
                                    context,
                                    orderId,
                                    selectedBranch.name,
                                    resService,
                                    cartService,
                                  );
                                } else {
                                  // Free store reservation flow
                                  final newRes = await resService.createReservation(
                                    branchId: selectedBranchId,
                                    items: itemsPayload,
                                    customerNotes: notesController.text,
                                  );

                                  await cartService.loadCart();

                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);

                                  _showSuccessDialog(context, newRes, isPaid: false);
                                }
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
                      icon: isSubmitting
                          ? const SizedBox.shrink()
                          : Icon(
                              isPayPal ? Icons.payment_rounded : Icons.check_circle_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                      label: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isPayPal
                                  ? 'Pagar con PayPal (Bs ${cart.totalAmount.toStringAsFixed(2)})'
                                  : 'Confirmar Reserva para Tienda',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPayPal ? const Color(0xFF0070BA) : AppTheme.terracotta,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _showPayPalPendingDialog(
    BuildContext context,
    String orderId,
    String branchName,
    ReservationService resService,
    CartService cartService,
  ) {
    bool isCapturing = false;
    String? captureError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (dlgCtx, setDlgState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: const [
                  Icon(Icons.payment_rounded, color: Color(0xFF0070BA), size: 26),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pago en PayPal Sandbox',
                      style: TextStyle(color: AppTheme.brown, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0070BA).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0070BA).withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF0070BA), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Se abrió PayPal Sandbox en tu navegador para que apruebes el pago con tu cuenta personal de prueba.',
                            style: TextStyle(fontSize: 12, color: AppTheme.brown),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Una vez aprobado el pago en PayPal, presiona el botón a continuación para registrar tu reserva pagada:',
                    style: TextStyle(fontSize: 13, color: AppTheme.brownMedium),
                  ),
                  if (captureError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        captureError!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isCapturing ? null : () => Navigator.pop(dlgCtx),
                  child: const Text('Cancelar', style: TextStyle(color: AppTheme.brownMedium)),
                ),
                ElevatedButton(
                  onPressed: isCapturing
                      ? null
                      : () async {
                          setDlgState(() {
                            isCapturing = true;
                            captureError = null;
                          });
                          try {
                            final capturedRes = await resService.capturePayPalReservationOrder(orderId);
                            await cartService.loadCart();
                            if (!dlgCtx.mounted) return;
                            Navigator.pop(dlgCtx);
                            _showSuccessDialog(context, capturedRes, isPaid: true);
                          } catch (e) {
                            final msg = (e is ApiException) ? e.message : '$e'.replaceAll('Exception: ', '');
                            setDlgState(() {
                              isCapturing = false;
                              captureError = 'Error: $msg';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0070BA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isCapturing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Confirmar y Capturar Pago'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, Reservation r, {bool isPaid = false}) {
    final paid = isPaid || r.isPaid;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  paid ? '¡Pago y Reserva Confirmados!' : '¡Reserva Creada!',
                  style: const TextStyle(color: AppTheme.brown, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: paid ? Colors.green.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: paid ? Colors.green.shade300 : Colors.amber.shade300),
                    ),
                    child: Text(
                      paid ? '✓ Pagado (PayPal)' : '⏳ Pendiente (Pago en Tienda)',
                      style: TextStyle(
                        color: paid ? Colors.green.shade800 : Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Sucursal: ${r.branchName ?? "Seleccionada"}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Total: Bs ${(r.totalAmount ?? r.totalEstimatedAmount).toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: paid ? Colors.green.shade50 : AppTheme.creamLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: paid ? Colors.green.shade200 : AppTheme.creamLight),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      paid ? Icons.store_mall_directory_rounded : Icons.info_outline,
                      color: paid ? Colors.green.shade700 : AppTheme.terracotta,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        paid
                            ? 'Pase por la sucursal ${r.branchName ?? "seleccionada"} a recoger sus prendas ya pagadas.'
                            : 'Presenta este código en la sucursal ${r.branchName ?? "seleccionada"} para que el personal prepare tus prendas para prueba y pago en caja.',
                        style: TextStyle(
                          color: paid ? Colors.green.shade900 : AppTheme.brownMedium,
                          fontSize: 12,
                          fontWeight: paid ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
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
                          onPressed: () => _showReservationSheet(context, cart, initialPaymentMethod: 'PAYPAL'),
                          icon: const Icon(Icons.payment_rounded, size: 18),
                          label: const Text(
                            'Pagar con PayPal (Sandbox)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0070BA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showReservationSheet(context, cart, initialPaymentMethod: 'EFECTIVO'),
                          icon: const Icon(Icons.storefront_rounded, size: 18, color: AppTheme.terracotta),
                          label: const Text(
                            'Reservar para Probar en Tienda (Pagar en tienda)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.terracotta),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.terracotta, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
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


