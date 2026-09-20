import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../models/virtual_fitting_result.dart';
import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';
import '../../services/virtual_fitting_service.dart';
import '../cart/cart_screen.dart';
import 'biometric_onboarding_screen.dart';

class VirtualFittingRoomScreen extends StatefulWidget {
  final Product? initialProduct;

  const VirtualFittingRoomScreen({super.key, this.initialProduct});

  @override
  State<VirtualFittingRoomScreen> createState() => _VirtualFittingRoomScreenState();
}

class _VirtualFittingRoomScreenState extends State<VirtualFittingRoomScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _userImageFile;
  String? _userImageBase64;

  Product? _selectedProduct;
  String? _selectedColor;
  String? _selectedSize;
  String? _selectedVariantId;

  SizeRecommendation? _recommendation;
  VirtualFittingResult? _tryOnResult;

  bool _isLoadingRecommendation = false;
  bool _isAddingToCart = false;
  bool _showAfter = true; // Selector Antes / Después

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFittingRoom();
    });
  }

  void _initFittingRoom() async {
    final vtonService = context.read<VirtualFittingService>();
    final catalogService = context.read<CatalogService>();

    // Verificar si el usuario tiene perfil biométrico
    final profile = vtonService.profile ?? await vtonService.loadProfile();
    if (profile == null && mounted) {
      // Redirigir a onboarding biométrico si aún no tiene perfil
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const BiometricOnboardingScreen(redirectToFittingRoom: true),
        ),
      );
      return;
    }

    // Cargar catálogo si no está cargado
    if (catalogService.products.isEmpty) {
      await catalogService.loadProducts();
    }

    if (mounted) {
      final products = catalogService.products;
      if (products.isNotEmpty) {
        final prod = widget.initialProduct ?? products.first;
        _selectProduct(prod);
      }
    }
  }

  void _selectProduct(Product product) async {
    setState(() {
      _selectedProduct = product;
      _selectedColor = product.availableColors.isNotEmpty ? product.availableColors.first : null;
      _tryOnResult = null;
      _isLoadingRecommendation = true;
    });

    final vtonService = context.read<VirtualFittingService>();

    try {
      final rec = await vtonService.getRecommendation(productId: product.id);
      if (!mounted) return;

      setState(() {
        _recommendation = rec;
        _selectedSize = rec.recommendedSize;
        _isLoadingRecommendation = false;

        // Auto-seleccionar variante que coincida con color y talla recomendada
        _updateSelectedVariant();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedSize = product.availableSizes.isNotEmpty ? product.availableSizes.first : 'M';
          _isLoadingRecommendation = false;
          _updateSelectedVariant();
        });
      }
    }
  }

  void _updateSelectedVariant() {
    if (_selectedProduct == null) return;
    for (final v in _selectedProduct!.variants) {
      final matchColor = _selectedColor == null || v.color.trim().toLowerCase() == _selectedColor!.trim().toLowerCase();
      final matchSize = _selectedSize == null || v.size.trim().toLowerCase() == _selectedSize!.trim().toLowerCase();
      if (matchColor && matchSize) {
        _selectedVariantId = v.id;
        return;
      }
    }
    if (_selectedProduct!.variants.isNotEmpty) {
      _selectedVariantId = _selectedProduct!.variants.first.id;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _userImageFile = picked;
          _userImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _runVirtualTryOn() async {
    if (_selectedProduct == null) return;

    final vtonService = context.read<VirtualFittingService>();
    try {
      final result = await vtonService.tryOnGarment(
        productId: _selectedProduct!.id,
        variantId: _selectedVariantId,
        userImageBase64: _userImageBase64,
        userImageUrl: _userImageFile?.path,
      );

      if (!mounted) return;
      setState(() {
        _tryOnResult = result;
        _showAfter = true;
      });

      // Abrir en pantalla completa automáticamente al generarse
      _openFullScreenViewer();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Prenda probada con éxito en el Vestidor Virtual!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en la prueba virtual: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addToCart() async {
    if (_selectedVariantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una variante disponible')),
      );
      return;
    }

    setState(() => _isAddingToCart = true);
    try {
      await context.read<CartService>().addToCart(_selectedVariantId!, quantity: 1);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${_selectedProduct?.name} añadida al carrito!'),
          backgroundColor: Colors.green,
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
        SnackBar(content: Text('Error al añadir: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vtonService = context.watch<VirtualFittingService>();
    final catalogService = context.watch<CatalogService>();
    final profile = vtonService.profile;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.face_retouching_natural_rounded, color: AppTheme.terracotta, size: 22),
            SizedBox(width: 8),
            Text(
              'Vestidor Virtual IA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.brown),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.straighten_rounded, color: AppTheme.terracotta),
            tooltip: 'Ajustar mis medidas',
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const BiometricOnboardingScreen(redirectToFittingRoom: false)),
              );
              if (updated == true && _selectedProduct != null) {
                _selectProduct(_selectedProduct!);
              }
            },
          ),
        ],
      ),
      body: vtonService.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.terracotta))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Visor de Imagen Virtual Try-On (Fase 4)
                  _buildTryOnViewer(vtonService.isTryingOn),
                  const SizedBox(height: 18),

                  // 2. Tarjeta de Recomendación de Talla y Fit de IA (Fase 2)
                  _buildRecommendationCard(),
                  const SizedBox(height: 20),

                  // 3. Selector de Prendas del Catálogo (Fase 3)
                  _buildCatalogSelector(catalogService.products),
                  const SizedBox(height: 18),

                  // 4. Selector de Color y Talla (Fase 3)
                  if (_selectedProduct != null) ...[
                    _buildVariantControls(_selectedProduct!),
                    const SizedBox(height: 20),
                  ],

                  // 5. Botón de Compra Directa / Añadir al Carrito (Fase 5)
                  _buildBottomActions(vtonService.isTryingOn),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  void _openFullScreenViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenVtonViewer(
          product: _selectedProduct,
          userImageFile: _userImageFile,
          tryOnResult: _tryOnResult,
          initialShowAfter: _showAfter,
          selectedSize: _selectedSize,
          onAddToCart: _addToCart,
        ),
      ),
    );
  }

  Widget _buildTryOnViewer(bool isProcessing) {
    final hasResult = _tryOnResult != null;
    final garmentImg = _selectedProduct?.imageUrl;

    return GestureDetector(
      onTap: isProcessing ? null : _openFullScreenViewer,
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
            // Imagen de Fondo / Prenda / Resultado
            Positioned.fill(
              child: _userImageFile != null && (!_showAfter || !hasResult)
                  ? Image.file(
                      File(_userImageFile!.path),
                      fit: BoxFit.cover,
                    )
                  : (hasResult && _showAfter
                      ? Image.network(
                          _tryOnResult!.resultImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderGraphic(garmentImg),
                        )
                      : _buildPlaceholderGraphic(garmentImg)),
            ),

            // Overlay degradado para legibilidad
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),

            // Indicador de Estado / Procesando IA
            if (isProcessing)
              Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 3),
                    SizedBox(height: 16),
                    Text(
                      'Ajustando prenda con IA...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Calculando proporciones biométricas y caída de tela',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Selector Antes / Después (si hay resultado)
            if (hasResult && !isProcessing)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleButton(
                        label: 'Prenda',
                        isSelected: !_showAfter,
                        onTap: () => setState(() => _showAfter = false),
                      ),
                      _buildToggleButton(
                        label: 'Look IA ✨',
                        isSelected: _showAfter,
                        onTap: () => setState(() => _showAfter = true),
                      ),
                    ],
                  ),
                ),
              ),

            // Botón flotante para cambiar foto del usuario
            Positioned(
              top: 14,
              right: 14,
              child: PopupMenuButton<ImageSource>(
                tooltip: 'Subir mi foto',
                onSelected: _pickImage,
                color: AppTheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: ImageSource.camera,
                    child: Row(
                      children: [
                        Icon(Icons.camera_alt_outlined, color: AppTheme.terracotta, size: 20),
                        SizedBox(width: 8),
                        Text('Tomar Foto'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: ImageSource.gallery,
                    child: Row(
                      children: [
                        Icon(Icons.photo_library_outlined, color: AppTheme.terracotta, size: 20),
                        SizedBox(width: 8),
                        Text('Elegir de Galería'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_a_photo_rounded, size: 16, color: AppTheme.terracotta),
                      const SizedBox(width: 6),
                      Text(
                        _userImageFile != null ? 'Cambiar Foto' : 'Subir Foto',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.brown),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Información inferior sobre la prenda activa
            if (!isProcessing && _selectedProduct != null)
              Positioned(
                bottom: 14,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedProduct!.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Bs ${_selectedProduct!.basePrice.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: isProcessing ? null : _runVirtualTryOn,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                      label: const Text('Probar con IA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.terracotta,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildPlaceholderGraphic(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.checkroom_rounded, size: 80, color: AppTheme.brownMedium),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.checkroom_rounded, size: 80, color: AppTheme.brownMedium),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.terracotta : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationCard() {
    if (_isLoadingRecommendation) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.terracotta)),
            SizedBox(width: 12),
            Text('IA analizando tus medidas para este producto...', style: TextStyle(color: AppTheme.brownMedium, fontSize: 13)),
          ],
        ),
      );
    }

    final rec = _recommendation;
    if (rec == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.terracotta.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_rounded, color: AppTheme.terracotta, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Talla recomendada: Talla ${rec.recommendedSize}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.brown),
                    ),
                    Text(
                      '${rec.confidenceScore.toStringAsFixed(0)}% porcentaje de confianza biométrica',
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.creamLight),
          const SizedBox(height: 10),

          // Chips de diagnóstico de Fit
          const Text(
            'Simulación de Ajuste Anatómico:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.brownMedium),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: rec.fitDetails.map((detail) {
              Color chipBg;
              Color chipText;
              IconData chipIcon;

              switch (detail.fitStatus) {
                case 'AJUSTADO':
                  chipBg = Colors.orange.shade50;
                  chipText = Colors.orange.shade900;
                  chipIcon = Icons.arrow_downward_rounded;
                  break;
                case 'HOLGADO':
                  chipBg = Colors.blue.shade50;
                  chipText = Colors.blue.shade900;
                  chipIcon = Icons.arrow_upward_rounded;
                  break;
                default:
                  chipBg = Colors.green.shade50;
                  chipText = Colors.green.shade900;
                  chipIcon = Icons.check_circle_rounded;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, size: 14, color: chipText),
                    const SizedBox(width: 4),
                    Text(
                      '${detail.zone}: ${detail.fitStatus}',
                      style: TextStyle(color: chipText, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogSelector(List<Product> products) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Explora Prendas del Catálogo',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.brown),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (ctx, idx) {
              final prod = products[idx];
              final isSelected = _selectedProduct?.id == prod.id;

              return GestureDetector(
                onTap: () => _selectProduct(prod),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppTheme.terracotta : AppTheme.creamLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: prod.imageUrl != null && prod.imageUrl!.isNotEmpty
                            ? Image.network(
                                prod.imageUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.checkroom_rounded, color: AppTheme.terracotta),
                              )
                            : const Icon(Icons.checkroom_rounded, color: AppTheme.terracotta),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          prod.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppTheme.terracotta : AppTheme.brown,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVariantControls(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de Color
        if (product.availableColors.isNotEmpty) ...[
          const Text('Color:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.brown)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: product.availableColors.map((color) {
              final isSel = _selectedColor?.trim().toLowerCase() == color.trim().toLowerCase();
              return ChoiceChip(
                label: Text(color),
                selected: isSel,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedColor = color;
                      _updateSelectedVariant();
                    });
                  }
                },
                selectedColor: AppTheme.terracotta,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : AppTheme.brown,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Selector de Talla (con indicador de IA)
        if (product.availableSizes.isNotEmpty) ...[
          const Text('Talla:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.brown)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: product.availableSizes.map((size) {
              final isSel = _selectedSize?.trim().toLowerCase() == size.trim().toLowerCase();
              final isAiRecommended = _recommendation?.recommendedSize.trim().toLowerCase() == size.trim().toLowerCase();

              return ChoiceChip(
                avatar: isAiRecommended
                    ? const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.amber)
                    : null,
                label: Text(isAiRecommended ? '$size (IA)' : size),
                selected: isSel,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedSize = size;
                      _updateSelectedVariant();
                    });
                  }
                },
                selectedColor: AppTheme.terracotta,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : AppTheme.brown,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomActions(bool isProcessing) {
    return ElevatedButton.icon(
      onPressed: (_isAddingToCart || isProcessing) ? null : _addToCart,
      icon: _isAddingToCart
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
      label: Text(
        _isAddingToCart ? 'Agregando...' : 'Añadir al Carrito (Talla ${_selectedSize ?? "M"})',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.terracotta,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 3,
      ),
    );
  }
}

class FullScreenVtonViewer extends StatefulWidget {
  final Product? product;
  final XFile? userImageFile;
  final VirtualFittingResult? tryOnResult;
  final bool initialShowAfter;
  final String? selectedSize;
  final VoidCallback onAddToCart;

  const FullScreenVtonViewer({
    super.key,
    required this.product,
    required this.userImageFile,
    required this.tryOnResult,
    required this.initialShowAfter,
    required this.selectedSize,
    required this.onAddToCart,
  });

  @override
  State<FullScreenVtonViewer> createState() => _FullScreenVtonViewerState();
}

class _FullScreenVtonViewerState extends State<FullScreenVtonViewer> {
  late bool _showAfter;

  @override
  void initState() {
    super.initState();
    _showAfter = widget.initialShowAfter;
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = widget.tryOnResult != null;
    final hasUserPhoto = widget.userImageFile != null;
    final garmentImg = widget.product?.imageUrl;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          widget.product?.name ?? 'Vestidor Virtual',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (hasResult || hasUserPhoto)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _showAfter = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: !_showAfter ? AppTheme.terracotta : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Prenda',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showAfter = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _showAfter ? AppTheme.terracotta : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Look IA ✨',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Imagen con zoom interactivo
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: _buildMainImage(garmentImg, hasResult),
            ),
          ),

          // Barra flotante inferior con información y botón de compra
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Talla: ${widget.selectedSize ?? "M"}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (widget.tryOnResult != null)
                          Text(
                            '${widget.tryOnResult!.confidenceScore.toStringAsFixed(0)}% coincidencia biométrica',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onAddToCart();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 16),
                    label: const Text('Comprar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.terracotta,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainImage(String? garmentImg, bool hasResult) {
    if (widget.userImageFile != null && (!_showAfter || !hasResult)) {
      return Image.file(
        File(widget.userImageFile!.path),
        fit: BoxFit.contain,
      );
    }

    if (hasResult && _showAfter) {
      return Image.network(
        widget.tryOnResult!.resultImageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _fallbackGraphic(garmentImg),
      );
    }

    return _fallbackGraphic(garmentImg);
  }

  Widget _fallbackGraphic(String? garmentImg) {
    if (garmentImg != null && garmentImg.isNotEmpty) {
      return Image.network(
        garmentImg,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.checkroom_rounded,
          size: 120,
          color: Colors.white54,
        ),
      );
    }
    return const Icon(
      Icons.checkroom_rounded,
      size: 120,
      color: Colors.white54,
    );
  }
}
