import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modelos/carrito.dart';
import 'package:mobile/modelos/venta_mayor.dart';
import 'package:mobile/servicios/sin_conexion_service.dart';
import 'package:mobile/servicios/almacen_sin_conexion.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'Offline quantity updates apply and remove the same wholesale discount',
    () async {
      final store = await AlmacenSinConexion.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final offline = SinConexionService(
        store,
        (_, _, _) async => throw StateError('No network expected'),
      );
      await offline.activate('api|bulk-user');
      offline.offline = true;
      await store.write('api|bulk-user', '/cart', {
        'items': [
          {
            'id': 'item',
            'variant_id': 'variant',
            'quantity': 12,
            'price': 10,
            'subtotal': 120,
          },
        ],
        'total_items': 12,
        'total_amount': 120,
      });
      await offline.mutate('PUT', '/cart/items/item', {'quantity': 13});
      final discounted = await offline.read('/cart', () async => null);
      expect(discounted['total_amount'], 110.5);
      expect(discounted['wholesale_discount_percent'], 15);
      await offline.mutate('PUT', '/cart/items/item', {'quantity': 12});
      final normal = await offline.read('/cart', () async => null);
      expect(normal['total_amount'], 120);
      expect(normal['wholesale_discount_percent'], 0);
      offline.dispose();
      await store.db.close();
    },
  );
  for (final quantity in [12, 13, 26, 52]) {
    test(
      'Wholesale: $quantity garments use one 15% discount from thirteen',
      () {
        final summary = resumenVentaMayor(quantity * 10.0, quantity);
        expect(summary['wholesale_discount_percent'], quantity >= 13 ? 15 : 0);
        expect(
          summary['total_amount'],
          quantity >= 13 ? quantity * 8.5 : quantity * 10.0,
        );
        final cart = CarritoResponse.fromJson({
          ...summary,
          'items': [],
          'total_items': quantity,
        });
        expect(cart.wholesaleDiscountPercent, quantity >= 13 ? 15 : 0);
        expect(cart.totalAmount, summary['total_amount']);
      },
    );
  }
}
