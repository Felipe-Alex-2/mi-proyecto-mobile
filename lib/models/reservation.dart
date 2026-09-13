class ReservationItem {
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
  final String? imageUrl;

  ReservationItem({
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
    this.imageUrl,
  });

  factory ReservationItem.fromJson(Map<String, dynamic> json) {
    return ReservationItem(
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
      imageUrl: json['image_url'],
    );
  }
}

class Reservation {
  final String id;
  final String reservationCode;
  final String customerId;
  final String branchId;
  final String status;
  final String? customerNotes;
  final String? staffNotes;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<ReservationItem> items;
  final String? customerName;
  final String? branchName;
  final String? branchAddress;
  final int totalItems;
  final double totalEstimatedAmount;

  Reservation({
    required this.id,
    required this.reservationCode,
    required this.customerId,
    required this.branchId,
    required this.status,
    this.customerNotes,
    this.staffNotes,
    required this.createdAt,
    required this.expiresAt,
    required this.items,
    this.customerName,
    this.branchName,
    this.branchAddress,
    required this.totalItems,
    required this.totalEstimatedAmount,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] ?? '',
      reservationCode: json['reservation_code'] ?? '',
      customerId: json['customer_id'] ?? '',
      branchId: json['branch_id'] ?? '',
      status: json['status'] ?? 'PENDING',
      customerNotes: json['customer_notes'],
      staffNotes: json['staff_notes'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ?? DateTime.now(),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => ReservationItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      customerName: json['customer_name'],
      branchName: json['branch_name'],
      branchAddress: json['branch_address'],
      totalItems: json['total_items'] ?? 0,
      totalEstimatedAmount: (json['total_estimated_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isExpired => status == 'EXPIRED';
}

class BranchOption {
  final String id;
  final String name;
  final String city;
  final String address;

  BranchOption({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
  });

  factory BranchOption.fromJson(Map<String, dynamic> json) {
    return BranchOption(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      address: json['address'] ?? '',
    );
  }
}
