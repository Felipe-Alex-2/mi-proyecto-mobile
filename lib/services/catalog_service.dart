import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'api_service.dart';

enum CatalogStatus { idle, loading, loaded, error }

class CatalogService extends ChangeNotifier {
  final ApiService _apiService;

  List<Product> _products = [];
  CatalogStatus _status = CatalogStatus.idle;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategory = 'Todos';

  CatalogService(this._apiService);

  List<Product> get products => _filteredProducts;
  CatalogStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  List<String> get categories {
    final cats = _products.map((p) => p.category).where((c) => c.isNotEmpty).toSet().toList()
      ..sort();
    return ['Todos', ...cats];
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final matchesSearch = _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == 'Todos' || product.category == _selectedCategory;

      return matchesSearch && matchesCategory && product.isActive;
    }).toList();
  }

  Future<void> loadProducts() async {
    if (_status == CatalogStatus.loading) return;

    _status = CatalogStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiService.get('/products') as List<dynamic>;
      _products = data
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
      _status = CatalogStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CatalogStatus.error;
    }

    notifyListeners();
  }

  Future<Product?> getProductDetail(String productId) async {
    try {
      final data = await _apiService.get('/products/$productId');
      return Product.fromJson(data as Map<String, dynamic>);
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

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'Todos';
    notifyListeners();
  }
}
