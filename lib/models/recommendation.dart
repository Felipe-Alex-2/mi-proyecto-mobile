import 'product.dart';

class RecommendationInterpretation {
  final String? category;
  final String? color;
  final String? season;
  final String? gender;
  final String? size;
  final String? search;

  const RecommendationInterpretation({
    this.category,
    this.color,
    this.season,
    this.gender,
    this.size,
    this.search,
  });

  factory RecommendationInterpretation.fromJson(Map<String, dynamic> json) {
    return RecommendationInterpretation(
      category: json['category']?.toString(),
      color: json['color']?.toString(),
      season: json['season']?.toString(),
      gender: json['gender']?.toString(),
      size: json['size']?.toString(),
      search: json['search']?.toString(),
    );
  }
}

class RecommendationResponse {
  final String message;
  final RecommendationInterpretation interpretation;
  final Map<String, String> matchedFilters;
  final List<Product> recommendations;

  const RecommendationResponse({
    required this.message,
    required this.interpretation,
    required this.matchedFilters,
    required this.recommendations,
  });

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) {
    final filtersJson = json['matched_filters'] as Map<String, dynamic>? ?? {};
    final filters = filtersJson.map((k, v) => MapEntry(k, v.toString()));

    final recsJson = json['recommendations'] as List<dynamic>? ?? [];
    final recommendations = recsJson
        .map((p) => Product.fromJson(p as Map<String, dynamic>))
        .toList();

    return RecommendationResponse(
      message: json['message']?.toString() ?? 'Recomendaciones generadas',
      interpretation: RecommendationInterpretation.fromJson(
        json['interpretation'] as Map<String, dynamic>? ?? {},
      ),
      matchedFilters: filters,
      recommendations: recommendations,
    );
  }
}
