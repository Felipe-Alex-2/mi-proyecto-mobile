import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/offline_purchase_scenario.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final method in ['WALLET', 'EFECTIVO']) {
    test(
      'login downloads data, offline $method purchase and automatic reconnect',
      () => purchaseScenario(method, factory: databaseFactoryFfi),
    );
  }
  test(
    'cached reads do not request the background writer lock',
    () => concurrentReadScenario(factory: databaseFactoryFfi),
  );
}
