class DetalleAjusteItem {
  final String zone;
  final String fitStatus;
  final double differenceCm;
  final String message;

  DetalleAjusteItem({
    required this.zone,
    required this.fitStatus,
    required this.differenceCm,
    required this.message,
  });

  factory DetalleAjusteItem.fromJson(Map<String, dynamic> json) {
    return DetalleAjusteItem(
      zone: json['zone'] as String? ?? 'General',
      fitStatus: json['fit_status'] as String? ?? 'IDEAL',
      differenceCm: (json['difference_cm'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String? ?? '',
    );
  }
}

class RecomendacionTalla {
  final String recommendedSize;
  final double confidenceScore;
  final String fitOverall;
  final List<DetalleAjusteItem> fitDetails;
  final String? suggestedVariantId;

  RecomendacionTalla({
    required this.recommendedSize,
    required this.confidenceScore,
    required this.fitOverall,
    required this.fitDetails,
    this.suggestedVariantId,
  });

  factory RecomendacionTalla.fromJson(Map<String, dynamic> json) {
    return RecomendacionTalla(
      recommendedSize: json['recommended_size'] as String? ?? 'M',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 90.0,
      fitOverall: json['fit_overall'] as String? ?? '',
      fitDetails: (json['fit_details'] as List<dynamic>?)
              ?.map((item) => DetalleAjusteItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      suggestedVariantId: json['suggested_variant_id'] as String?,
    );
  }
}

class VestidorVirtualResult {
  final String sessionId;
  final String resultImageUrl;
  final String? userImageUrl;
  final String? garmentImageUrl;
  final String recommendedSize;
  final double confidenceScore;
  final String fitFeedback;
  final List<DetalleAjusteItem> fitDetails;
  final String productId;
  final String? variantId;

  VestidorVirtualResult({
    required this.sessionId,
    required this.resultImageUrl,
    this.userImageUrl,
    this.garmentImageUrl,
    required this.recommendedSize,
    required this.confidenceScore,
    required this.fitFeedback,
    required this.fitDetails,
    required this.productId,
    this.variantId,
  });

  factory VestidorVirtualResult.fromJson(Map<String, dynamic> json) {
    return VestidorVirtualResult(
      sessionId: json['session_id'] as String? ?? '',
      resultImageUrl: json['result_image_url'] as String? ?? '',
      userImageUrl: json['user_image_url'] as String?,
      garmentImageUrl: json['garment_image_url'] as String?,
      recommendedSize: json['recommended_size'] as String? ?? 'M',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 90.0,
      fitFeedback: json['fit_feedback'] as String? ?? '',
      fitDetails: (json['fit_details'] as List<dynamic>?)
              ?.map((item) => DetalleAjusteItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      productId: json['product_id'] as String? ?? '',
      variantId: json['variant_id'] as String?,
    );
  }
}
