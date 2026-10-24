import 'producto.dart';

class RecomendacionInterpretation {
  final String? category;
  final String? color;
  final String? season;
  final String? gender;
  final String? size;
  final String? search;

  const RecomendacionInterpretation({
    this.category,
    this.color,
    this.season,
    this.gender,
    this.size,
    this.search,
  });

  factory RecomendacionInterpretation.fromJson(Map<String, dynamic> json) {
    return RecomendacionInterpretation(
      category: json['category']?.toString(),
      color: json['color']?.toString(),
      season: json['season']?.toString(),
      gender: json['gender']?.toString(),
      size: json['size']?.toString(),
      search: json['search']?.toString(),
    );
  }
}

class RecomendacionResponse {
  final String message;
  final RecomendacionInterpretation interpretation;
  final Map<String, String> matchedFilters;
  final List<Producto> recommendations;

  const RecomendacionResponse({
    required this.message,
    required this.interpretation,
    required this.matchedFilters,
    required this.recommendations,
  });

  factory RecomendacionResponse.fromJson(Map<String, dynamic> json) {
    final filtersJson = json['matched_filters'] as Map<String, dynamic>? ?? {};
    final filters = filtersJson.map((k, v) => MapEntry(k, v.toString()));

    final recsJson = json['recommendations'] as List<dynamic>? ?? [];
    final recommendations = recsJson
        .map((p) => Producto.fromJson(p as Map<String, dynamic>))
        .toList();

    return RecomendacionResponse(
      message: json['message']?.toString() ?? 'Recomendaciones generadas',
      interpretation: RecomendacionInterpretation.fromJson(
        json['interpretation'] as Map<String, dynamic>? ?? {},
      ),
      matchedFilters: filters,
      recommendations: recommendations,
    );
  }
}
