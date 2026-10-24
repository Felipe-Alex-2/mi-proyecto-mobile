import '../modelos/producto.dart';
import '../modelos/recomendacion.dart';

class AsistenteLocalCatalogo {
  static const _categories = {
    'pantalón': [
      'pantalon',
      'pantalones',
      'jean',
      'jeans',
      'vaquero',
      'vaqueros',
    ],
    'camisa': ['camisa', 'camisas'],
    'blusa': ['blusa', 'blusas'],
    'vestido': ['vestido', 'vestidos'],
    'falda': ['falda', 'faldas'],
    'chaqueta': ['chaqueta', 'chaquetas', 'chamarra', 'chamarras'],
    'abrigo': ['abrigo', 'abrigos'],
    'camiseta': ['camiseta', 'camisetas', 'polera', 'poleras'],
    'suéter': ['sueter', 'sueteres', 'jersey', 'jerseys'],
    'short': ['short', 'shorts', 'bermuda', 'bermudas'],
  };
  static const _colors = {
    'rojo': ['rojo', 'roja', 'rojos', 'rojas'],
    'azul': ['azul', 'azules'],
    'negro': ['negro', 'negra', 'negros', 'negras'],
    'blanco': ['blanco', 'blanca', 'blancos', 'blancas'],
    'verde': ['verde', 'verdes'],
    'gris': ['gris', 'grises'],
    'beige': ['beige', 'arena'],
    'rosa': ['rosa', 'rosado', 'rosada'],
    'marrón': ['marron', 'cafe', 'café'],
    'amarillo': ['amarillo', 'amarilla', 'amarillos', 'amarillas'],
    'morado': ['morado', 'morada', 'violeta', 'lila'],
  };
  static const _stopWords = {
    'quiero',
    'busco',
    'buscas',
    'tienes',
    'tienen',
    'hay',
    'ropa',
    'prenda',
    'prendas',
    'para',
    'con',
    'una',
    'uno',
    'unos',
    'unas',
    'que',
    'del',
    'las',
    'los',
    'por',
    'como',
    'recomienda',
    'recomiendame',
    'necesito',
    'gustan',
    'gusta',
    'algo',
    'catalogo',
    'mostrar',
    'muestra',
    'muestrame',
    'ver',
    'comprar',
    'favor',
    'hola',
    'buenas',
    'buenos',
    'dias',
    'tardes',
    'noches',
    'color',
    'colores',
    'talla',
    'hasta',
    'menos',
    'maximo',
    'presupuesto',
    'barato',
    'barata',
    'baratos',
    'baratas',
    'economico',
    'economica',
    'precio',
    'precios',
    'bolivianos',
    'bob',
  };

  String _normalize(String text) {
    var value = text.toLowerCase();
    const accented = 'áéíóúüñ';
    const plain = 'aeiouun';
    for (var index = 0; index < accented.length; index++) {
      value = value.replaceAll(accented[index], plain[index]);
    }
    return value;
  }

  bool _contains(String text, String term) =>
      RegExp(r'\b' + RegExp.escape(_normalize(term)) + r'\b').hasMatch(text);

  String? _match(String text, Map<String, List<String>> groups) {
    for (final entry in groups.entries) {
      if (entry.value.any((term) => _contains(text, term))) return entry.key;
    }
    return null;
  }

  RecomendacionResponse respond(String message, List<Producto> catalog) {
    final query = _normalize(message.trim());
    final filters = <String, String>{};
    RecomendacionResponse reply(
      String text, [
      List<Producto> products = const [],
    ]) => RecomendacionResponse(
      message: text,
      interpretation: const RecomendacionInterpretation(),
      matchedFilters: filters,
      recommendations: products,
    );

    if (catalog.isEmpty) {
      return reply(
        'Aún no hay un catálogo guardado en este celular. Abre el catálogo con conexión una vez para poder consultarlo offline.',
      );
    }
    if (RegExp(
      r'^(hola|buenas|buenos dias|buenas tardes|buenas noches)[!,.\s]*$',
    ).hasMatch(query)) {
      return reply(
        '¡Hola! Puedo buscar en tu catálogo guardado por prenda, color, talla o presupuesto. Prueba: «pantalón azul talla M hasta 200».',
      );
    }

    final category = _match(query, _categories);
    final color = _match(query, _colors);
    final size = RegExp(r'\btalla\s+(xxs|xs|s|m|l|xxxl|xxl|xl|\d{1,3})\b')
        .firstMatch(query)
        ?.group(1)
        ?.toUpperCase();
    final budgetText = RegExp(
      r'\b(?:menos de|hasta|maximo|presupuesto(?: de)?)\s*(?:bs\.?\s*|bob\s*)?(\d+(?:[.,]\d+)?)',
    ).firstMatch(query)?.group(1);
    final budget = budgetText == null
        ? null
        : double.tryParse(budgetText.replaceAll(',', '.'));
    final gender = _contains(query, 'mujer') || _contains(query, 'dama')
        ? 'mujer'
        : _contains(query, 'hombre') || _contains(query, 'caballero')
        ? 'hombre'
        : null;
    if (category != null) filters['Prenda'] = category;
    if (color != null) filters['Color'] = color;
    if (size != null) filters['Talla'] = size;
    if (budget != null) {
      filters['Presupuesto'] = 'Hasta ${budget.toStringAsFixed(2)}';
    }
    if (gender != null) filters['Para'] = gender;

    String description(Producto product) => _normalize(
      '${product.name} ${product.category} ${product.description}',
    );
    final catalogText = catalog.map(description).join(' ');
    final terms = RegExp(r'[a-z]{3,}')
        .allMatches(query)
        .map((match) => match.group(0)!)
        .where(
          (term) => !_stopWords.contains(term) && _contains(catalogText, term),
        )
        .toSet();
    final browse = RegExp(
      r'\b(catalogo|prendas|ropa|barat[oa]s?|economic[oa]s?)\b',
    ).hasMatch(query);
    if (filters.isEmpty && terms.isEmpty && !browse) {
      return reply(
        'Mi modo local está limitado a buscar ropa del catálogo guardado. Dime una prenda, color, talla o presupuesto; no puedo responder preguntas generales.',
      );
    }

    final matches =
        catalog.where((product) {
          if (!product.isActive || !product.isAvailable) return false;
          final text = description(product);
          if (category != null &&
              !_categories[category]!.any((term) => _contains(text, term))) {
            return false;
          }
          if (gender != null &&
              _normalize(product.gender) != gender &&
              _normalize(product.gender) != 'unisex') {
            return false;
          }
          if (filters.isEmpty &&
              terms.isNotEmpty &&
              !terms.every((term) => _contains(text, term))) {
            return false;
          }
          return product.variants.any((variant) {
            if (!variant.isAvailable) return false;
            if (color != null &&
                !_colors[color]!.any(
                  (term) => _contains(_normalize(variant.color), term),
                )) {
              return false;
            }
            if (size != null && variant.size.trim().toUpperCase() != size) {
              return false;
            }
            final price = variant.price > 0 ? variant.price : product.basePrice;
            return budget == null || price <= budget;
          });
        }).toList()..sort(
          (first, second) => first.minPrice.compareTo(second.minPrice),
        );
    final products = matches.take(6).toList();
    return reply(
      products.isEmpty
          ? 'No encontré prendas con esos datos en el catálogo guardado. Prueba otro color, talla o presupuesto. Puede haber novedades cuando vuelvas a conectarte.'
          : 'Encontré estas prendas en tu catálogo guardado. La disponibilidad y los precios corresponden a la última actualización; se confirmarán al sincronizar.',
      products,
    );
  }
}
