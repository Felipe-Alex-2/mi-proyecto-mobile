import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
import '../../models/biometric_profile.dart';
import 'garment_transparent_processor.dart';

enum FittingViewerMode {
  overlay, // 👗 Prenda sobre ti (vestidor virtual superpuesto interactivo)
  aiResult, // ✨ Look IA (IDM-VTON generativo o simulación)
  userPhoto, // 👤 Mi foto
  garment, // 👕 Prenda catálogo
}

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

  /// Bytes de la imagen generada por IDM-VTON (cuando el try-on real fue exitoso).
  Uint8List? _idmResultBytes;

  bool _isLoadingRecommendation = false;
  bool _isAddingToCart = false;

  /// Modo de visualización del probador virtual
  FittingViewerMode _viewerMode = FittingViewerMode.overlay;

  /// Posición interactiva de la prenda sobre la persona
  Offset _garmentOffset = Offset.zero;

  /// Factor de escala interactivo de la prenda
  double _garmentScale = 1.0;

  /// Nivel de opacidad de la prenda superpuesta (por defecto 96% para visualización realista)
  final double _garmentOpacity = 0.96;

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

    // Obtener perfil biométrico existente (o null)
    final profile = vtonService.profile ?? await vtonService.loadProfile();

    // Preguntar siempre al ingresar sobre sus medidas para calcular su talla ideal
    if (mounted) {
      _promptBiometricMeasurements(profile);
    }
  }

  void _selectProduct(Product product) async {
    setState(() {
      _selectedProduct = product;
      _selectedColor = product.availableColors.isNotEmpty ? product.availableColors.first : null;
      _tryOnResult = null;
      _idmResultBytes = null;
      _garmentOffset = Offset.zero;
      _garmentScale = 1.0;
      _viewerMode = FittingViewerMode.overlay;
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

    // Si el usuario subió su foto, intentamos el try-on real con IDM-VTON
    if (_userImageFile != null) {
      try {
        // Leer bytes de la foto del usuario
        final personBytes = await _userImageFile!.readAsBytes();
        final personFilename = _userImageFile!.name;

        // Obtener los bytes de la imagen de la prenda.
        // Las imágenes del catálogo pueden ser data URIs (base64) o URLs HTTP.
        final garmentUrl = _selectedProduct!.imageUrl;
        if (garmentUrl == null || garmentUrl.isEmpty) {
          throw Exception('El producto no tiene imagen de prenda disponible.');
        }

        Uint8List garmentBytes;
        String garmentFilename;

        if (garmentUrl.startsWith('data:')) {
          // Caso 1: La imagen ya está en base64 (data:image/jpeg;base64,...)
          if (!garmentUrl.contains(',')) {
            throw Exception('Formato de imagen de prenda no válido.');
          }
          final b64Part = garmentUrl.split(',').last;
          garmentBytes = base64Decode(b64Part);

          // Detectar extensión desde el mime type (data:image/jpeg -> .jpg)
          final mimeMatch = RegExp(r'data:image/(\w+);').firstMatch(garmentUrl);
          final ext = mimeMatch?.group(1) ?? 'jpg';
          garmentFilename = 'garment.$ext';
        } else if (garmentUrl.startsWith('http://') || garmentUrl.startsWith('https://')) {
          // Caso 2: URL HTTP normal, descargar la imagen
          final garmentResponse = await HttpClient().getUrl(Uri.parse(garmentUrl));
          final garmentHttpResponse = await garmentResponse.close();
          garmentBytes = Uint8List.fromList(
            await garmentHttpResponse.expand((chunk) => chunk).toList(),
          );
          garmentFilename = garmentUrl.split('/').last.split('?').first;
          if (garmentFilename.isEmpty) garmentFilename = 'garment.jpg';
        } else {
          throw Exception('Formato de URL de prenda no soportado: $garmentUrl');
        }

        // Descripción por defecto con nombre del producto
        final garmentDesc = _selectedProduct!.name;

        final dataUri = await vtonService.tryOnWithIDMVTON(
          personImageBytes: personBytes,
          personFilename: personFilename,
          garmentImageBytes: garmentBytes,
          garmentFilename: garmentFilename.isNotEmpty ? garmentFilename : 'garment.jpg',
          garmentDescription: garmentDesc,
        );

        if (!mounted) return;

        // Extraer bytes del data URI (data:image/webp;base64,...)
        Uint8List? resultBytes;
        if (dataUri.contains(',')) {
          final b64 = dataUri.split(',').last;
          resultBytes = base64Decode(b64);
        }

        setState(() {
          _idmResultBytes = resultBytes;
          _viewerMode = FittingViewerMode.aiResult;
        });

        _openFullScreenViewer();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Try-On generado con IDM-VTON exitosamente! ✨'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      } on HttpException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo descargar la imagen de la prenda: $e'),
            backgroundColor: Colors.orange,
          ),
        );
        // Fallback al try-on simulado
      } catch (e) {
        if (!mounted) return;
        final isServiceDown = e.toString().contains('503') ||
            e.toString().contains('no está disponible') ||
            e.toString().contains('VTON_URL');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isServiceDown
                  ? 'Servicio IDM-VTON no disponible. Usando simulación visual.'
                  : 'Error en IDM-VTON: $e. Usando simulación visual.',
            ),
            backgroundColor: isServiceDown ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        // Fallback al try-on simulado si IDM-VTON falla
      }
    }

    // Fallback: try-on simulado (sin foto real o si IDM-VTON falló)
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
        _idmResultBytes = null; // Limpiar resultado IDM anterior
        _viewerMode = FittingViewerMode.aiResult;
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
            tooltip: 'Ajustar mis medidas biométricas',
            onPressed: () {
              _promptBiometricMeasurements(profile);
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
          idmResultBytes: _idmResultBytes,
          initialViewerMode: _viewerMode,
          selectedSize: _selectedSize,
          initialOffset: _garmentOffset,
          initialScale: _garmentScale,
          onAddToCart: _addToCart,
          onPickImage: _pickImage,
        ),
      ),
    );
  }

  /// Calcula la posición anatómica inicial por categoría de catálogo
  Map<String, dynamic> _getGarmentPositioning(Product? product) {
    if (product == null) {
      return {'alignment': const Alignment(0.0, -0.18), 'heightFraction': 0.46};
    }
    final text = '${product.category} ${product.name}'.toLowerCase();
    if (text.contains('pantal') ||
        text.contains('jean') ||
        text.contains('short') ||
        text.contains('falda') ||
        text.contains('bermuda') ||
        text.contains('pants')) {
      // Prenda inferior: piernas / cintura hacia abajo
      return {'alignment': const Alignment(0.0, 0.48), 'heightFraction': 0.50};
    }
    if (text.contains('vestid') ||
        text.contains('enteriz') ||
        text.contains('overol') ||
        text.contains('traje')) {
      // Prenda completa: desde hombros hasta rodillas
      return {'alignment': const Alignment(0.0, 0.08), 'heightFraction': 0.72};
    }
    if (text.contains('zapato') ||
        text.contains('zapatilla') ||
        text.contains('bota') ||
        text.contains('sandalia')) {
      // Calzado: pies
      return {'alignment': const Alignment(0.0, 0.88), 'heightFraction': 0.22};
    }
    // Prenda superior (polera, camisa, blusa, casaca, top, hoodie, chompa)
    return {'alignment': const Alignment(0.0, -0.22), 'heightFraction': 0.46};
  }

  /// Helper para cargar imagen de prenda garantizando formato PNG sin fondo
  Widget _buildGarmentImage(String? imageUrl, {BoxFit fit = BoxFit.contain, bool removeWhiteBg = true}) {
    return TransparentGarmentWidget(
      imageUrl: imageUrl,
      fit: fit,
      removeWhiteBg: removeWhiteBg,
    );
  }

  Widget _buildMeasurementInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.brown),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11, color: AppTheme.brownMedium),
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(icon, size: 16, color: AppTheme.terracotta),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Requerido';
        final n = double.tryParse(val.trim());
        if (n == null || n <= 0) return 'Inválido';
        return null;
      },
    );
  }

  Future<void> _promptBiometricMeasurements(BiometricProfile? existingProfile) async {
    final vtonService = context.read<VirtualFittingService>();
    String selectedGender = (existingProfile?.gender.toUpperCase() == 'MUJER') ? 'MUJER' : 'HOMBRE';
    final heightCtrl = TextEditingController(text: (existingProfile?.heightCm ?? 172.0).toStringAsFixed(0));
    final weightCtrl = TextEditingController(text: (existingProfile?.weightKg ?? 70.0).toStringAsFixed(0));
    final chestCtrl = TextEditingController(text: (existingProfile?.chestCm ?? 95.0).toStringAsFixed(0));
    final waistCtrl = TextEditingController(text: (existingProfile?.waistCm ?? 82.0).toStringAsFixed(0));
    final hipCtrl = TextEditingController(text: (existingProfile?.hipCm ?? 98.0).toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.terracotta.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.straighten_rounded, color: AppTheme.terracotta, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '📏 Tu Talla Ideal con IA',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.brown,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Confirma tus medidas para calcular tu talla perfecta:',
                                  style: TextStyle(fontSize: 12, color: AppTheme.brownMedium),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Gender selector
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Hombre 👔')),
                              selected: selectedGender == 'HOMBRE',
                              selectedColor: AppTheme.terracotta.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                color: selectedGender == 'HOMBRE' ? AppTheme.terracotta : AppTheme.brown,
                                fontWeight: selectedGender == 'HOMBRE' ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedGender = 'HOMBRE');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Mujer 👗')),
                              selected: selectedGender == 'MUJER',
                              selectedColor: AppTheme.terracotta.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                color: selectedGender == 'MUJER' ? AppTheme.terracotta : AppTheme.brown,
                                fontWeight: selectedGender == 'MUJER' ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedGender = 'MUJER');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Altura y Peso
                      Row(
                        children: [
                          Expanded(
                            child: _buildMeasurementInput(
                              label: 'Altura (cm)',
                              controller: heightCtrl,
                              icon: Icons.height_rounded,
                              hint: '172',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMeasurementInput(
                              label: 'Peso (kg)',
                              controller: weightCtrl,
                              icon: Icons.fitness_center_rounded,
                              hint: '70',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Pecho, Cintura, Cadera
                      Row(
                        children: [
                          Expanded(
                            child: _buildMeasurementInput(
                              label: 'Pecho (cm)',
                              controller: chestCtrl,
                              icon: Icons.accessibility_new_rounded,
                              hint: '95',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMeasurementInput(
                              label: 'Cintura (cm)',
                              controller: waistCtrl,
                              icon: Icons.donut_small_rounded,
                              hint: '82',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMeasurementInput(
                              label: 'Cadera (cm)',
                              controller: hipCtrl,
                              icon: Icons.airline_seat_legroom_reduced_rounded,
                              hint: '98',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Botón principal
                      ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                        label: const Text(
                          'Calcular Talla y Probar Prendas',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.terracotta,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(sheetContext);

                          final messenger = ScaffoldMessenger.of(this.context);
                          final newProfile = BiometricProfile(
                            gender: selectedGender,
                            heightCm: double.tryParse(heightCtrl.text.trim()) ?? 172.0,
                            weightKg: double.tryParse(weightCtrl.text.trim()) ?? 70.0,
                            chestCm: double.tryParse(chestCtrl.text.trim()) ?? 95.0,
                            waistCm: double.tryParse(waistCtrl.text.trim()) ?? 82.0,
                            hipCm: double.tryParse(hipCtrl.text.trim()) ?? 98.0,
                          );

                          await vtonService.saveProfile(newProfile);

                          if (!mounted) return;

                          if (_selectedProduct != null) {
                            _selectProduct(_selectedProduct!);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('📏 Talla calculada para ${selectedGender.toLowerCase()}: ${_selectedSize ?? "M"}'),
                                backgroundColor: AppTheme.terracotta,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                      ),

                      if (existingProfile != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(
                            'Continuar con medidas guardadas (${existingProfile.heightCm.toInt()}cm, ${existingProfile.weightKg.toInt()}kg)',
                            style: const TextStyle(color: AppTheme.brownMedium, fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Silueta y maniquí estilizado cuando el usuario aún no cargó su foto
  Widget _buildHumanSilhouette(VirtualFittingService vtonService) {
    final profile = vtonService.profile;
    return Container(
      color: const Color(0xFF1E1B18),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: [Color(0xFF352B24), Color(0xFF13100E)],
              ),
            ),
          ),
          Opacity(
            opacity: 0.22,
            child: Icon(
              Icons.accessibility_new_rounded,
              size: 270,
              color: AppTheme.terracotta.withValues(alpha: 0.8),
            ),
          ),
          Positioned(
            bottom: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    profile != null
                        ? 'Modelo Biométrico: Altura ${profile.heightCm} cm • Pecho ${profile.chestCm} cm'
                        : 'Silueta del Vestidor Virtual',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                  label: const Text('Subir mi foto para calzar prendas', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.terracotta.withValues(alpha: 0.9),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Capa interactiva antepuesta de la prenda PNG con arrastre táctil y escala
  Widget _buildDraggableGarmentOverlay({required double containerHeight}) {
    final pos = _getGarmentPositioning(_selectedProduct);
    final Alignment defaultAlignment = pos['alignment'] as Alignment;
    final double heightFraction = pos['heightFraction'] as double;
    final double baseHeight = containerHeight * heightFraction;

    return Center(
      child: Transform.translate(
        offset: _garmentOffset,
        child: Transform.scale(
          scale: _garmentScale,
          child: Align(
            alignment: defaultAlignment,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _garmentOffset += details.delta;
                });
              },
              child: Opacity(
                opacity: _garmentOpacity,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: baseHeight,
                    maxWidth: 290,
                  ),
                  child: _buildGarmentImage(_selectedProduct?.imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Botón tipo pill para seleccionar el modo de visualización
  Widget _buildModePill({
    required String label,
    required FittingViewerMode mode,
  }) {
    final isSelected = _viewerMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewerMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.terracotta : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Botón de acción para tomar o subir foto de la persona
  Widget _buildPhotoActionButton() {
    return PopupMenuButton<ImageSource>(
      tooltip: 'Subir mi foto',
      onSelected: _pickImage,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: ImageSource.camera,
          child: Row(
            children: [
              Icon(Icons.camera_alt_outlined, color: AppTheme.terracotta, size: 18),
              SizedBox(width: 8),
              Text('Tomar Foto'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: ImageSource.gallery,
          child: Row(
            children: [
              Icon(Icons.photo_library_outlined, color: AppTheme.terracotta, size: 18),
              SizedBox(width: 8),
              Text('Elegir de Galería'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_a_photo_rounded, size: 14, color: AppTheme.terracotta),
            const SizedBox(width: 5),
            Text(
              _userImageFile != null ? 'Cambiar Foto' : 'Subir Foto',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brown),
            ),
          ],
        ),
      ),
    );
  }

  /// Contenido de fondo según el modo activo
  Widget _buildViewerContent(bool hasAiResult, bool hasIdmResult) {
    final vtonService = context.read<VirtualFittingService>();
    final garmentImg = _selectedProduct?.imageUrl;

    switch (_viewerMode) {
      case FittingViewerMode.overlay:
        // Vestidor Virtual: la persona de fondo (o avatar)
        if (_userImageFile != null) {
          return Image.file(
            File(_userImageFile!.path),
            fit: BoxFit.cover,
          );
        }
        return _buildHumanSilhouette(vtonService);

      case FittingViewerMode.aiResult:
        if (hasIdmResult) {
          return Image.memory(
            _idmResultBytes!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildGarmentImage(garmentImg),
          );
        }
        if (_tryOnResult != null) {
          return Image.network(
            _tryOnResult!.resultImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildGarmentImage(garmentImg),
          );
        }
        return _buildGarmentImage(garmentImg);

      case FittingViewerMode.userPhoto:
        if (_userImageFile != null) {
          return Image.file(
            File(_userImageFile!.path),
            fit: BoxFit.cover,
          );
        }
        return _buildHumanSilhouette(vtonService);

      case FittingViewerMode.garment:
        return Container(
          color: const Color(0xFF1E1B18),
          padding: const EdgeInsets.all(24),
          child: _buildGarmentImage(garmentImg, fit: BoxFit.contain),
        );
    }
  }

  Widget _buildTryOnViewer(bool isProcessing) {
    final hasIdmResult = _idmResultBytes != null && _idmResultBytes!.isNotEmpty;
    final hasAiResult = hasIdmResult || _tryOnResult != null;
    final hasUserPhoto = _userImageFile != null;

    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Capa de Contenido / Fondo según el modo
            Positioned.fill(
              child: _buildViewerContent(hasAiResult, hasIdmResult),
            ),

            // 2. Capa Prenda PNG Superpuesta e interactiva sobre la persona
            if (_viewerMode == FittingViewerMode.overlay && _selectedProduct != null)
              Positioned.fill(
                child: _buildDraggableGarmentOverlay(containerHeight: 420),
              ),

            // 3. Indicador de Procesamiento IA
            if (isProcessing)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
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

            // 4. Selector de Modos de Visualización (Pills en la parte superior izquierda)
            if (!isProcessing)
              Positioned(
                top: 12,
                left: 12,
                right: 120,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModePill(
                          label: '👗 Prenda sobre ti',
                          mode: FittingViewerMode.overlay,
                        ),
                        if (hasAiResult)
                          _buildModePill(
                            label: '✨ Look IA',
                            mode: FittingViewerMode.aiResult,
                          ),
                        if (hasUserPhoto)
                          _buildModePill(
                            label: '👤 Mi Foto',
                            mode: FittingViewerMode.userPhoto,
                          ),
                        _buildModePill(
                          label: '👕 Prenda',
                          mode: FittingViewerMode.garment,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 5. Botón flotante para cambiar foto del usuario (superior derecha)
            Positioned(
              top: 12,
              right: 12,
              child: _buildPhotoActionButton(),
            ),

            // 6. Controles interactivos de ajuste de la prenda antepuesta (Zoom +, Zoom -, Centrar)
            if (_viewerMode == FittingViewerMode.overlay && !isProcessing && _selectedProduct != null)
              Positioned(
                right: 12,
                bottom: 74,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        tooltip: 'Agrandar prenda',
                        onPressed: () {
                          setState(() {
                            if (_garmentScale < 2.2) _garmentScale += 0.08;
                          });
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 20),
                        tooltip: 'Reducir prenda',
                        onPressed: () {
                          setState(() {
                            if (_garmentScale > 0.5) _garmentScale -= 0.08;
                          });
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.restart_alt_rounded, color: Colors.white, size: 20),
                        tooltip: 'Centrar prenda',
                        onPressed: () {
                          setState(() {
                            _garmentOffset = Offset.zero;
                            _garmentScale = 1.0;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // 7. Hint de arrastre táctil (cuando está en modo overlay)
            if (_viewerMode == FittingViewerMode.overlay && !isProcessing)
              Positioned(
                bottom: 76,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, color: Colors.white70, size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Arrastra para calzar la prenda',
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

            // 8. Información inferior sobre la prenda activa y botones de acción
            if (!isProcessing && _selectedProduct != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.88),
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedProduct!.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '\$ ${_selectedProduct!.basePrice.toStringAsFixed(2)} • ${_selectedProduct!.category}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 24),
                        tooltip: 'Pantalla completa',
                        onPressed: _openFullScreenViewer,
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: isProcessing ? null : _runVirtualTryOn,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                        label: const Text('Look IA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.terracotta,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
  /// Bytes de la imagen generada por IDM-VTON (prioridad sobre tryOnResult URL).
  final Uint8List? idmResultBytes;
  final FittingViewerMode initialViewerMode;
  final String? selectedSize;
  final Offset initialOffset;
  final double initialScale;
  final VoidCallback onAddToCart;
  final Future<void> Function(ImageSource source)? onPickImage;

  const FullScreenVtonViewer({
    super.key,
    required this.product,
    required this.userImageFile,
    required this.tryOnResult,
    this.idmResultBytes,
    required this.initialViewerMode,
    required this.selectedSize,
    this.initialOffset = Offset.zero,
    this.initialScale = 1.0,
    required this.onAddToCart,
    this.onPickImage,
  });

  @override
  State<FullScreenVtonViewer> createState() => _FullScreenVtonViewerState();
}

class _FullScreenVtonViewerState extends State<FullScreenVtonViewer> {
  late FittingViewerMode _viewerMode;
  late Offset _garmentOffset;
  late double _garmentScale;

  @override
  void initState() {
    super.initState();
    _viewerMode = widget.initialViewerMode;
    _garmentOffset = widget.initialOffset;
    _garmentScale = widget.initialScale;
  }

  Map<String, dynamic> _getGarmentPositioning(Product? product) {
    if (product == null) {
      return {'alignment': const Alignment(0.0, -0.18), 'heightFraction': 0.46};
    }
    final text = '${product.category} ${product.name}'.toLowerCase();
    if (text.contains('pantal') ||
        text.contains('jean') ||
        text.contains('short') ||
        text.contains('falda') ||
        text.contains('bermuda') ||
        text.contains('pants')) {
      return {'alignment': const Alignment(0.0, 0.48), 'heightFraction': 0.52};
    }
    if (text.contains('vestid') ||
        text.contains('enteriz') ||
        text.contains('overol') ||
        text.contains('traje')) {
      return {'alignment': const Alignment(0.0, 0.08), 'heightFraction': 0.74};
    }
    if (text.contains('zapato') ||
        text.contains('zapatilla') ||
        text.contains('bota') ||
        text.contains('sandalia')) {
      return {'alignment': const Alignment(0.0, 0.88), 'heightFraction': 0.22};
    }
    return {'alignment': const Alignment(0.0, -0.22), 'heightFraction': 0.46};
  }

  Widget _buildGarmentImage(String? imageUrl, {BoxFit fit = BoxFit.contain, bool removeWhiteBg = true}) {
    return TransparentGarmentWidget(
      imageUrl: imageUrl,
      fit: fit,
      removeWhiteBg: removeWhiteBg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasIdmResult = widget.idmResultBytes != null && widget.idmResultBytes!.isNotEmpty;
    final hasAiResult = hasIdmResult || widget.tryOnResult != null;
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
          if (widget.onPickImage != null)
            PopupMenuButton<ImageSource>(
              tooltip: 'Subir o cambiar foto',
              onSelected: (source) async {
                await widget.onPickImage!(source);
                if (mounted) setState(() {});
              },
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: ImageSource.camera,
                  child: Row(
                    children: [
                      Icon(Icons.camera_alt_outlined, color: AppTheme.terracotta, size: 18),
                      SizedBox(width: 8),
                      Text('Tomar Foto'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: ImageSource.gallery,
                  child: Row(
                    children: [
                      Icon(Icons.photo_library_outlined, color: AppTheme.terracotta, size: 18),
                      SizedBox(width: 8),
                      Text('Elegir de Galería'),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  hasUserPhoto ? Icons.edit_rounded : Icons.add_a_photo_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final pos = _getGarmentPositioning(widget.product);
          final Alignment defaultAlignment = pos['alignment'] as Alignment;
          final double heightFraction = pos['heightFraction'] as double;
          final double baseHeight = h * heightFraction;

          return Stack(
            children: [
              // 1. Capa de Fondo (Persona / Look IA / Prenda)
              Positioned.fill(
                child: _buildMainViewerContent(garmentImg, hasAiResult, hasIdmResult),
              ),

              // 2. Capa Prenda PNG Superpuesta e interactiva sobre la persona
              if (_viewerMode == FittingViewerMode.overlay && widget.product != null)
                Positioned.fill(
                  child: Center(
                    child: Transform.translate(
                      offset: _garmentOffset,
                      child: Transform.scale(
                        scale: _garmentScale,
                        child: Align(
                          alignment: defaultAlignment,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _garmentOffset += details.delta;
                              });
                            },
                            child: Container(
                              constraints: BoxConstraints(
                                maxHeight: baseHeight,
                                maxWidth: 360,
                              ),
                              child: _buildGarmentImage(garmentImg, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Selector de Modo en Barra Flotante Superior
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPill('👗 Prenda sobre ti', FittingViewerMode.overlay),
                          if (hasAiResult)
                            _buildPill('✨ Look IA', FittingViewerMode.aiResult),
                          if (hasUserPhoto)
                            _buildPill('👤 Mi Foto', FittingViewerMode.userPhoto),
                          _buildPill('👕 Prenda', FittingViewerMode.garment),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Controles flotantes de escala y recentrado en modo overlay
              if (_viewerMode == FittingViewerMode.overlay && widget.product != null)
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                          tooltip: 'Agrandar prenda',
                          onPressed: () {
                            setState(() {
                              if (_garmentScale < 2.5) _garmentScale += 0.08;
                            });
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 22),
                          tooltip: 'Reducir prenda',
                          onPressed: () {
                            setState(() {
                              if (_garmentScale > 0.4) _garmentScale -= 0.08;
                            });
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.restart_alt_rounded, color: Colors.white, size: 22),
                          tooltip: 'Centrar prenda',
                          onPressed: () {
                            setState(() {
                              _garmentOffset = Offset.zero;
                              _garmentScale = 1.0;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. Hint inferior en modo overlay
              if (_viewerMode == FittingViewerMode.overlay)
                Positioned(
                  bottom: 96,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, color: Colors.white70, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Arrastra con el dedo para calzar la prenda',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),

              // 6. Barra flotante inferior con información y botón de compra
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
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
          );
        },
      ),
    );
  }

  Widget _buildPill(String label, FittingViewerMode mode) {
    final isSel = _viewerMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewerMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? AppTheme.terracotta : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMainViewerContent(String? garmentImg, bool hasAiResult, bool hasIdmResult) {
    switch (_viewerMode) {
      case FittingViewerMode.overlay:
        if (widget.userImageFile != null) {
          return Image.file(
            File(widget.userImageFile!.path),
            fit: BoxFit.contain,
          );
        }
        return Container(
          color: const Color(0xFF141210),
          child: const Center(
            child: Icon(Icons.accessibility_new_rounded, size: 300, color: Colors.white12),
          ),
        );

      case FittingViewerMode.aiResult:
        if (hasIdmResult) {
          return Image.memory(
            widget.idmResultBytes!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildGarmentImage(garmentImg),
          );
        }
        if (widget.tryOnResult != null) {
          return Image.network(
            widget.tryOnResult!.resultImageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildGarmentImage(garmentImg),
          );
        }
        return _buildGarmentImage(garmentImg);

      case FittingViewerMode.userPhoto:
        if (widget.userImageFile != null) {
          return Image.file(
            File(widget.userImageFile!.path),
            fit: BoxFit.contain,
          );
        }
        return const Center(
          child: Icon(Icons.person_rounded, size: 120, color: Colors.white24),
        );

      case FittingViewerMode.garment:
        return Center(
          child: _buildGarmentImage(garmentImg, fit: BoxFit.contain),
        );
    }
  }
}
