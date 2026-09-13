class CartItem {
  final String id;
  final String variantId;
  final int quantity;
  final String? productId;
  final String? productName;
  final String? sku;
  final String? sizeName;
  final String? colorName;
  final String? colorHex;
  final double price;
  final double subtotal;
  final String? imageUrl;
  final int availableStock;

  CartItem({
    required this.id,
    required this.variantId,
    required this.quantity,
    this.productId,
    this.productName,
    this.sku,
    this.sizeName,
    this.colorName,
    this.colorHex,
    required this.price,
    required this.subtotal,
    this.imageUrl,
    this.availableStock = 0,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] ?? '',
      variantId: json['variant_id'] ?? '',
      quantity: json['quantity'] ?? 1,
      productId: json['product_id'],
      productName: json['product_name'],
      sku: json['sku'],
      sizeName: json['size_name'],
      colorName: json['color_name'],
      colorHex: json['color_hex'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'],
      availableStock: json['available_stock'] ?? 0,
    );
  }
}

class CartResponse {
  final List<CartItem> items;
  final int totalItems;
  final double totalAmount;

  CartResponse({
    required this.items,
    required this.totalItems,
    required this.totalAmount,
  });

  factory CartResponse.fromJson(Map<String, dynamic> json) {
    return CartResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => CartItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalItems: json['total_items'] ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
