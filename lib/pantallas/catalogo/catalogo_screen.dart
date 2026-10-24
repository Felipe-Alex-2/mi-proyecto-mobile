import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../configuracion/tema.dart';
import '../../servicios/catalogo_service.dart';
import '../../widgets/prenda_card.dart';

class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final catalog = context.read<CatalogoService>();
      if (catalog.status == CatalogStatus.idle ||
          catalog.status == CatalogStatus.error) {
        catalog.loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterModal(BuildContext context) {
    final catalog = context.read<CatalogoService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: TemaApp.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtros Avanzados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: TemaApp.brown,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          catalog.clearFilters();
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Limpiar',
                          style: TextStyle(color: TemaApp.terracotta),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Género',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: TemaApp.brownMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Todos', 'Hombre', 'Mujer', 'Unisex'].map((g) {
                      final isSelected = catalog.selectedGender == g;
                      return ChoiceChip(
                        label: Text(g),
                        selected: isSelected,
                        selectedColor: TemaApp.terracotta,
                        backgroundColor: TemaApp.creamLight,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : TemaApp.brownMedium,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (_) {
                          catalog.setGender(g);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ordenar por',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: TemaApp.brownMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                          {'key': 'newest', 'label': 'Más recientes'},
                          {
                            'key': 'price_asc',
                            'label': 'Precio: menor a mayor',
                          },
                          {
                            'key': 'price_desc',
                            'label': 'Precio: mayor a menor',
                          },
                          {'key': 'name_asc', 'label': 'Nombre A-Z'},
                        ].map((s) {
                          final isSelected = catalog.sortBy == s['key'];
                          return ChoiceChip(
                            label: Text(s['label']!),
                            selected: isSelected,
                            selectedColor: TemaApp.terracotta,
                            backgroundColor: TemaApp.creamLight,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : TemaApp.brownMedium,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) {
                              catalog.setSortBy(s['key']!);
                              setModalState(() {});
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TemaApp.terracotta,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Aplicar Filtros',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.creamLight,
      appBar: AppBar(
        backgroundColor: TemaApp.creamLight,
        elevation: 0,
        foregroundColor: TemaApp.brown,
        title: Text(
          'Catálogo',
          style: TemaApp.editorial.copyWith(fontSize: 32),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: TemaApp.terracotta),
            tooltip: 'Filtros avanzados',
            onPressed: () => _showFilterModal(context),
          ),
          Consumer<CatalogoService>(
            builder: (_, catalog, _) => IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: TemaApp.brownMedium,
              ),
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
    return Consumer<CatalogoService>(
      builder: (_, catalog, _) => Container(
        color: TemaApp.creamLight,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: catalog.setSearch,
                    decoration: InputDecoration(
                      hintText: 'Buscar prendas',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: TemaApp.brownMedium,
                      ),
                      suffixIcon: catalog.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: TemaApp.brownMedium,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                catalog.setSearch('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(
                    Icons.filter_list_rounded,
                    color: TemaApp.terracotta,
                  ),
                  tooltip: 'Filtros',
                  onPressed: () => _showFilterModal(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['Todos', 'Mujer', 'Hombre', 'Unisex'].map((gender) {
                  final selected = catalog.selectedGender == gender;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(gender),
                      selected: selected,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : TemaApp.brownMedium,
                      ),
                      onSelected: (_) => catalog.setGender(gender),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
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
                        selectedColor: TemaApp.terracotta,
                        backgroundColor: TemaApp.creamLight,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : TemaApp.brownMedium,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? TemaApp.terracotta
                              : TemaApp.terracotta.withValues(alpha: 0.2),
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
    return Consumer<CatalogoService>(
      builder: (_, catalog, _) {
        if (catalog.status == CatalogStatus.loading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: TemaApp.terracotta),
                SizedBox(height: 16),
                Text(
                  'Cargando catálogo...',
                  style: TextStyle(color: TemaApp.brownMedium),
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
                    color: TemaApp.brownMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo cargar el catálogo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: TemaApp.brown,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    catalog.errorMessage ?? 'Error desconocido',
                    style: const TextStyle(
                      color: TemaApp.brownMedium,
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
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: TemaApp.brownMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sin resultados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: TemaApp.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    catalog.searchQuery.isNotEmpty
                        ? 'No encontramos prendas para "${catalog.searchQuery}"'
                        : 'No hay prendas disponibles con los filtros actuales.',
                    style: const TextStyle(
                      color: TemaApp.brownMedium,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (catalog.searchQuery.isNotEmpty ||
                      catalog.selectedCategory != 'Todos' ||
                      catalog.selectedGender != 'Todos') ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        _searchController.clear();
                        catalog.clearFilters();
                      },
                      child: const Text('Limpiar filtros'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: TemaApp.terracotta,
          onRefresh: catalog.loadProducts,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width > 650 ? 3 : 2,
              mainAxisExtent:
                  315 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return PrendaCard(product: products[index]);
            },
          ),
        );
      },
    );
  }
}
