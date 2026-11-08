import 'package:flutter/material.dart';

import '../configuracion/tema.dart';
import '../modelos/producto.dart';
import '../pantallas/catalogo/detalle_producto_screen.dart';
import 'foto_producto.dart';

class PrendaCard extends StatelessWidget {
  final Producto product;
  const PrendaCard({super.key, required this.product});

  Color _swatch(String name) => switch (name.toLowerCase().trim()) {
    'blanco' => Colors.white,
    'negro' => const Color(0xFF242424),
    'crema' || 'beige' => const Color(0xFFDDCDB5),
    'café' || 'cafe' || 'marrón' => const Color(0xFF795548),
    'gris' => const Color(0xFF9E9E9E),
    'verde' || 'oliva' => const Color(0xFF72765A),
    'azul' => const Color(0xFF496983),
    'rojo' => const Color(0xFFA34F3D),
    'rosa' => const Color(0xFFD9A5A5),
    'amarillo' => const Color(0xFFD6B55A),
    'lila' || 'morado' => const Color(0xFF9B85AC),
    _ => TemaApp.terracottaLight,
  };

  @override
  Widget build(BuildContext context) {
    final factor = product.hasDiscount
        ? 1 - product.discountPercent! / 100
        : 1.0;
    final min = product.minPrice * factor;
    final max = product.maxPrice * factor;
    final price = min == max
        ? '\$ ${min.toStringAsFixed(2)}'
        : '\$ ${min.toStringAsFixed(2)} – ${max.toStringAsFixed(2)}';
    return Material(
      color: TemaApp.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleProductoScreen(product: product),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FotoProducto(url: product.imageUrl),
                  if (product.hasDiscount)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TemaApp.terracotta,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '-${product.discountPercent!.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (!product.isAvailable)
                    const Positioned(
                      bottom: 8,
                      left: 8,
                      child: Chip(label: Text('Agotado')),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (product.hasDiscount)
                    Text(
                      'Antes \$ ${product.minPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: TemaApp.brownMedium,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  if (product.availableColors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        for (final color in product.availableColors.take(4))
                          Tooltip(
                            message: color,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: _swatch(color),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: TemaApp.brownMedium.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: TemaApp.creamLight,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: !product.isAvailable
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DetalleProductoScreen(product: product),
                        ),
                      ),
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 16),
                label: const Text(
                  'Añadir al carrito',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
