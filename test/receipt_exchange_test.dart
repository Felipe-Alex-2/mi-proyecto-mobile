import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modelos/reserva.dart';
import 'package:mobile/pantallas/reservas/widgets/comprobante_pago_sheet.dart';

Reserva receipt(String method, {bool paid = true}) => Reserva.fromJson({
  'id': 'r1',
  'reservation_code': 'RSV-E2C8A6',
  'exchange_code': paid ? 'RSV-E2C8A6' : null,
  'customer_id': 'customer',
  'customer_name': 'Felipe',
  'branch_id': 'branch',
  'status': 'CONFIRMED',
  'payment_method': method,
  'payment_status': paid ? 'PAID' : 'PENDING',
  'paid_at': paid ? '2026-11-07T12:00:00' : null,
  'receipt_issued_at': paid ? '2026-11-07T12:00:00Z' : null,
  'exchange_deadline': paid ? '2026-11-09T12:00:00Z' : null,
  'created_at': '2026-11-06T12:00:00Z',
  'expires_at': '2026-11-08T12:00:00Z',
  'currency': 'USD',
  'total_amount': 50,
  'total_estimated_amount': 50,
  'total_items': 1,
  'items': [
    {
      'id': 'line',
      'variant_id': 'v',
      'quantity': 1,
      'product_name': 'Camisa',
      'price': 50,
    },
  ],
});

void main() {
  for (final method in ['EFECTIVO', 'PAYPAL', 'WALLET']) {
    testWidgets(
      'Paid $method receipt shows the stable change code and 48-hour policy',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final value = receipt(method);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ComprobantePagoDialog(reservation: value)),
          ),
        );
        expect(find.text('CÓDIGO PARA CAMBIOS / DEVOLUCIONES'), findsOneWidget);
        expect(find.text('RSV-E2C8A6'), findsOneWidget);
        expect(find.text('PAGO CONFIRMADO · $method'), findsOneWidget);
        expect(
          find.textContaining('48 horas desde la emisión'),
          findsOneWidget,
        );
        expect(value.receiptDate, DateTime.utc(2026, 11, 7, 12));
        expect(value.changeDeadline, DateTime.utc(2026, 11, 9, 12));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Pending cash reservation does not claim to be paid or offer a valid change receipt',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComprobantePagoDialog(
              reservation: receipt('EFECTIVO', paid: false),
            ),
          ),
        ),
      );
      expect(find.text('RESERVA · PAGO PENDIENTE'), findsOneWidget);
      expect(find.text('CÓDIGO PARA CAMBIOS / DEVOLUCIONES'), findsNothing);
    },
  );
  test('An older paid receipt keeps its code and paid timestamp instead of the opening time', () {
    final value = Reserva.fromJson({
      'reservation_code': 'RSV-OLD',
      'payment_status': 'PAID',
      'paid_at': '2026-11-07T12:00:00',
    });
    expect(value.changeCode, 'RSV-OLD');
    expect(value.receiptDate, DateTime.utc(2026, 11, 7, 12));
    expect(value.changeDeadline, DateTime.utc(2026, 11, 9, 12));
  });
}
