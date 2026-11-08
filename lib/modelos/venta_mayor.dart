Map<String, dynamic> resumenVentaMayor(double subtotal, int cantidad) {
  final centavos = (subtotal * 100).round();
  final porcentaje = cantidad >= 13 ? 15 : 0;
  final descuento = (centavos * porcentaje / 100).round();
  return {
    'subtotal_before_wholesale': centavos / 100,
    'wholesale_discount_percent': porcentaje,
    'wholesale_discount_amount': descuento / 100,
    'total_amount': (centavos - descuento) / 100,
  };
}
