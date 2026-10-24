import 'package:flutter/foundation.dart';

import '../modelos/producto.dart';
import 'api_service.dart';

enum CatalogStatus { idle, loading, loaded, error }

class CatalogoService extends ChangeNotifier {
  final ApiService _apiService;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<Producto> _products = [];
  CatalogStatus _status = CatalogStatus.idle;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  String _selectedGender = 'Todos';
  String _sortBy = 'newest';
  double? _minPrice;
  double? _maxPrice;

  CatalogoService(this._apiService);

  List<Producto> get products => _filteredProducts;
  CatalogStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get selectedGender => _selectedGender;
  String get sortBy => _sortBy;
  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;

  List<String> get categories {
    final cats =
        _products
            .map((p) => p.category)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['Todos', ...cats];
  }

  List<Producto> get _filteredProducts {
    var list = _products.where((product) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.variants.any(
            (v) => v.sku.toLowerCase().contains(_searchQuery.toLowerCase()),
          );

      final matchesCategory =
          _selectedCategory == 'Todos' || product.category == _selectedCategory;

      final matchesGender =
          _selectedGender == 'Todos' ||
          product.gender.toLowerCase() == _selectedGender.toLowerCase() ||
          product.gender.toLowerCase() == 'unisex';

      final matchesMin = _minPrice == null || product.maxPrice >= _minPrice!;
      final matchesMax = _maxPrice == null || product.minPrice <= _maxPrice!;

      return matchesSearch &&
          matchesCategory &&
          matchesGender &&
          matchesMin &&
          matchesMax &&
          product.isActive;
    }).toList();

    if (_sortBy == 'price_asc') {
      list.sort((a, b) => a.minPrice.compareTo(b.minPrice));
    } else if (_sortBy == 'price_desc') {
      list.sort((a, b) => b.maxPrice.compareTo(a.maxPrice));
    } else if (_sortBy == 'name_asc') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return list;
  }

  Future<void> loadProducts() async {
    if (_status == CatalogStatus.loading) return;

    _status = CatalogStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiService.get('/products') as List<dynamic>;
      _products = data
          .map((item) => Producto.fromJson(item as Map<String, dynamic>))
          .toList();
      _status = CatalogStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CatalogStatus.error;
    }

    notifyListeners();
  }

  Future<Producto?> getProductDetail(String productId) async {
    try {
      final data = await _apiService.get('/products/$productId');
      return Producto.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setGender(String gender) {
    _selectedGender = gender;
    notifyListeners();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void setPriceRange(double? min, double? max) {
    _minPrice = min;
    _maxPrice = max;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'Todos';
    _selectedGender = 'Todos';
    _sortBy = 'newest';
    _minPrice = null;
    _maxPrice = null;
    notifyListeners();
  }
}
