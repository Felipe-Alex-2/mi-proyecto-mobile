import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/offline_purchase_scenario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android reads large cached data while another connection writes',
    (_) => concurrentReadScenario(),
  );
  for (final method in ['WALLET', 'EFECTIVO']) {
    testWidgets(
      'Android login, offline $method purchase and automatic synchronization',
      (_) => purchaseScenario(method),
    );
  }
}
