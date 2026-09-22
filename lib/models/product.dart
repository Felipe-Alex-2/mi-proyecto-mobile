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

  factory ProductVariant.fromJson(Map<String, dynamic> json, {double defaultPrice = 0.0}) {
    final stocksJson = json['stocks'] as List<dynamic>? ?? [];
    // Color can be color_name, color, or Color object
    String colorName = json['color_name']?.toString() ?? json['color']?.toString() ?? '';
    // Size can be size_code, size_name, or size
    String sizeName = json['size_code']?.toString() ?? json['size_name']?.toString() ?? json['size']?.toString() ?? '';
    
    // Price can be price_override, price, or product default price
    double variantPrice = defaultPrice;
    if (json['price_override'] != null) {
      variantPrice = (json['price_override'] as num).toDouble();
    } else if (json['price'] != null && (json['price'] as num).toDouble() > 0) {
      variantPrice = (json['price'] as num).toDouble();
    }

    return ProductVariant(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      color: colorName,
      size: sizeName,
      price: variantPrice,
      stocks: stocksJson.map((s) => Stock.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final String category;
  final double basePrice;
  final String gender;
  final String? imageUrl;
  final bool isActive;
  final String? promotionId;
  final String? promotionName;
  final double? discountPercent;
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.basePrice = 0.0,
    this.gender = 'Unisex',
    this.imageUrl,
    required this.isActive,
    this.promotionId,
    this.promotionName,
    this.discountPercent,
    required this.variants,
  });

  bool get hasDiscount => discountPercent != null && discountPercent! > 0;

  double get discountedPrice {
    if (!hasDiscount) return basePrice;
    return basePrice * (1.0 - (discountPercent! / 100.0));
  }

  int get totalStock => variants.fold(0, (sum, v) => sum + v.totalStock);

  bool get isAvailable => totalStock > 0;

  double get minPrice {
    if (variants.isEmpty) return basePrice;
    final prices = variants.map((v) => v.price > 0 ? v.price : basePrice).toList();
    return prices.reduce((a, b) => a < b ? a : b);
  }

  double get maxPrice {
    if (variants.isEmpty) return basePrice;
    final prices = variants.map((v) => v.price > 0 ? v.price : basePrice).toList();
    return prices.reduce((a, b) => a > b ? a : b);
  }

  List<String> get availableColors =>
      variants.map((v) => v.color).where((c) => c.isNotEmpty).toSet().toList();

  List<String> get availableSizes =>
      variants.map((v) => v.size).where((s) => s.isNotEmpty).toSet().toList();

  factory Product.fromJson(Map<String, dynamic> json) {
    final variantsJson = json['variants'] as List<dynamic>? ?? [];
    final prodPrice = (json['price'] as num?)?.toDouble() ?? 0.0;
    final categoryName = json['category_name']?.toString() ?? json['category']?.toString() ?? '';

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: categoryName,
      basePrice: prodPrice,
      gender: json['gender']?.toString() ?? 'Unisex',
      imageUrl: json['image_url']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      promotionId: json['promotion_id']?.toString(),
      promotionName: json['promotion_name']?.toString(),
      discountPercent: (json['discount_percent'] as num?)?.toDouble(),
      variants: variantsJson
          .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>, defaultPrice: prodPrice))
          .toList(),
    );
  }
}
