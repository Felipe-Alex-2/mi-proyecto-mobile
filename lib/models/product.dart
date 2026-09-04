class Stock {
  final String id;
  final String branchId;
  final String branchName;
  final int quantity;

  const Stock({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.quantity,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      id: json['id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? 'Sucursal',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProductVariant {
  final String id;
  final String sku;
  final String color;
  final String size;
  final double price;
  final List<Stock> stocks;

  const ProductVariant({
    required this.id,
    required this.sku,
    required this.color,
    required this.size,
    required this.price,
    required this.stocks,
  });

  int get totalStock => stocks.fold(0, (sum, s) => sum + s.quantity);

  bool get isAvailable => totalStock > 0;

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final stocksJson = json['stocks'] as List<dynamic>? ?? [];
    return ProductVariant(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stocks: stocksJson.map((s) => Stock.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final String category;
  final String? imageUrl;
  final bool isActive;
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.imageUrl,
    required this.isActive,
    required this.variants,
  });

  int get totalStock => variants.fold(0, (sum, v) => sum + v.totalStock);

  bool get isAvailable => totalStock > 0;

  double get minPrice {
    if (variants.isEmpty) return 0;
    return variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
  }

  double get maxPrice {
    if (variants.isEmpty) return 0;
    return variants.map((v) => v.price).reduce((a, b) => a > b ? a : b);
  }

  List<String> get availableColors =>
      variants.map((v) => v.color).where((c) => c.isNotEmpty).toSet().toList();

  List<String> get availableSizes =>
      variants.map((v) => v.size).where((s) => s.isNotEmpty).toSet().toList();

  factory Product.fromJson(Map<String, dynamic> json) {
    final variantsJson = json['variants'] as List<dynamic>? ?? [];
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      variants: variantsJson
          .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}
