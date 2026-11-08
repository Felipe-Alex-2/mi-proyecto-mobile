class ReservaItem {
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
  final double? originalPrice;
  final String? imageUrl;

  ReservaItem({
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
    this.originalPrice,
    this.imageUrl,
  });

  factory ReservaItem.fromJson(Map<String, dynamic> json) {
    return ReservaItem(
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
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      imageUrl: json['image_url'],
    );
  }
}

class Reserva {
  final String? tenantId;
  final String? companyName;
  final String id;
  final String reservationCode;
  final String? exchangeCode;
  final DateTime? receiptIssuedAt;
  final DateTime? exchangeDeadline;
  final String currency;
  final double? subtotalBeforeWholesale;
  final int wholesaleDiscountPercent;
  final int couponDiscountPercent;
  final double couponDiscountAmount;
  final double wholesaleDiscountAmount;
  final String customerId;
  final String branchId;
  final String status;
  final String? customerNotes;
  final String? staffNotes;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<ReservaItem> items;
  final String? customerName;
  final String? branchName;
  final String? branchAddress;
  final int totalItems;
  final double totalEstimatedAmount;

  final String? paymentMethod;
  final String paymentStatus;
  final String? paypalOrderId;
  final String? paypalCaptureId;
  final DateTime? paidAt;
  final double? totalAmount;

  Reserva({
    this.tenantId,
    this.companyName,
    required this.id,
    required this.reservationCode,
    this.exchangeCode,
    this.receiptIssuedAt,
    this.exchangeDeadline,
    this.currency = 'USD',
    this.subtotalBeforeWholesale,
    this.wholesaleDiscountPercent = 0,
    this.couponDiscountPercent = 0,
    this.couponDiscountAmount = 0,
    this.wholesaleDiscountAmount = 0,
    required this.customerId,
    required this.branchId,
    required this.status,
    this.paymentMethod,
    this.paymentStatus = 'PENDING',
    this.paypalOrderId,
    this.paypalCaptureId,
    this.paidAt,
    this.totalAmount,
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

  factory Reserva.fromJson(Map<String, dynamic> json) {
    return Reserva(
      tenantId: json["tenant_id"],
      companyName: json["company_name"],
      id: json['id'] ?? '',
      reservationCode: json['reservation_code'] ?? '',
      exchangeCode: json['exchange_code'],
      receiptIssuedAt: _serverDate(json['receipt_issued_at']),
      exchangeDeadline: _serverDate(json['exchange_deadline']),
      currency: json['currency'] ?? 'USD',
      subtotalBeforeWholesale: (json['subtotal_before_wholesale'] as num?)
          ?.toDouble(),
      couponDiscountPercent:
          (json['coupon_discount_percent'] as num?)?.toInt() ?? 0,
      couponDiscountAmount:
          (json['coupon_discount_amount'] as num?)?.toDouble() ?? 0,
      wholesaleDiscountPercent:
          (json['wholesale_discount_percent'] as num?)?.toInt() ?? 0,
      wholesaleDiscountAmount:
          (json['wholesale_discount_amount'] as num?)?.toDouble() ?? 0,
      customerId: json['customer_id'] ?? '',
      branchId: json['branch_id'] ?? '',
      status: json['status'] ?? 'PENDING',
      paymentMethod: json['payment_method'],
      paymentStatus: json['payment_status'] ?? 'PENDING',
      paypalOrderId: json['paypal_order_id'],
      paypalCaptureId: json['paypal_capture_id'],
      paidAt: _serverDate(json['paid_at']),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      customerNotes: json['customer_notes'],
      staffNotes: json['staff_notes'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ?? DateTime.now(),
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (item) => ReservaItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      customerName: json['customer_name'],
      branchName: json['branch_name'],
      branchAddress: json['branch_address'],
      totalItems: json['total_items'] ?? 0,
      totalEstimatedAmount:
          (json['total_estimated_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static DateTime? _serverDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final hasZone = RegExp(
      r'(Z|[+-]\d{2}:\d{2})$',
      caseSensitive: false,
    ).hasMatch(value);
    return DateTime.tryParse(hasZone ? value : '${value}Z');
  }

  String get changeCode =>
      (exchangeCode?.isNotEmpty ?? false) ? exchangeCode! : reservationCode;
  DateTime? get receiptDate => receiptIssuedAt ?? paidAt;
  DateTime? get changeDeadline =>
      exchangeDeadline ?? receiptDate?.add(const Duration(hours: 48));

  bool get isPending => status == 'PENDING' || status == 'SYNC_PENDING';
  bool get isLocal => id.startsWith('local:');
  bool get syncPending =>
      isLocal ||
      status == 'SYNC_PENDING' ||
      status == 'SYNC_FAILED' ||
      status == 'CANCEL_PENDING' ||
      paymentStatus == 'SYNC_PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isExpired => status == 'EXPIRED';
  bool get isPaid => paymentStatus == 'PAID';
  bool get isPaypal => paymentMethod == 'PAYPAL';
  bool get isCash => paymentMethod == 'EFECTIVO';
}

class SucursalOption {
  final String id;
  final String name;
  final String city;
  final String address;

  SucursalOption({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
  });

  factory SucursalOption.fromJson(Map<String, dynamic> json) {
    return SucursalOption(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      address: json['address'] ?? '',
    );
  }
}
